// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation

/// Reconstructs the `moov` atom with updated metadata and chapters.
///
/// Preserves the existing track structure and sample tables while
/// replacing the `udta` atom with new metadata and chapters.
/// After rebuilding, chunk offsets (`stco`/`co64`) must be adjusted
/// for any size change using ``adjustChunkOffsets(in:delta:)``.
public struct MP4MoovBuilder: Sendable {

    private let metadataBuilder = MP4MetadataBuilder()
    private let atomBuilder = MP4AtomBuilder()
    private let textTrackBuilder = MP4TextTrackBuilder()
    private let videoTrackBuilder = MP4VideoTrackBuilder()

    /// Creates an MP4 moov builder.
    public init() {}

    // MARK: - Build Result

    /// The result of rebuilding a moov atom.
    public struct MoovBuildResult: Sendable {
        /// Complete moov atom data.
        public let moov: Data
        /// Chapter text samples to be written in a separate mdat (empty if no chapters).
        public let chapterSampleData: Data
        /// Per-sample sizes for text samples (matches chapter count).
        public let textSampleSizes: [UInt32]
        /// Byte positions of the text track's stco entries relative to moov start.
        /// Used for patching absolute file offsets after layout is determined.
        public let textTrackStcoOffsets: [Int]
        /// Per-chapter artwork image samples (empty if no chapters have artwork).
        public let artworkSampleData: Data
        /// Per-sample sizes for artwork images (matches `videoTrackStcoOffsets` count).
        public let artworkSampleSizes: [UInt32]
        /// Byte positions of the video track's stco entries relative to moov start.
        public let videoTrackStcoOffsets: [Int]
    }

    // MARK: - Public API

    /// Rebuilds the `moov` atom with new metadata and chapters.
    ///
    /// Preserves all existing children (mvhd, trak, etc.) except `udta`
    /// and any existing chapter text tracks. Creates a QuickTime chapter
    /// text track in addition to Nero chapters for maximum compatibility.
    /// - Parameters:
    ///   - existingMoov: The existing moov atom from the original file.
    ///   - reader: File reader for reading existing atom data.
    ///   - metadata: New metadata to write.
    ///   - chapters: New chapters to write.
    /// - Returns: A ``MoovBuildResult`` with moov data and chapter sample data.
    /// - Throws: ``MP4Error``, ``StreamingError``
    public func rebuildMoov(
        from existingMoov: MP4Atom,
        reader: FileReader,
        metadata: AudioMetadata,
        chapters: ChapterList
    ) throws -> MoovBuildResult {
        let movieTimescale = try readMovieTimescale(from: existingMoov, reader: reader)
        let movieDuration = try readMovieDuration(from: existingMoov, reader: reader)
        let maxTrackID = findMaxTrackID(in: existingMoov, reader: reader)
        let audioTrack = findAudioTrack(in: existingMoov, reader: reader)
        let oldChapterTrackIDs = findOldChapterTrackIDs(
            in: existingMoov, audioTrack: audioTrack, reader: reader)
        let hasChapters = !chapters.isEmpty

        var children = try collectExistingChildren(
            from: existingMoov, reader: reader,
            oldChapterTrackIDs: oldChapterTrackIDs)

        let textTrackID = maxTrackID + 1
        let videoTrackID = maxTrackID + 2

        // Probe for video track (per-chapter artwork) before modifying children.
        let videoResult: MP4VideoTrackBuilder.VideoTrackResult?
        if hasChapters {
            videoResult = videoTrackBuilder.buildVideoTrack(
                chapters: chapters, trackID: videoTrackID,
                movieTimescale: movieTimescale, movieDuration: movieDuration)
        } else {
            videoResult = nil
        }
        let hasVideoTrack = videoResult != nil

        // Build tref/chap track ID list.
        var chapTrackIDs: [UInt32] = []
        if hasChapters {
            chapTrackIDs.append(textTrackID)
            if hasVideoTrack { chapTrackIDs.append(videoTrackID) }
        }

        try updateAudioTrakTref(
            in: &children, audioTrack: audioTrack,
            hasChapters: hasChapters, chapTrackIDs: chapTrackIDs, reader: reader)

        var chapterSampleData = Data()
        var textSampleSizes: [UInt32] = []
        var textTrackStcoOffsets: [Int] = []
        if hasChapters {
            let chapterTrack = appendChapterTrack(
                to: &children, chapters: chapters,
                trackID: textTrackID,
                movieTimescale: movieTimescale, movieDuration: movieDuration)
            chapterSampleData = chapterTrack.sampleData
            textSampleSizes = chapterTrack.sampleSizes
            textTrackStcoOffsets = chapterTrack.stcoOffsets
        }

        let videoTrackData = appendVideoTrack(
            videoResult: videoResult, to: &children)

        let chaptersOrNil: ChapterList? = hasChapters ? chapters : nil
        let udta = metadataBuilder.buildUdta(from: metadata, chapters: chaptersOrNil)
        children.append(udta)

        let moov = atomBuilder.buildContainerAtom(type: "moov", children: children)
        return MoovBuildResult(
            moov: moov,
            chapterSampleData: chapterSampleData,
            textSampleSizes: textSampleSizes,
            textTrackStcoOffsets: textTrackStcoOffsets,
            artworkSampleData: videoTrackData.sampleData,
            artworkSampleSizes: videoTrackData.sampleSizes,
            videoTrackStcoOffsets: videoTrackData.stcoOffsets)
    }

    /// Adjusts chunk offsets (`stco`/`co64`) in moov data by a delta.
    ///
    /// Scans the moov data for `stco` and `co64` atoms and adjusts
    /// each offset entry by the given delta value.
    /// - Parameters:
    ///   - moovData: The raw moov atom data.
    ///   - delta: The offset adjustment (positive = mdat moved forward,
    ///     negative = mdat moved backward).
    /// - Returns: Moov data with adjusted offsets.
    public func adjustChunkOffsets(in moovData: Data, delta: Int64) throws -> Data {
        guard delta != 0 else { return moovData }

        var adjusted = moovData
        adjustSTCO(in: &adjusted, delta: delta)
        adjustCO64(in: &adjusted, delta: delta)
        return adjusted
    }

    /// Patches specific stco entry positions in moov data with absolute offsets.
    ///
    /// Used after `adjustChunkOffsets` to set the text track's stco entries
    /// to the correct absolute file offsets for chapter sample data.
    /// - Parameters:
    ///   - moovData: The moov data to patch (modified in-place).
    ///   - offsets: The absolute file offsets for each chapter sample.
    ///   - positions: The byte positions within moov data to write to.
    public func patchStcoEntries(
        in moovData: inout Data,
        offsets: [UInt32],
        positions: [Int]
    ) {
        for (position, offset) in zip(positions, offsets) {
            guard position + 4 <= moovData.count else { continue }
            writeUInt32(offset, to: &moovData, at: position)
        }
    }
}

// MARK: - Moov Analysis Helpers

extension MP4MoovBuilder {

    /// Reads the movie timescale from the `mvhd` atom.
    private func readMovieTimescale(
        from moov: MP4Atom, reader: FileReader
    ) throws -> UInt32 {
        guard let mvhd = moov.child(ofType: MP4AtomType.mvhd.rawValue) else {
            throw MP4Error.atomNotFound("mvhd")
        }
        let data = try reader.read(at: mvhd.dataOffset, count: min(Int(mvhd.dataSize), 24))
        guard data.count >= 16 else { throw MP4Error.invalidFile("mvhd too short.") }

        let version = data[0]
        if version == 1 {
            // v1: 8+8+4(timescale)+8
            guard data.count >= 24 else { throw MP4Error.invalidFile("mvhd v1 too short.") }
            return readUInt32(from: data, at: 20)
        }
        // v0: 4+4+4(timescale)+4
        return readUInt32(from: data, at: 12)
    }

    /// Reads the movie duration from the `mvhd` atom.
    private func readMovieDuration(
        from moov: MP4Atom, reader: FileReader
    ) throws -> UInt64 {
        guard let mvhd = moov.child(ofType: MP4AtomType.mvhd.rawValue) else {
            throw MP4Error.atomNotFound("mvhd")
        }
        let data = try reader.read(at: mvhd.dataOffset, count: min(Int(mvhd.dataSize), 28))
        guard data.count >= 20 else { throw MP4Error.invalidFile("mvhd too short.") }

        let version = data[0]
        if version == 1 {
            guard data.count >= 28 else { throw MP4Error.invalidFile("mvhd v1 too short.") }
            return readUInt64(from: data, at: 24)
        }
        return UInt64(readUInt32(from: data, at: 16))
    }

    /// Finds the highest track ID across all traks.
    private func findMaxTrackID(in moov: MP4Atom, reader: FileReader) -> UInt32 {
        var maxID: UInt32 = 0
        for trak in moov.children(ofType: MP4AtomType.trak.rawValue) {
            if let tkhd = trak.child(ofType: MP4AtomType.tkhd.rawValue),
                let data = try? reader.read(at: tkhd.dataOffset, count: min(Int(tkhd.dataSize), 16))
            {
                // tkhd v0: version(1) + flags(3) + creation(4) + modification(4) + trackID(4)
                let version = data[0]
                let trackIDOffset = version == 1 ? 20 : 12
                if data.count >= trackIDOffset + 4 {
                    let trackID = readUInt32(from: data, at: trackIDOffset)
                    maxID = max(maxID, trackID)
                }
            }
        }
        return maxID
    }

    /// Finds the first audio track (handler type "soun").
    private func findAudioTrack(in moov: MP4Atom, reader: FileReader) -> MP4Atom? {
        for trak in moov.children(ofType: MP4AtomType.trak.rawValue) {
            if let hdlr = trak.find(path: "mdia.hdlr"),
                isHandlerType("soun", in: hdlr, reader: reader)
            {
                return trak
            }
        }
        return nil
    }

    /// Reads all chapter track IDs from the audio track's `tref/chap` reference.
    private func findAllChapterTrackIDs(
        audioTrack: MP4Atom, reader: FileReader
    ) -> [UInt32] {
        guard let tref = audioTrack.child(ofType: "tref"),
            let chap = tref.child(ofType: "chap"),
            chap.dataSize >= 4
        else {
            return []
        }
        let entryCount = Int(chap.dataSize) / 4
        guard let data = try? reader.read(at: chap.dataOffset, count: entryCount * 4) else {
            return []
        }
        var ids: [UInt32] = []
        for index in 0..<entryCount {
            ids.append(readUInt32(from: data, at: index * 4))
        }
        return ids
    }

    /// Checks if a handler atom has the specified handler type.
    private func isHandlerType(
        _ type: String, in hdlr: MP4Atom, reader: FileReader
    ) -> Bool {
        guard hdlr.dataSize >= 12,
            let data = try? reader.read(at: hdlr.dataOffset, count: 12)
        else {
            return false
        }
        let handlerType = String(data: data[8..<12], encoding: .isoLatin1)
        return handlerType == type
    }

    /// Checks if a track's ID matches the given value.
    private func trackIDMatches(
        _ trak: MP4Atom, trackID: UInt32, reader: FileReader
    ) -> Bool {
        guard let tkhd = trak.child(ofType: MP4AtomType.tkhd.rawValue),
            let data = try? reader.read(at: tkhd.dataOffset, count: min(Int(tkhd.dataSize), 16))
        else {
            return false
        }
        let version = data[0]
        let trackIDOffset = version == 1 ? 20 : 12
        guard data.count >= trackIDOffset + 4 else { return false }
        return readUInt32(from: data, at: trackIDOffset) == trackID
    }

    /// Finds all track IDs that should be removed as old chapter tracks.
    ///
    /// Uses two strategies:
    /// 1. **Primary**: reads all IDs from `tref/chap` on the audio track (text + video tracks).
    /// 2. **Fallback**: scans for tracks with `text`, `sbtl`, or `vide` handler types
    ///    that are chapter-related tracks not explicitly referenced by `tref/chap`.
    private func findOldChapterTrackIDs(
        in moov: MP4Atom,
        audioTrack: MP4Atom?,
        reader: FileReader
    ) -> Set<UInt32> {
        var trackIDs = Set<UInt32>()

        // Primary: via tref/chap reference (reads ALL referenced track IDs).
        if let audio = audioTrack {
            for id in findAllChapterTrackIDs(audioTrack: audio, reader: reader) {
                trackIDs.insert(id)
            }
        }

        // Fallback: text/subtitle handler tracks.
        for trak in moov.children(ofType: MP4AtomType.trak.rawValue) {
            if let hdlr = trak.find(path: "mdia.hdlr"),
                isTextOrSubtitleHandler(hdlr, reader: reader),
                let trackID = readTrackID(from: trak, reader: reader)
            {
                trackIDs.insert(trackID)
            }
        }

        return trackIDs
    }

    /// Reads the track ID from a trak's tkhd atom.
    private func readTrackID(from trak: MP4Atom, reader: FileReader) -> UInt32? {
        guard let tkhd = trak.child(ofType: MP4AtomType.tkhd.rawValue),
            let data = try? reader.read(
                at: tkhd.dataOffset, count: min(Int(tkhd.dataSize), 24))
        else {
            return nil
        }
        let version = data[0]
        let trackIDOffset = version == 1 ? 20 : 12
        guard data.count >= trackIDOffset + 4 else { return nil }
        return readUInt32(from: data, at: trackIDOffset)
    }

    /// Checks if a handler atom has handler type `text` or `sbtl`.
    private func isTextOrSubtitleHandler(
        _ hdlr: MP4Atom, reader: FileReader
    ) -> Bool {
        guard hdlr.dataSize >= 12,
            let data = try? reader.read(at: hdlr.dataOffset, count: 12)
        else {
            return false
        }
        let handlerType = String(data: data[8..<12], encoding: .isoLatin1)
        return handlerType == "text" || handlerType == "sbtl"
    }

    /// Checks if raw trak data contains a "soun" handler.
    private func isAudioTrakData(_ trakData: Data) -> Bool {
        let sounBytes = Data("soun".utf8)
        for position in 0..<(trakData.count - 3) {
            if trakData[position] == sounBytes[0],
                trakData[position + 1] == sounBytes[1],
                trakData[position + 2] == sounBytes[2],
                trakData[position + 3] == sounBytes[3]
            {
                return true
            }
        }
        return false
    }

    /// Total byte count across an array of Data.
    private func totalSize(of items: [Data]) -> Int {
        var total = 0
        for item in items {
            total += item.count
        }
        return total
    }
}

// MARK: - Moov Child Collection

extension MP4MoovBuilder {

    /// Data produced by appending a chapter text track to the moov children.
    private struct ChapterTrackData {
        /// Encoded text samples for the chapter track.
        let sampleData: Data
        /// Per-sample byte sizes (one entry per chapter).
        let sampleSizes: [UInt32]
        /// Byte positions of stco entries relative to moov start.
        let stcoOffsets: [Int]
    }

    /// Copies existing moov children, skipping udta and old chapter text tracks.
    private func collectExistingChildren(
        from moov: MP4Atom,
        reader: FileReader,
        oldChapterTrackIDs: Set<UInt32>
    ) throws -> [Data] {
        var children: [Data] = []
        for child in moov.children {
            if child.type == MP4AtomType.udta.rawValue { continue }
            if child.type == MP4AtomType.trak.rawValue,
                !oldChapterTrackIDs.isEmpty,
                let trackID = readTrackID(from: child, reader: reader),
                oldChapterTrackIDs.contains(trackID)
            {
                continue
            }
            let childData = try reader.read(at: child.offset, count: Int(child.size))
            children.append(childData)
        }
        return children
    }

    /// Updates the audio trak's tref/chap reference based on whether chapters exist.
    private func updateAudioTrakTref(
        in children: inout [Data],
        audioTrack: MP4Atom?,
        hasChapters: Bool,
        chapTrackIDs: [UInt32],
        reader: FileReader
    ) throws {
        guard let audioTrakAtom = audioTrack else { return }

        let rebuiltAudioTrak: Data
        if hasChapters, !chapTrackIDs.isEmpty {
            let trefData = textTrackBuilder.buildTrefChap(chapterTrackIDs: chapTrackIDs)
            rebuiltAudioTrak = try rebuildTrakWithTref(
                trak: audioTrakAtom, reader: reader, trefData: trefData)
        } else {
            rebuiltAudioTrak = try rebuildTrakWithoutTref(
                trak: audioTrakAtom, reader: reader)
        }
        replaceAudioTrak(in: &children, with: rebuiltAudioTrak)
    }

    /// Replaces the audio trak in the children array with a rebuilt version.
    private func replaceAudioTrak(in children: inout [Data], with replacement: Data) {
        for index in children.indices where children[index].count >= 8 {
            let childType =
                String(
                    data: children[index][4..<8], encoding: .isoLatin1) ?? ""
            if childType == "trak", isAudioTrakData(children[index]) {
                children[index] = replacement
                return
            }
        }
    }

    /// Appends video track and returns its sample data/offsets, or empty defaults.
    private func appendVideoTrack(
        videoResult: MP4VideoTrackBuilder.VideoTrackResult?,
        to children: inout [Data]
    ) -> ChapterTrackData {
        guard let video = videoResult else {
            return ChapterTrackData(sampleData: Data(), sampleSizes: [], stcoOffsets: [])
        }
        let videoTrakOffset = 8 + totalSize(of: children)
        let stcoOffsets = video.stcoEntryOffsets.map { $0 + videoTrakOffset }
        children.append(video.trak)
        return ChapterTrackData(
            sampleData: video.sampleData,
            sampleSizes: video.sampleSizes,
            stcoOffsets: stcoOffsets)
    }

    /// Builds a chapter text track and appends it to children.
    private func appendChapterTrack(
        to children: inout [Data],
        chapters: ChapterList,
        trackID: UInt32,
        movieTimescale: UInt32,
        movieDuration: UInt64
    ) -> ChapterTrackData {
        let result = textTrackBuilder.buildChapterTrack(
            chapters: chapters, trackID: trackID,
            movieTimescale: movieTimescale, movieDuration: movieDuration)

        let trakOffsetInMoov = 8 + totalSize(of: children)  // 8 = moov header
        let stcoOffsets = result.stcoEntryOffsets.map { $0 + trakOffsetInMoov }
        children.append(result.trak)
        return ChapterTrackData(
            sampleData: result.sampleData,
            sampleSizes: result.sampleSizes,
            stcoOffsets: stcoOffsets)
    }
}

// MARK: - Trak Rebuilding

extension MP4MoovBuilder {

    /// Rebuilds a trak by copying all children except `tref`, then appending new tref.
    private func rebuildTrakWithTref(
        trak: MP4Atom, reader: FileReader, trefData: Data
    ) throws -> Data {
        var children: [Data] = []
        for child in trak.children {
            if child.type == "tref" { continue }
            let childData = try reader.read(at: child.offset, count: Int(child.size))
            children.append(childData)
        }
        children.append(trefData)
        return atomBuilder.buildContainerAtom(type: "trak", children: children)
    }

    /// Rebuilds a trak by copying all children except `tref`.
    private func rebuildTrakWithoutTref(
        trak: MP4Atom, reader: FileReader
    ) throws -> Data {
        var children: [Data] = []
        for child in trak.children {
            if child.type == "tref" { continue }
            let childData = try reader.read(at: child.offset, count: Int(child.size))
            children.append(childData)
        }
        return atomBuilder.buildContainerAtom(type: "trak", children: children)
    }
}

// MARK: - Offset Adjustment

extension MP4MoovBuilder {

    /// Scans for `stco` atoms and adjusts 32-bit chunk offsets.
    private func adjustSTCO(in data: inout Data, delta: Int64) {
        var position = 0
        let stcoType = Data("stco".utf8)

        while position + 8 <= data.count {
            guard let atomStart = findAtomType(stcoType, in: data, from: position) else {
                break
            }

            let sizeOffset = atomStart - 4
            guard sizeOffset >= 0 else {
                position = atomStart + 4
                continue
            }

            let atomSize = readUInt32(from: data, at: sizeOffset)
            let payloadStart = atomStart + 4  // after type
            let entryCountOffset = payloadStart + 4  // skip version+flags

            guard entryCountOffset + 4 <= data.count else {
                position = atomStart + 4
                continue
            }

            let entryCount = Int(readUInt32(from: data, at: entryCountOffset))
            let entriesStart = entryCountOffset + 4
            for index in 0..<entryCount {
                let entryOffset = entriesStart + index * 4
                guard entryOffset + 4 <= data.count else { break }
                let original = Int64(readUInt32(from: data, at: entryOffset))
                let adjusted = UInt32(clamping: max(0, original + delta))
                writeUInt32(adjusted, to: &data, at: entryOffset)
            }

            position = sizeOffset + Int(atomSize)
        }
    }

    /// Scans for `co64` atoms and adjusts 64-bit chunk offsets.
    private func adjustCO64(in data: inout Data, delta: Int64) {
        var position = 0
        let co64Type = Data("co64".utf8)

        while position + 8 <= data.count {
            guard let atomStart = findAtomType(co64Type, in: data, from: position) else {
                break
            }

            let sizeOffset = atomStart - 4
            guard sizeOffset >= 0 else {
                position = atomStart + 4
                continue
            }

            let atomSize = readUInt32(from: data, at: sizeOffset)
            let payloadStart = atomStart + 4
            let entryCountOffset = payloadStart + 4

            guard entryCountOffset + 4 <= data.count else {
                position = atomStart + 4
                continue
            }

            let entryCount = Int(readUInt32(from: data, at: entryCountOffset))
            let entriesStart = entryCountOffset + 4
            for index in 0..<entryCount {
                let entryOffset = entriesStart + index * 8
                guard entryOffset + 8 <= data.count else { break }
                let original = Int64(bitPattern: readUInt64(from: data, at: entryOffset))
                let adjusted = UInt64(clamping: max(0, original + delta))
                writeUInt64(adjusted, to: &data, at: entryOffset)
            }

            position = sizeOffset + Int(atomSize)
        }
    }
}

// MARK: - Binary Helpers

extension MP4MoovBuilder {

    /// Finds the next occurrence of a 4-byte atom type in data starting from position.
    private func findAtomType(_ type: Data, in data: Data, from start: Int) -> Int? {
        guard type.count == 4 else { return nil }
        let end = data.count - 3
        for position in start..<end {
            if data[position] == type[0],
                data[position + 1] == type[1],
                data[position + 2] == type[2],
                data[position + 3] == type[3]
            {
                return position
            }
        }
        return nil
    }

    /// Reads a big-endian UInt32 from data at the given offset.
    func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    /// Reads a big-endian UInt64 from data at the given offset.
    private func readUInt64(from data: Data, at offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<8 {
            value = (value << 8) | UInt64(data[offset + index])
        }
        return value
    }

    /// Writes a big-endian UInt32 to data at the given offset.
    func writeUInt32(_ value: UInt32, to data: inout Data, at offset: Int) {
        data[offset] = UInt8((value >> 24) & 0xFF)
        data[offset + 1] = UInt8((value >> 16) & 0xFF)
        data[offset + 2] = UInt8((value >> 8) & 0xFF)
        data[offset + 3] = UInt8(value & 0xFF)
    }

    /// Writes a big-endian UInt64 to data at the given offset.
    private func writeUInt64(_ value: UInt64, to data: inout Data, at offset: Int) {
        for index in 0..<8 {
            data[offset + index] = UInt8((value >> ((7 - index) * 8)) & 0xFF)
        }
    }
}
