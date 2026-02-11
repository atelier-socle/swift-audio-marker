import Foundation

/// Extracts chapters from an MP4 atom tree.
///
/// Supports two chapter formats:
/// - **Nero chapters** (`chpl` atom under `moov.udta`): timestamps in 100-nanosecond units.
/// - **QuickTime chapter track**: text track referenced by `chap` track reference (best-effort).
///
/// - Note: v0.2.0 — Parse chapter URLs and per-chapter artwork from M4A.
public struct MP4ChapterParser: Sendable {

    /// Creates an MP4 chapter parser.
    public init() {}

    // MARK: - Public API

    /// Extracts chapters from the parsed atom tree.
    ///
    /// Tries Nero chapters first (`chpl`), then falls back to QuickTime chapter track.
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

        // Try Nero chapters first.
        if let chapters = try parseNeroChapters(moov: moov, reader: reader) {
            return chapters
        }

        // Fall back to QuickTime chapter track.
        if let chapters = try parseQuickTimeChapters(moov: moov, reader: reader) {
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

    /// Parses QuickTime chapters from a text track in the `moov` atom.
    ///
    /// Best-effort: looks for a `trak` with handler type `text`, then
    /// reads sample times from `stts` and sample data from `stco`/`stsz`.
    private func parseQuickTimeChapters(
        moov: MP4Atom,
        reader: FileReader
    ) throws -> ChapterList? {
        guard let textTrack = findTextTrack(in: moov, reader: reader) else {
            return nil
        }

        let timescale = try readTrackTimescale(textTrack, reader: reader)
        guard timescale > 0 else { return nil }

        guard let stbl = textTrack.find(path: "mdia.minf.stbl") else { return nil }

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
            let title = try readSampleText(
                at: sampleOffsets[index],
                size: sampleSizes[index],
                reader: reader
            )
            chapters.append(Chapter(start: .seconds(seconds), title: title))
            cumulativeTime += sampleTimes[index]
        }

        guard !chapters.isEmpty else { return nil }
        return ChapterList(chapters)
    }

    /// Finds the first `trak` with handler type `text` or `sbtl`.
    private func findTextTrack(in moov: MP4Atom, reader: FileReader) -> MP4Atom? {
        for trak in moov.children(ofType: MP4AtomType.trak.rawValue) {
            if let hdlr = trak.find(path: "mdia.hdlr"),
                isTextHandler(hdlr, reader: reader)
            {
                return trak
            }
        }
        return nil
    }

    /// Checks if a `hdlr` atom has handler type `text` or `sbtl`.
    private func isTextHandler(_ hdlr: MP4Atom, reader: FileReader) -> Bool {
        guard hdlr.dataSize >= 12 else { return false }
        guard let data = try? reader.read(at: hdlr.dataOffset, count: 12) else {
            return false
        }
        // hdlr format: version(1) + flags(3) + pre_defined(4) + handler_type(4)
        let handlerType = String(data: data[8..<12], encoding: .isoLatin1)
        return handlerType == "text" || handlerType == "sbtl"
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

    /// Reads a QuickTime text sample: 2-byte length prefix + UTF-8 text.
    private func readSampleText(
        at offset: UInt64,
        size: UInt32,
        reader: FileReader
    ) throws -> String {
        guard size >= 2 else { return "Chapter" }

        let data = try reader.read(at: offset, count: Int(size))
        var binaryReader = BinaryReader(data: data)

        let textLength = Int(try binaryReader.readUInt16())
        guard textLength > 0, binaryReader.remainingCount >= textLength else {
            return "Chapter"
        }

        return try binaryReader.readUTF8String(count: textLength)
    }
}
