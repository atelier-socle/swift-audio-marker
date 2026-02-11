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

    /// Creates an MP4 moov builder.
    public init() {}

    // MARK: - Build Result

    /// The result of rebuilding a moov atom.
    public struct MoovBuildResult: Sendable {
        /// Complete moov atom data.
        public let moov: Data
        /// Chapter text samples to be written in a separate mdat (empty if no chapters).
        public let chapterSampleData: Data
        /// Byte positions of the text track's stco entries relative to moov start.
        /// Used for patching absolute file offsets after layout is determined.
        public let textTrackStcoOffsets: [Int]
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

        try updateAudioTrakTref(
            in: &children, audioTrack: audioTrack,
            hasChapters: hasChapters, maxTrackID: maxTrackID, reader: reader)

        var chapterSampleData = Data()
        var textTrackStcoOffsets: [Int] = []
        if hasChapters {
            (chapterSampleData, textTrackStcoOffsets) = appendChapterTrack(
                to: &children, chapters: chapters,
                trackID: maxTrackID + 1,
                movieTimescale: movieTimescale, movieDuration: movieDuration)
        }

        let chaptersOrNil: ChapterList? = hasChapters ? chapters : nil
        let udta = metadataBuilder.buildUdta(from: metadata, chapters: chaptersOrNil)
        children.append(udta)

        let moov = atomBuilder.buildContainerAtom(type: "moov", children: children)
        return MoovBuildResult(
            moov: moov,
            chapterSampleData: chapterSampleData,
            textTrackStcoOffsets: textTrackStcoOffsets)
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

    /// Reads the chapter track ID from the audio track's `tref/chap` reference.
    private func findChapterTrackID(audioTrack: MP4Atom, reader: FileReader) -> UInt32? {
        guard let tref = audioTrack.child(ofType: "tref"),
            let chap = tref.child(ofType: "chap")
        else {
            return nil
        }
        guard chap.dataSize >= 4,
            let data = try? reader.read(at: chap.dataOffset, count: 4)
        else {
            return nil
        }
        return readUInt32(from: data, at: 0)
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

    /// Finds all track IDs that should be removed as old chapter text tracks.
    ///
    /// Uses two strategies:
    /// 1. **Primary**: reads `tref/chap` from the audio track to find the referenced track ID.
    /// 2. **Fallback**: scans for tracks with `text` or `sbtl` handler types, which are
    ///    chapter text tracks not explicitly referenced by `tref/chap`.
    private func findOldChapterTrackIDs(
        in moov: MP4Atom,
        audioTrack: MP4Atom?,
        reader: FileReader
    ) -> Set<UInt32> {
        var trackIDs = Set<UInt32>()

        // Primary: via tref/chap reference.
        if let audio = audioTrack,
            let chapTrackID = findChapterTrackID(audioTrack: audio, reader: reader)
        {
            trackIDs.insert(chapTrackID)
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
        maxTrackID: UInt32,
        reader: FileReader
    ) throws {
        guard let audioTrakAtom = audioTrack else { return }

        let rebuiltAudioTrak: Data
        if hasChapters {
            let trefData = textTrackBuilder.buildTrefChap(chapterTrackID: maxTrackID + 1)
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

    /// Builds a chapter text track and appends it to children.
    private func appendChapterTrack(
        to children: inout [Data],
        chapters: ChapterList,
        trackID: UInt32,
        movieTimescale: UInt32,
        movieDuration: UInt64
    ) -> (sampleData: Data, stcoOffsets: [Int]) {
        let result = textTrackBuilder.buildChapterTrack(
            chapters: chapters, trackID: trackID,
            movieTimescale: movieTimescale, movieDuration: movieDuration)

        let trakOffsetInMoov = 8 + totalSize(of: children)  // 8 = moov header
        let stcoOffsets = result.stcoEntryOffsets.map { $0 + trakOffsetInMoov }
        children.append(result.trak)
        return (sampleData: result.sampleData, stcoOffsets: stcoOffsets)
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

            let entryCount = readUInt32(from: data, at: entryCountOffset)
            adjustSTCOEntries(
                in: &data,
                entriesStart: entryCountOffset + 4,
                count: Int(entryCount),
                delta: delta
            )

            position = sizeOffset + Int(atomSize)
        }
    }

    /// Adjusts individual stco offset entries.
    private func adjustSTCOEntries(
        in data: inout Data,
        entriesStart: Int,
        count: Int,
        delta: Int64
    ) {
        for index in 0..<count {
            let offset = entriesStart + index * 4
            guard offset + 4 <= data.count else { break }
            let original = Int64(readUInt32(from: data, at: offset))
            let adjusted = UInt32(clamping: max(0, original + delta))
            writeUInt32(adjusted, to: &data, at: offset)
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

            let entryCount = readUInt32(from: data, at: entryCountOffset)
            adjustCO64Entries(
                in: &data,
                entriesStart: entryCountOffset + 4,
                count: Int(entryCount),
                delta: delta
            )

            position = sizeOffset + Int(atomSize)
        }
    }

    /// Adjusts individual co64 offset entries.
    private func adjustCO64Entries(
        in data: inout Data,
        entriesStart: Int,
        count: Int,
        delta: Int64
    ) {
        for index in 0..<count {
            let offset = entriesStart + index * 8
            guard offset + 8 <= data.count else { break }
            let original = Int64(bitPattern: readUInt64(from: data, at: offset))
            let adjusted = UInt64(clamping: max(0, original + delta))
            writeUInt64(adjusted, to: &data, at: offset)
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
