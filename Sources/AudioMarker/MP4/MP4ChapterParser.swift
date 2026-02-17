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

/// Extracts chapters from an MP4 atom tree.
///
/// Supports two chapter formats:
/// - **Nero chapters** (`chpl` atom under `moov.udta`): timestamps in 100-nanosecond units.
/// - **QuickTime chapter track**: text track referenced by `chap` track reference,
///   with optional `href` URLs and per-chapter artwork from a video track.
public struct MP4ChapterParser: Sendable {

    /// Creates an MP4 chapter parser.
    public init() {}

    // MARK: - Public API

    /// Extracts chapters from the parsed atom tree.
    ///
    /// Tries QuickTime chapter track first (supports URLs and artwork),
    /// then falls back to Nero chapters (`chpl`).
    /// - Parameters:
    ///   - atoms: Top-level atoms from ``MP4AtomParser``.
    ///   - reader: An open file reader for reading atom payloads.
    /// - Returns: A ``ChapterList`` (may be empty if no chapters found).
    /// - Throws: ``MP4Error`` if chapter data is corrupt.
    public func parseChapters(
        from atoms: [MP4Atom],
        reader: FileReader
    ) throws -> ChapterList {
        guard let moov = atoms.first(where: { $0.type == MP4AtomType.moov.rawValue }) else {
            return ChapterList()
        }

        // Try QuickTime chapter track first (supports URLs and artwork).
        if let chapters = try parseQuickTimeChapters(moov: moov, reader: reader) {
            return chapters
        }

        // Fall back to Nero chapters.
        if let chapters = try parseNeroChapters(moov: moov, reader: reader) {
            return chapters
        }

        return ChapterList()
    }
}

// MARK: - Nero Chapters (chpl)

extension MP4ChapterParser {

    /// Parses Nero chapters from the `moov.udta.chpl` atom.
    ///
    /// Binary format:
    /// - 4 bytes: version
    /// - 4 bytes: unknown/reserved
    /// - 1 byte: chapter count
    /// - For each chapter:
    ///   - 8 bytes: start time in 100-nanosecond units (UInt64 big-endian)
    ///   - 1 byte: title length
    ///   - N bytes: title (UTF-8)
    private func parseNeroChapters(
        moov: MP4Atom,
        reader: FileReader
    ) throws -> ChapterList? {
        guard let udta = moov.child(ofType: MP4AtomType.udta.rawValue),
            let chpl = udta.child(ofType: MP4AtomType.chpl.rawValue)
        else {
            return nil
        }

        let payloadSize = chpl.dataSize
        guard payloadSize >= 9 else { return nil }

        let data = try reader.read(at: chpl.dataOffset, count: Int(payloadSize))
        var binaryReader = BinaryReader(data: data)

        // Version (4 bytes) + unknown (4 bytes).
        try binaryReader.skip(8)

        let chapterCount = try binaryReader.readUInt8()
        guard chapterCount > 0 else { return nil }

        var chapters: [Chapter] = []

        for _ in 0..<chapterCount {
            guard binaryReader.remainingCount >= 9 else { break }

            let timestamp100ns = try binaryReader.readUInt64()
            let titleLength = Int(try binaryReader.readUInt8())

            guard binaryReader.remainingCount >= titleLength else { break }

            let title: String
            if titleLength > 0 {
                title = try binaryReader.readUTF8String(count: titleLength)
            } else {
                title = "Chapter \(chapters.count + 1)"
            }

            // Convert 100-nanosecond units to seconds.
            let seconds = Double(timestamp100ns) / 10_000_000.0
            let chapter = Chapter(start: .seconds(seconds), title: title)
            chapters.append(chapter)
        }

        guard !chapters.isEmpty else { return nil }
        return ChapterList(chapters)
    }
}

// MARK: - QuickTime Chapter Track

extension MP4ChapterParser {

    /// Parses QuickTime chapters from text tracks in the `moov` atom.
    ///
    /// Handles files with multiple text tracks (e.g. GarageBand Enhanced Podcasts
    /// where one track has clean titles and another has `href` URLs). Merges
    /// titles from the cleanest track with URLs from the track that has them.
    private func parseQuickTimeChapters(
        moov: MP4Atom,
        reader: FileReader
    ) throws -> ChapterList? {
        let textTracks = findAllTextTracks(in: moov, reader: reader)
        guard !textTracks.isEmpty else { return nil }

        // Parse chapters from each text track.
        var parsedSets: [[Chapter]] = []
        for trak in textTracks {
            if let chapters = try readChaptersFromTextTrack(trak, reader: reader) {
                parsedSets.append(chapters)
            }
        }

        guard !parsedSets.isEmpty else { return nil }

        var chapters: [Chapter]
        if parsedSets.count == 1 {
            chapters = parsedSets[0]
        } else {
            chapters = mergeTextTrackChapters(parsedSets)
        }

        // Enrich with per-chapter artwork from video track.
        let artworks = readChapterArtwork(moov: moov, reader: reader)
        if !artworks.isEmpty {
            var enriched: [Chapter] = []
            for (index, chapter) in chapters.enumerated() {
                let art = index < artworks.count ? artworks[index] : nil
                enriched.append(
                    Chapter(
                        start: chapter.start, title: chapter.title,
                        url: chapter.url, artwork: art))
            }
            chapters = enriched
        }

        return chapters.isEmpty ? nil : ChapterList(chapters)
    }

    /// Reads chapters from a single text track, filtering spacers and trimming titles.
    private func readChaptersFromTextTrack(
        _ trak: MP4Atom,
        reader: FileReader
    ) throws -> [Chapter]? {
        let timescale = try readTrackTimescale(trak, reader: reader)
        guard timescale > 0 else { return nil }

        guard let stbl = trak.find(path: "mdia.minf.stbl") else { return nil }

        let sampleTimes = try readSampleTimes(stbl: stbl, reader: reader)
        let sampleOffsets = try readChunkOffsets(stbl: stbl, reader: reader)
        let sampleSizes = try readSampleSizes(stbl: stbl, reader: reader)

        guard !sampleTimes.isEmpty,
            sampleOffsets.count >= sampleTimes.count,
            sampleSizes.count >= sampleTimes.count
        else {
            return nil
        }

        var chapters: [Chapter] = []
        var cumulativeTime: UInt64 = 0

        for index in 0..<sampleTimes.count {
            let seconds = Double(cumulativeTime) / Double(timescale)
            let duration = sampleTimes[index]
            let content = try parseTx3gSample(
                at: sampleOffsets[index],
                size: sampleSizes[index],
                reader: reader
            )

            // Filter spacer samples (whitespace-only title, duration <= 1 tick).
            let trimmedTitle = content.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedTitle.isEmpty && duration <= 1 {
                cumulativeTime += duration
                continue
            }

            let title =
                trimmedTitle.isEmpty
                ? "Chapter \(chapters.count + 1)" : trimmedTitle
            chapters.append(
                Chapter(
                    start: .seconds(seconds), title: title, url: content.url))
            cumulativeTime += duration
        }

        return chapters.isEmpty ? nil : chapters
    }

    /// Returns all text tracks referenced by `tref/chap`, or all text tracks if none referenced.
    private func findAllTextTracks(in moov: MP4Atom, reader: FileReader) -> [MP4Atom] {
        let chapTrackIDs = findChapTrackIDs(in: moov, reader: reader)

        var allTextTracks: [MP4Atom] = []
        var referencedTextTracks: [MP4Atom] = []

        for trak in moov.children(ofType: MP4AtomType.trak.rawValue) {
            if let hdlr = trak.find(path: "mdia.hdlr"),
                isTextHandler(hdlr, reader: reader)
            {
                allTextTracks.append(trak)
                if let trackID = readTrackIDFromTkhd(trak, reader: reader),
                    chapTrackIDs.contains(trackID)
                {
                    referencedTextTracks.append(trak)
                }
            }
        }

        return referencedTextTracks.isEmpty ? allTextTracks : referencedTextTracks
    }

    /// Merges chapters from multiple text tracks: titles from the cleanest track, URLs from any.
    ///
    /// GarageBand Enhanced Podcasts use two text tracks: one with clean titles (disabled)
    /// and one with `href` URLs (enabled). This method picks titles from the non-URL track
    /// and matches URLs by timestamp proximity.
    private func mergeTextTrackChapters(_ sets: [[Chapter]]) -> [Chapter] {
        let hasURLs: ([Chapter]) -> Bool = { $0.contains { $0.url != nil } }

        // Title track: prefer the set without URLs (has cleaner titles).
        let titleSet: [Chapter]
        if let cleanSet = sets.first(where: { !hasURLs($0) }) {
            titleSet = cleanSet
        } else {
            titleSet = sets.max(by: { $0.count < $1.count }) ?? sets[0]
        }

        // Build URL lookup from all tracks by timestamp (millisecond precision).
        var urlByTime: [Int: URL] = [:]
        for set in sets {
            for chapter in set {
                if let url = chapter.url {
                    let key = Int(round(chapter.start.timeInterval * 1000))
                    urlByTime[key] = url
                }
            }
        }

        guard !urlByTime.isEmpty else { return titleSet }

        // Merge: title from titleSet, URL from closest timestamp match (within 2s).
        return titleSet.map { chapter in
            let key = Int(round(chapter.start.timeInterval * 1000))
            let url = findClosestURL(for: key, in: urlByTime, tolerance: 2000)
            return Chapter(
                start: chapter.start, title: chapter.title,
                url: url ?? chapter.url, artwork: chapter.artwork)
        }
    }

    /// Finds the URL with the closest matching timestamp within tolerance (in milliseconds).
    private func findClosestURL(
        for timeMS: Int, in map: [Int: URL], tolerance: Int
    ) -> URL? {
        if let url = map[timeMS] { return url }
        var bestURL: URL?
        var bestDiff = Int.max
        for (key, url) in map {
            let diff = abs(key - timeMS)
            if diff < bestDiff && diff <= tolerance {
                bestDiff = diff
                bestURL = url
            }
        }
        return bestURL
    }

    /// Checks if a `hdlr` atom has handler type `text` or `sbtl`.
    private func isTextHandler(_ hdlr: MP4Atom, reader: FileReader) -> Bool {
        readHandlerType(hdlr, reader: reader).map { $0 == "text" || $0 == "sbtl" } ?? false
    }

    /// Checks if a `hdlr` atom has handler type `vide`.
    private func isVideoHandler(_ hdlr: MP4Atom, reader: FileReader) -> Bool {
        readHandlerType(hdlr, reader: reader) == "vide"
    }

    /// Reads the 4-character handler type from an `hdlr` atom.
    private func readHandlerType(_ hdlr: MP4Atom, reader: FileReader) -> String? {
        guard hdlr.dataSize >= 12 else { return nil }
        guard let data = try? reader.read(at: hdlr.dataOffset, count: 12) else {
            return nil
        }
        // hdlr format: version(1) + flags(3) + pre_defined(4) + handler_type(4)
        return String(data: data[8..<12], encoding: .isoLatin1)
    }

    /// Reads the timescale from the `mdhd` atom in a track.
    private func readTrackTimescale(_ trak: MP4Atom, reader: FileReader) throws -> UInt32 {
        guard let mdhd = trak.find(path: "mdia.mdhd") else { return 0 }

        let dataSize = mdhd.dataSize
        guard dataSize >= 16 else { return 0 }

        let readSize = min(dataSize, 24)
        let data = try reader.read(at: mdhd.dataOffset, count: Int(readSize))
        var binaryReader = BinaryReader(data: data)

        let version = try binaryReader.readUInt8()
        try binaryReader.skip(3)  // flags

        if version == 1 {
            guard dataSize >= 24 else { return 0 }
            try binaryReader.skip(16)  // creation + modification time (8 bytes each)
        } else {
            try binaryReader.skip(8)  // creation + modification time (4 bytes each)
        }

        return try binaryReader.readUInt32()
    }

    /// Reads sample durations from the `stts` atom.
    ///
    /// Returns one duration per sample (expanded from the run-length encoding).
    private func readSampleTimes(stbl: MP4Atom, reader: FileReader) throws -> [UInt64] {
        guard let stts = stbl.child(ofType: MP4AtomType.stts.rawValue) else {
            return []
        }

        let dataSize = stts.dataSize
        guard dataSize >= 8 else { return [] }

        let data = try reader.read(at: stts.dataOffset, count: Int(dataSize))
        var binaryReader = BinaryReader(data: data)

        try binaryReader.skip(4)  // version + flags
        let entryCount = try binaryReader.readUInt32()

        var times: [UInt64] = []
        for _ in 0..<entryCount {
            guard binaryReader.remainingCount >= 8 else { break }
            let sampleCount = try binaryReader.readUInt32()
            let sampleDuration = try binaryReader.readUInt32()
            for _ in 0..<sampleCount {
                times.append(UInt64(sampleDuration))
            }
        }

        return times
    }

    /// Reads chunk offsets from `stco` (32-bit) or `co64` (64-bit) atoms.
    private func readChunkOffsets(stbl: MP4Atom, reader: FileReader) throws -> [UInt64] {
        if let stco = stbl.child(ofType: MP4AtomType.stco.rawValue) {
            return try readSTCO(stco, reader: reader)
        }
        if let co64 = stbl.child(ofType: MP4AtomType.co64.rawValue) {
            return try readCO64(co64, reader: reader)
        }
        return []
    }

    /// Reads 32-bit chunk offsets from `stco`.
    private func readSTCO(_ atom: MP4Atom, reader: FileReader) throws -> [UInt64] {
        let dataSize = atom.dataSize
        guard dataSize >= 8 else { return [] }

        let data = try reader.read(at: atom.dataOffset, count: Int(dataSize))
        var binaryReader = BinaryReader(data: data)

        try binaryReader.skip(4)  // version + flags
        let entryCount = try binaryReader.readUInt32()

        var offsets: [UInt64] = []
        for _ in 0..<entryCount {
            guard binaryReader.remainingCount >= 4 else { break }
            offsets.append(UInt64(try binaryReader.readUInt32()))
        }
        return offsets
    }

    /// Reads 64-bit chunk offsets from `co64`.
    private func readCO64(_ atom: MP4Atom, reader: FileReader) throws -> [UInt64] {
        let dataSize = atom.dataSize
        guard dataSize >= 8 else { return [] }

        let data = try reader.read(at: atom.dataOffset, count: Int(dataSize))
        var binaryReader = BinaryReader(data: data)

        try binaryReader.skip(4)  // version + flags
        let entryCount = try binaryReader.readUInt32()

        var offsets: [UInt64] = []
        for _ in 0..<entryCount {
            guard binaryReader.remainingCount >= 8 else { break }
            offsets.append(try binaryReader.readUInt64())
        }
        return offsets
    }

    /// Reads sample sizes from the `stsz` atom.
    private func readSampleSizes(stbl: MP4Atom, reader: FileReader) throws -> [UInt32] {
        guard let stsz = stbl.child(ofType: MP4AtomType.stsz.rawValue) else {
            return []
        }

        let dataSize = stsz.dataSize
        guard dataSize >= 12 else { return [] }

        let data = try reader.read(at: stsz.dataOffset, count: Int(dataSize))
        var binaryReader = BinaryReader(data: data)

        try binaryReader.skip(4)  // version + flags
        let defaultSize = try binaryReader.readUInt32()
        let sampleCount = try binaryReader.readUInt32()

        if defaultSize > 0 {
            return [UInt32](repeating: defaultSize, count: Int(sampleCount))
        }

        var sizes: [UInt32] = []
        for _ in 0..<sampleCount {
            guard binaryReader.remainingCount >= 4 else { break }
            sizes.append(try binaryReader.readUInt32())
        }
        return sizes
    }

    // MARK: - tx3g Sample Parsing

    /// Content extracted from a tx3g text sample.
    private struct SampleContent {
        let title: String
        let url: URL?
    }

    /// Parses a tx3g text sample: 2-byte length prefix + UTF-8 text + optional `href` atom.
    private func parseTx3gSample(
        at offset: UInt64,
        size: UInt32,
        reader: FileReader
    ) throws -> SampleContent {
        guard size >= 2 else { return SampleContent(title: "Chapter", url: nil) }

        let data = try reader.read(at: offset, count: Int(size))
        var binaryReader = BinaryReader(data: data)

        let textLength = Int(try binaryReader.readUInt16())
        let title: String
        if textLength > 0, binaryReader.remainingCount >= textLength {
            title = try binaryReader.readUTF8String(count: textLength)
        } else {
            title = "Chapter"
        }

        // Scan remaining bytes for an href atom after the text.
        let textEnd = 2 + textLength
        let url = parseHrefAtom(in: data, from: textEnd)

        return SampleContent(title: title, url: url)
    }

    /// Scans for an `href` atom after the text portion of a tx3g sample.
    ///
    /// href atom format:
    /// `[UInt32 atomSize] [FourCC "href"] [UInt16 0x0005] [UInt16 textCharCount] [UInt8 urlLength] [UTF-8 url] [UInt16 0x0000]`
    private func parseHrefAtom(in data: Data, from startOffset: Int) -> URL? {
        var position = startOffset
        let hrefTag = Data("href".utf8)

        // Scan for atom boundaries until we find "href".
        while position + 8 <= data.count {
            guard position + 4 <= data.count else { break }
            let atomSize = Int(
                UInt32(data[position]) << 24
                    | UInt32(data[position + 1]) << 16
                    | UInt32(data[position + 2]) << 8
                    | UInt32(data[position + 3]))
            guard atomSize >= 8, position + atomSize <= data.count else { break }

            let typeStart = position + 4
            if data[typeStart] == hrefTag[0],
                data[typeStart + 1] == hrefTag[1],
                data[typeStart + 2] == hrefTag[2],
                data[typeStart + 3] == hrefTag[3]
            {
                // Found href atom. Parse payload.
                // Payload: UInt16(flags) + UInt16(textCharCount) + UInt8(urlLength) + url + UInt16(0)
                let payloadStart = position + 8
                let payloadEnd = position + atomSize
                let payloadSize = payloadEnd - payloadStart
                guard payloadSize >= 5 else { return nil }

                // Skip UInt16 flags + UInt16 textCharCount.
                let urlLenOffset = payloadStart + 4
                guard urlLenOffset < data.count else { return nil }
                let urlLength = Int(data[urlLenOffset])
                guard urlLength > 0, urlLenOffset + 1 + urlLength <= payloadEnd else { return nil }

                let urlData = data[(urlLenOffset + 1)..<(urlLenOffset + 1 + urlLength)]
                guard let urlString = String(data: urlData, encoding: .utf8),
                    !urlString.isEmpty
                else {
                    return nil
                }
                return URL(string: urlString)
            }

            position += atomSize
        }

        return nil
    }
}

// MARK: - Video Track Artwork

extension MP4ChapterParser {

    /// Reads per-chapter artwork from a video track referenced by `tref/chap`.
    private func readChapterArtwork(moov: MP4Atom, reader: FileReader) -> [Artwork] {
        guard let videoTrack = findVideoTrack(in: moov, reader: reader) else {
            return []
        }
        return (try? readVideoTrackArtwork(from: videoTrack, reader: reader)) ?? []
    }

    /// Finds a video track referenced by any audio track's `tref/chap`.
    private func findVideoTrack(in moov: MP4Atom, reader: FileReader) -> MP4Atom? {
        let chapTrackIDs = findChapTrackIDs(in: moov, reader: reader)
        guard !chapTrackIDs.isEmpty else { return nil }

        for trak in moov.children(ofType: MP4AtomType.trak.rawValue) {
            if let hdlr = trak.find(path: "mdia.hdlr"),
                isVideoHandler(hdlr, reader: reader),
                let trackID = readTrackIDFromTkhd(trak, reader: reader),
                chapTrackIDs.contains(trackID)
            {
                return trak
            }
        }
        return nil
    }

    /// Returns all track IDs from `tref/chap` references on audio tracks.
    private func findChapTrackIDs(in moov: MP4Atom, reader: FileReader) -> Set<UInt32> {
        var trackIDs = Set<UInt32>()
        for trak in moov.children(ofType: MP4AtomType.trak.rawValue) {
            if let hdlr = trak.find(path: "mdia.hdlr"),
                readHandlerType(hdlr, reader: reader) == "soun",
                let tref = trak.child(ofType: "tref"),
                let chap = tref.child(ofType: "chap"),
                chap.dataSize >= 4
            {
                let entryCount = Int(chap.dataSize) / 4
                if let data = try? reader.read(
                    at: chap.dataOffset, count: entryCount * 4)
                {
                    var binaryReader = BinaryReader(data: data)
                    for _ in 0..<entryCount {
                        if let id = try? binaryReader.readUInt32() {
                            trackIDs.insert(id)
                        }
                    }
                }
            }
        }
        return trackIDs
    }

    /// Reads the track ID from a trak's tkhd atom.
    private func readTrackIDFromTkhd(_ trak: MP4Atom, reader: FileReader) -> UInt32? {
        guard let tkhd = trak.child(ofType: MP4AtomType.tkhd.rawValue),
            let data = try? reader.read(
                at: tkhd.dataOffset, count: min(Int(tkhd.dataSize), 24))
        else {
            return nil
        }
        let version = data[0]
        let trackIDOffset = version == 1 ? 20 : 12
        guard data.count >= trackIDOffset + 4 else { return nil }
        return UInt32(data[trackIDOffset]) << 24
            | UInt32(data[trackIDOffset + 1]) << 16
            | UInt32(data[trackIDOffset + 2]) << 8
            | UInt32(data[trackIDOffset + 3])
    }

    /// Reads per-chapter artwork from a video track's sample table.
    private func readVideoTrackArtwork(
        from trak: MP4Atom,
        reader: FileReader
    ) throws -> [Artwork] {
        guard let stbl = trak.find(path: "mdia.minf.stbl") else { return [] }

        let format = readVideoSampleFormat(stbl: stbl, reader: reader)
        let sampleOffsets = try readChunkOffsets(stbl: stbl, reader: reader)
        let sampleSizes = try readSampleSizes(stbl: stbl, reader: reader)

        let count = min(sampleOffsets.count, sampleSizes.count)
        guard count > 0 else { return [] }

        var artworks: [Artwork] = []
        for index in 0..<count {
            let size = sampleSizes[index]
            guard size > 0 else { continue }
            let imageData = try reader.read(at: sampleOffsets[index], count: Int(size))
            if let detected = ArtworkFormat.detect(from: imageData) {
                artworks.append(Artwork(data: imageData, format: detected))
            } else if let hintFormat = format {
                artworks.append(Artwork(data: imageData, format: hintFormat))
            }
        }
        return artworks
    }

    /// Reads the sample format from `stsd` in a video track (e.g., "jpeg" or "png ").
    private func readVideoSampleFormat(
        stbl: MP4Atom, reader: FileReader
    ) -> ArtworkFormat? {
        guard let stsd = stbl.child(ofType: "stsd"),
            stsd.dataSize >= 16,
            let data = try? reader.read(at: stsd.dataOffset, count: min(Int(stsd.dataSize), 16))
        else {
            return nil
        }
        // stsd: version+flags(4) + entry_count(4) + entry_size(4) + format(4)
        let formatString = String(data: data[12..<16], encoding: .isoLatin1)
        switch formatString {
        case "jpeg": return .jpeg
        case "png ": return .png
        default: return nil
        }
    }
}
