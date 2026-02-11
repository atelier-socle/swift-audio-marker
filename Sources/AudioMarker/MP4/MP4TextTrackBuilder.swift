import Foundation

/// Builds a QuickTime chapter text track (`trak` atom) for MP4/M4A files.
///
/// QuickTime Player and Apple Podcasts only read chapters from a text track
/// referenced by the audio track's `tref/chap`. This builder creates the
/// complete text track hierarchy and sample data. Chapter URLs are embedded
/// as `href` atoms within tx3g text samples.
public struct MP4TextTrackBuilder: Sendable {

    private let atomBuilder = MP4AtomBuilder()

    /// Creates a text track builder.
    public init() {}

    // MARK: - Result Type

    /// The result of building a chapter text track.
    public struct TextTrackResult: Sendable {
        /// Complete `trak` atom data for the chapter text track.
        public let trak: Data
        /// Chapter text samples (not wrapped in mdat).
        public let sampleData: Data
        /// Per-sample sizes in bytes (matches chapter count).
        public let sampleSizes: [UInt32]
        /// Byte positions of stco entry values within the trak data.
        /// Each position is the offset of a 4-byte big-endian UInt32 within `trak`.
        public let stcoEntryOffsets: [Int]
    }

    // MARK: - Public API

    /// Builds a chapter text track with placeholder stco offsets.
    ///
    /// The caller is responsible for patching the stco entries with correct
    /// absolute file offsets after determining the final file layout.
    /// - Parameters:
    ///   - chapters: The chapters to encode.
    ///   - trackID: The track ID to assign to this text track.
    ///   - movieTimescale: The movie-level timescale (from mvhd).
    ///   - movieDuration: The movie-level duration (from mvhd).
    /// - Returns: A ``TextTrackResult`` with the trak, sample data, and stco positions.
    public func buildChapterTrack(
        chapters: ChapterList,
        trackID: UInt32,
        movieTimescale: UInt32,
        movieDuration: UInt64
    ) -> TextTrackResult {
        // Build text samples: UInt16(BE text_length) + UTF-8 text bytes + optional href atom.
        var sampleData = Data()
        var sampleSizes: [UInt32] = []
        for chapter in chapters {
            let textBytes = Data(chapter.title.utf8)
            var sampleWriter = BinaryWriter(capacity: 2 + textBytes.count + 32)
            sampleWriter.writeUInt16(UInt16(textBytes.count))
            sampleWriter.writeData(textBytes)

            // Append href atom if chapter has a URL.
            if let url = chapter.url {
                let urlBytes = Data(url.absoluteString.utf8)
                // href atom: size(4) + "href"(4) + flags(2) + textCharCount(2) + urlLen(1) + url(N) + terminator(2)
                let hrefPayloadSize = 2 + 2 + 1 + urlBytes.count + 2
                sampleWriter.writeUInt32(UInt32(8 + hrefPayloadSize))
                sampleWriter.writeLatin1String("href")
                sampleWriter.writeUInt16(0x0005)
                sampleWriter.writeUInt16(UInt16(chapter.title.count))
                sampleWriter.writeUInt8(UInt8(min(urlBytes.count, 255)))
                sampleWriter.writeData(urlBytes)
                sampleWriter.writeUInt16(0x0000)
            }

            sampleSizes.append(UInt32(sampleWriter.count))
            sampleData.append(sampleWriter.data)
        }

        // Calculate sample durations in media timescale (1000 = milliseconds).
        let mediaTimescale: UInt32 = 1000
        let mediaDuration = UInt32(
            Double(movieDuration) / Double(movieTimescale) * Double(mediaTimescale))
        let sampleDurations = buildSampleDurations(
            chapters: chapters, mediaDuration: mediaDuration, mediaTimescale: mediaTimescale)

        // Build tkhd (disabled track, flags=0).
        let tkhd = buildTkhd(
            trackID: trackID, movieTimescale: movieTimescale, movieDuration: movieDuration)

        // Build mdia.
        let mdhd = buildMdhd(timescale: mediaTimescale, duration: UInt32(mediaDuration))
        let hdlr = buildHdlr()
        let minf = buildMinf(
            sampleDurations: sampleDurations,
            sampleSizes: sampleSizes,
            sampleCount: chapters.count)
        let mdia = atomBuilder.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])

        // Build trak.
        let trak = atomBuilder.buildContainerAtom(type: "trak", children: [tkhd, mdia])

        // Find stco entry offsets within trak data.
        let stcoEntryOffsets = findStcoEntryOffsets(in: trak, entryCount: chapters.count)

        return TextTrackResult(
            trak: trak, sampleData: sampleData,
            sampleSizes: sampleSizes, stcoEntryOffsets: stcoEntryOffsets)
    }

    /// Builds a `tref` atom containing a `chap` reference to one or more chapter tracks.
    /// - Parameter chapterTrackIDs: The track IDs of the chapter tracks (text, video, etc.).
    /// - Returns: Complete `tref` atom data.
    public func buildTrefChap(chapterTrackIDs: [UInt32]) -> Data {
        var chapPayload = BinaryWriter(capacity: chapterTrackIDs.count * 4)
        for trackID in chapterTrackIDs {
            chapPayload.writeUInt32(trackID)
        }
        let chapAtom = atomBuilder.buildAtom(type: "chap", data: chapPayload.data)
        return atomBuilder.buildContainerAtom(type: "tref", children: [chapAtom])
    }
}

// MARK: - Track Header

extension MP4TextTrackBuilder {

    /// Builds a `tkhd` atom for a disabled text track (version 0).
    private func buildTkhd(
        trackID: UInt32, movieTimescale: UInt32, movieDuration: UInt64
    ) -> Data {
        var payload = BinaryWriter(capacity: 84)
        payload.writeUInt8(0)  // version
        // flags: 0 (track disabled — chapter tracks should not be user-visible)
        payload.writeRepeating(0x00, count: 3)
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(trackID)
        payload.writeUInt32(0)  // reserved
        // Duration in movie timescale.
        payload.writeUInt32(UInt32(clamping: movieDuration))
        // Reserved (8 bytes) + layer (2) + alternate group (2) + volume (2) + reserved (2).
        payload.writeRepeating(0x00, count: 16)
        // Identity matrix (36 bytes).
        writeIdentityMatrix(to: &payload)
        // Width and height (0 for text track).
        payload.writeUInt32(0)
        payload.writeUInt32(0)
        return atomBuilder.buildAtom(type: "tkhd", data: payload.data)
    }

    /// Writes a 3x3 identity matrix in fixed-point 16.16 / 2.30 format.
    private func writeIdentityMatrix(to writer: inout BinaryWriter) {
        // | 1.0  0.0  0.0 |
        // | 0.0  1.0  0.0 |
        // | 0.0  0.0  1.0 |  (last row uses 2.30 fixed-point)
        writer.writeUInt32(0x0001_0000)  // 1.0 (16.16)
        writer.writeUInt32(0)
        writer.writeUInt32(0)
        writer.writeUInt32(0)
        writer.writeUInt32(0x0001_0000)  // 1.0 (16.16)
        writer.writeUInt32(0)
        writer.writeUInt32(0)
        writer.writeUInt32(0)
        writer.writeUInt32(0x4000_0000)  // 1.0 (2.30)
    }
}

// MARK: - Media Header & Handler

extension MP4TextTrackBuilder {

    /// Builds an `mdhd` atom (version 0) with timescale and duration.
    private func buildMdhd(timescale: UInt32, duration: UInt32) -> Data {
        var payload = BinaryWriter(capacity: 24)
        payload.writeUInt8(0)  // version
        payload.writeRepeating(0x00, count: 3)  // flags
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt32(duration)
        payload.writeUInt16(0x55C4)  // language: undetermined
        payload.writeUInt16(0)  // pre_defined
        return atomBuilder.buildAtom(type: "mdhd", data: payload.data)
    }

    /// Builds an `hdlr` atom for a text handler.
    private func buildHdlr() -> Data {
        var payload = BinaryWriter(capacity: 33)
        payload.writeUInt8(0)  // version
        payload.writeRepeating(0x00, count: 3)  // flags
        payload.writeUInt32(0)  // pre_defined
        payload.writeLatin1String("text")  // handler_type
        payload.writeRepeating(0x00, count: 12)  // reserved
        payload.writeNullTerminatedLatin1String("ChapterHandler")
        return atomBuilder.buildAtom(type: "hdlr", data: payload.data)
    }
}

// MARK: - Media Information

extension MP4TextTrackBuilder {

    /// Builds the `minf` container (gmhd + dinf + stbl).
    private func buildMinf(
        sampleDurations: [(count: UInt32, duration: UInt32)],
        sampleSizes: [UInt32],
        sampleCount: Int
    ) -> Data {
        let gmhd = buildGmhd()
        let dinf = buildDinf()
        let stbl = buildStbl(
            sampleDurations: sampleDurations,
            sampleSizes: sampleSizes,
            sampleCount: sampleCount)
        return atomBuilder.buildContainerAtom(type: "minf", children: [gmhd, dinf, stbl])
    }

    /// Builds a `gmhd` (generic media header) with `gmin` sub-atom.
    private func buildGmhd() -> Data {
        // gmin: version(1) + flags(3) + graphicsMode(2) + opcolor(6) + balance(2) + reserved(2)
        var gminPayload = BinaryWriter(capacity: 16)
        gminPayload.writeUInt8(0)  // version
        gminPayload.writeRepeating(0x00, count: 3)  // flags
        gminPayload.writeUInt16(0x0040)  // graphicsMode: ditherCopy
        gminPayload.writeRepeating(0x80, count: 6)  // opcolor (gray)
        gminPayload.writeUInt16(0)  // balance
        gminPayload.writeUInt16(0)  // reserved
        let gmin = atomBuilder.buildAtom(type: "gmin", data: gminPayload.data)
        return atomBuilder.buildContainerAtom(type: "gmhd", children: [gmin])
    }

    /// Builds a `dinf → dref → url` for self-contained data.
    private func buildDinf() -> Data {
        // url atom with flags=0x000001 (self-contained).
        var urlPayload = BinaryWriter(capacity: 4)
        urlPayload.writeUInt8(0)  // version
        urlPayload.writeUInt8(0)
        urlPayload.writeUInt8(0)
        urlPayload.writeUInt8(0x01)  // flags: self-contained
        let urlAtom = atomBuilder.buildAtom(type: "url ", data: urlPayload.data)

        // dref: version(1) + flags(3) + entry_count(4) + entries.
        var drefPayload = BinaryWriter(capacity: 8 + urlAtom.count)
        drefPayload.writeUInt32(0)  // version + flags
        drefPayload.writeUInt32(1)  // entry count
        drefPayload.writeData(urlAtom)
        let dref = atomBuilder.buildAtom(type: "dref", data: drefPayload.data)

        return atomBuilder.buildContainerAtom(type: "dinf", children: [dref])
    }
}

// MARK: - Sample Table

extension MP4TextTrackBuilder {

    /// Builds the `stbl` container with all sample table atoms.
    private func buildStbl(
        sampleDurations: [(count: UInt32, duration: UInt32)],
        sampleSizes: [UInt32],
        sampleCount: Int
    ) -> Data {
        let stsd = buildStsd()
        let stts = buildStts(entries: sampleDurations)
        let stsc = buildStsc()
        let stsz = buildStsz(sizes: sampleSizes)
        let stco = buildStco(entryCount: sampleCount)
        return atomBuilder.buildContainerAtom(
            type: "stbl", children: [stsd, stts, stsc, stsz, stco])
    }

    /// Builds a minimal `stsd` with a complete QuickTime text sample description.
    private func buildStsd() -> Data {
        // Complete QuickTime text sample description (59 bytes):
        // size(4) + format(4) + reserved(6) + data_ref_index(2)
        // + displayFlags(4) + textJustification(4) + bgColor(6)
        // + defaultTextBox(8) + reserved(8) + fontNumber(2) + fontFace(2)
        // + reserved(1) + fontSize(2) + fgColor(6)
        var textDesc = BinaryWriter(capacity: 59)
        textDesc.writeUInt32(59)  // size of this description
        textDesc.writeLatin1String("text")  // format
        textDesc.writeRepeating(0x00, count: 6)  // reserved
        textDesc.writeUInt16(1)  // data reference index
        textDesc.writeUInt32(0)  // displayFlags
        textDesc.writeUInt32(1)  // textJustification: center
        textDesc.writeRepeating(0x00, count: 6)  // background color (black)
        textDesc.writeRepeating(0x00, count: 8)  // default text box
        textDesc.writeRepeating(0x00, count: 8)  // reserved
        textDesc.writeUInt16(0)  // font number
        textDesc.writeUInt16(0)  // font face
        textDesc.writeUInt8(0)  // reserved
        textDesc.writeUInt16(12)  // font size
        textDesc.writeRepeating(0xFF, count: 6)  // foreground color (white)

        var stsdPayload = BinaryWriter(capacity: 8 + textDesc.count)
        stsdPayload.writeUInt32(0)  // version + flags
        stsdPayload.writeUInt32(1)  // entry count
        stsdPayload.writeData(textDesc.data)
        return atomBuilder.buildAtom(type: "stsd", data: stsdPayload.data)
    }

    /// Builds an `stts` atom from run-length encoded durations.
    private func buildStts(entries: [(count: UInt32, duration: UInt32)]) -> Data {
        var payload = BinaryWriter(capacity: 8 + entries.count * 8)
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(UInt32(entries.count))
        for entry in entries {
            payload.writeUInt32(entry.count)
            payload.writeUInt32(entry.duration)
        }
        return atomBuilder.buildAtom(type: "stts", data: payload.data)
    }

    /// Builds an `stsc` atom: one chunk per sample.
    private func buildStsc() -> Data {
        var payload = BinaryWriter(capacity: 20)
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(1)  // entry count
        payload.writeUInt32(1)  // first_chunk
        payload.writeUInt32(1)  // samples_per_chunk
        payload.writeUInt32(1)  // sample_description_index
        return atomBuilder.buildAtom(type: "stsc", data: payload.data)
    }

    /// Builds an `stsz` atom with per-sample sizes.
    private func buildStsz(sizes: [UInt32]) -> Data {
        var payload = BinaryWriter(capacity: 12 + sizes.count * 4)
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(0)  // default size (0 = per-sample)
        payload.writeUInt32(UInt32(sizes.count))
        for size in sizes {
            payload.writeUInt32(size)
        }
        return atomBuilder.buildAtom(type: "stsz", data: payload.data)
    }

    /// Builds an `stco` atom with placeholder zero offsets.
    private func buildStco(entryCount: Int) -> Data {
        var payload = BinaryWriter(capacity: 8 + entryCount * 4)
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(UInt32(entryCount))
        for _ in 0..<entryCount {
            payload.writeUInt32(0)  // placeholder
        }
        return atomBuilder.buildAtom(type: "stco", data: payload.data)
    }
}

// MARK: - Sample Durations

extension MP4TextTrackBuilder {

    /// Calculates per-chapter durations for the stts atom.
    ///
    /// Each chapter's duration extends to the next chapter's start time.
    /// The last chapter extends to the media duration.
    private func buildSampleDurations(
        chapters: ChapterList,
        mediaDuration: UInt32,
        mediaTimescale: UInt32
    ) -> [(count: UInt32, duration: UInt32)] {
        var entries: [(count: UInt32, duration: UInt32)] = []
        for index in chapters.indices {
            let startMs = UInt32(chapters[index].start.timeInterval * Double(mediaTimescale))
            let endMs: UInt32
            if index + 1 < chapters.count {
                endMs = UInt32(chapters[index + 1].start.timeInterval * Double(mediaTimescale))
            } else {
                endMs = mediaDuration
            }
            let duration = endMs > startMs ? endMs - startMs : 1
            entries.append((count: 1, duration: duration))
        }
        return entries
    }
}

// MARK: - Stco Offset Finding

extension MP4TextTrackBuilder {

    /// Finds the byte positions of stco entries within the trak data.
    ///
    /// Scans the binary data for the stco atom and returns the offsets
    /// of each 4-byte entry value within the trak data.
    private func findStcoEntryOffsets(in trakData: Data, entryCount: Int) -> [Int] {
        let stcoType = Data("stco".utf8)
        var position = 0

        while position + 8 <= trakData.count {
            // Look for "stco" type identifier.
            if position + 4 <= trakData.count - 3,
                trakData[position + 4] == stcoType[0],
                trakData[position + 5] == stcoType[1],
                trakData[position + 6] == stcoType[2],
                trakData[position + 7] == stcoType[3]
            {
                // Found stco. Entries start after: size(4) + type(4) + version+flags(4) + count(4)
                let entriesStart = position + 16
                var offsets: [Int] = []
                for index in 0..<entryCount {
                    offsets.append(entriesStart + index * 4)
                }
                return offsets
            }
            position += 1
        }
        return []
    }
}
