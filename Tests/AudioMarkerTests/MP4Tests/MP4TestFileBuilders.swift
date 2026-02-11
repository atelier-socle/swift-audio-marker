import Foundation

@testable import AudioMarker

// MARK: - Dual Text Track Builder

extension MP4TestHelper {

    /// Components needed to rebuild a text track with correct offsets.
    struct TextTrackComponents {
        let trak: Data
        let stts: Data
        let stsz: Data
        let stsc: Data
        let hdlr: Data
        let mdhd: Data
    }

    /// Builds an MP4 with two text tracks (simulating GarageBand Enhanced Podcast).
    ///
    /// Track 1: clean titles (no URLs). Track 2: titles + href URLs.
    /// An audio trak with tref/chap references both text track IDs.
    static func buildMP4WithDualTextTracks(
        titlesOnly: [String],
        titlesWithURLs: [(title: String, url: String)],
        timescale: UInt32 = 1000,
        sampleDuration: UInt32 = 10_000
    ) -> Data {
        let textTrackID: UInt32 = 2
        let urlTrackID: UInt32 = 3

        // Build text track 1 (titles only).
        var samples1: [Data] = []
        for title in titlesOnly {
            samples1.append(buildTx3gSample(title: title))
        }
        let track1 = buildTextTrackComponents(
            samples: samples1, trackID: textTrackID,
            timescale: timescale, sampleDuration: sampleDuration
        )

        // Build text track 2 (titles + URLs).
        var samples2: [Data] = []
        for ch in titlesWithURLs {
            samples2.append(buildTx3gSample(title: ch.title, url: ch.url))
        }
        let track2 = buildTextTrackComponents(
            samples: samples2, trackID: urlTrackID,
            timescale: timescale, sampleDuration: sampleDuration
        )

        // Audio track with tref/chap.
        let audioHdlr = buildHdlrAtom(handlerType: "soun")
        let audioMdhd = buildMdhdAtom(timescale: timescale)
        let audioMinf = buildContainerAtom(type: "minf", children: [])
        let audioMdia = buildContainerAtom(
            type: "mdia", children: [audioMdhd, audioHdlr, audioMinf])
        let audioTkhd = buildTkhdAtom(trackID: 1, flags: 0x000001)
        let trefChap = buildTrefChap(trackIDs: [textTrackID, urlTrackID])
        let audioTrak = buildContainerAtom(
            type: "trak", children: [audioTkhd, audioMdia, trefChap])

        let ftyp = buildFtyp()
        let maxSamples = UInt32(max(titlesOnly.count, titlesWithURLs.count))
        let totalDuration = maxSamples * sampleDuration
        let mvhd = buildMVHD(timescale: timescale, duration: totalDuration)

        // First pass to compute moov size.
        let moov = buildContainerAtom(
            type: "moov", children: [mvhd, audioTrak, track1.trak, track2.trak])
        let headerSize = UInt32(ftyp.count + moov.count)

        // Rebuild with correct stco offsets.
        let track1Fixed = rebuildTrackWithOffsets(
            components: track1, samples: samples1, baseOffset: headerSize)
        let offset2 = headerSize + UInt32(samples1.reduce(0) { $0 + $1.count })
        let track2Fixed = rebuildTrackWithOffsets(
            components: track2, samples: samples2, baseOffset: offset2)

        let moovFixed = buildContainerAtom(
            type: "moov", children: [mvhd, audioTrak, track1Fixed.trak, track2Fixed.trak])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        for s in samples1 { file.append(s) }
        for s in samples2 { file.append(s) }
        return file
    }

    /// Builds the trak atom components for a text track.
    private static func buildTextTrackComponents(
        samples: [Data],
        trackID: UInt32,
        timescale: UInt32,
        sampleDuration: UInt32
    ) -> TextTrackComponents {
        let sampleSizes = samples.map { UInt32($0.count) }
        let sampleCount = UInt32(samples.count)
        let hdlr = buildHdlrAtom(handlerType: "text")
        let mdhd = buildMdhdAtom(timescale: timescale)
        let tkhd = buildTkhdAtom(trackID: trackID)
        let stts = buildSttsAtom(entries: [(count: sampleCount, duration: sampleDuration)])
        let stco = buildStcoAtom(offsets: [UInt32](repeating: 0, count: samples.count))
        let stsz = buildStszAtom(defaultSize: 0, sizes: sampleSizes)
        let stsc = buildStscAtom()
        let stbl = buildContainerAtom(type: "stbl", children: [stts, stco, stsz, stsc])
        let minf = buildContainerAtom(type: "minf", children: [stbl])
        let mdia = buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = buildContainerAtom(type: "trak", children: [tkhd, mdia])
        return TextTrackComponents(
            trak: trak, stts: stts, stsz: stsz, stsc: stsc, hdlr: hdlr, mdhd: mdhd)
    }

    /// Rebuilds a text track with correct stco offsets.
    private static func rebuildTrackWithOffsets(
        components: TextTrackComponents,
        samples: [Data],
        baseOffset: UInt32
    ) -> TextTrackComponents {
        var offset = baseOffset
        var offsets: [UInt32] = []
        for sample in samples {
            offsets.append(offset)
            offset += UInt32(sample.count)
        }
        let stco = buildStcoAtom(offsets: offsets)
        let stbl = buildContainerAtom(
            type: "stbl", children: [components.stts, stco, components.stsz, components.stsc])
        let minf = buildContainerAtom(type: "minf", children: [stbl])
        let mdia = buildContainerAtom(
            type: "mdia", children: [components.mdhd, components.hdlr, minf])

        // Extract tkhd from original trak (first child: size(4)+type(4)+payload(84)).
        let tkhd = Data(components.trak[8..<(8 + 92)])
        let trak = buildContainerAtom(type: "trak", children: [tkhd, mdia])
        return TextTrackComponents(
            trak: trak, stts: components.stts, stsz: components.stsz,
            stsc: components.stsc, hdlr: components.hdlr, mdhd: components.mdhd)
    }
}

// MARK: - Complete File Builders

extension MP4TestHelper {

    /// Builds a minimal valid MP4 file with ftyp + moov (containing mvhd).
    static func buildMinimalMP4(
        majorBrand: String = "M4A ",
        timescale: UInt32 = 44100,
        duration: UInt32 = 441_000
    ) -> Data {
        let ftyp = buildFtyp(majorBrand: majorBrand)
        let mvhd = buildMVHD(timescale: timescale, duration: duration)
        let moov = buildContainerAtom(type: "moov", children: [mvhd])
        var file = Data()
        file.append(ftyp)
        file.append(moov)
        return file
    }

    /// Builds an MP4 file with metadata in the ilst atom.
    static func buildMP4WithMetadata(ilstItems: [Data]) -> Data {
        let ftyp = buildFtyp()
        let mvhd = buildMVHD(timescale: 44100, duration: 441_000)
        let ilst = buildContainerAtom(type: "ilst", children: ilstItems)
        let meta = buildMetaAtom(children: [ilst])
        let udta = buildContainerAtom(type: "udta", children: [meta])
        let moov = buildContainerAtom(type: "moov", children: [mvhd, udta])
        var file = Data()
        file.append(ftyp)
        file.append(moov)
        return file
    }

    /// Builds an MP4 file with Nero chapters.
    static func buildMP4WithNeroChapters(
        chapters: [(startTime100ns: UInt64, title: String)]
    ) -> Data {
        let ftyp = buildFtyp()
        let mvhd = buildMVHD(timescale: 44100, duration: 441_000)
        let chpl = buildChplAtom(chapters: chapters)
        let udta = buildContainerAtom(type: "udta", children: [chpl])
        let moov = buildContainerAtom(type: "moov", children: [mvhd, udta])
        var file = Data()
        file.append(ftyp)
        file.append(moov)
        return file
    }

    /// Builds an MP4 file with a QuickTime text chapter track.
    static func buildMP4WithQuickTimeChapters(
        titles: [String],
        timescale: UInt32 = 1000,
        sampleDuration: UInt32 = 10_000
    ) -> Data {
        // Build chapter text samples.
        var sampleData: [Data] = []
        for text in titles {
            var writer = BinaryWriter()
            let textBytes = Data(text.utf8)
            writer.writeUInt16(UInt16(textBytes.count))
            writer.writeData(textBytes)
            sampleData.append(writer.data)
        }

        let sampleSizes = sampleData.map { UInt32($0.count) }
        let sampleCount = UInt32(titles.count)

        // Build track atoms with placeholder offsets.
        let hdlr = buildHdlrAtom(handlerType: "text")
        let mdhd = buildMdhdAtom(timescale: timescale)
        let stts = buildSttsAtom(entries: [(count: sampleCount, duration: sampleDuration)])
        let stco = buildStcoAtom(offsets: [UInt32](repeating: 0, count: titles.count))
        let stsz = buildStszAtom(defaultSize: 0, sizes: sampleSizes)
        let stsc = buildStscAtom()

        let stbl = buildContainerAtom(type: "stbl", children: [stts, stco, stsz, stsc])
        let minf = buildContainerAtom(type: "minf", children: [stbl])
        let mdia = buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = buildContainerAtom(type: "trak", children: [mdia])

        let ftyp = buildFtyp()
        let totalDuration = sampleCount * sampleDuration
        let mvhd = buildMVHD(timescale: timescale, duration: totalDuration)
        let moov = buildContainerAtom(type: "moov", children: [mvhd, trak])

        // Calculate actual sample offsets.
        let sampleDataStart = UInt32(ftyp.count + moov.count)
        var actualOffsets: [UInt32] = []
        var offset = sampleDataStart
        for sample in sampleData {
            actualOffsets.append(offset)
            offset += UInt32(sample.count)
        }

        // Rebuild with correct offsets.
        let stcoFixed = buildStcoAtom(offsets: actualOffsets)
        let stblFixed = buildContainerAtom(type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = buildContainerAtom(type: "moov", children: [mvhd, trakFixed])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        for sample in sampleData {
            file.append(sample)
        }
        return file
    }

    /// Builds an MP4 with QuickTime chapters that include href URLs.
    static func buildMP4WithQuickTimeChaptersAndURLs(
        chapters: [(title: String, url: String?)],
        timescale: UInt32 = 1000,
        sampleDuration: UInt32 = 10_000
    ) -> Data {
        var sampleData: [Data] = []
        for chapter in chapters {
            sampleData.append(buildTx3gSample(title: chapter.title, url: chapter.url))
        }

        let sampleSizes = sampleData.map { UInt32($0.count) }
        let sampleCount = UInt32(chapters.count)

        let hdlr = buildHdlrAtom(handlerType: "text")
        let mdhd = buildMdhdAtom(timescale: timescale)
        let stts = buildSttsAtom(entries: [(count: sampleCount, duration: sampleDuration)])
        let stco = buildStcoAtom(offsets: [UInt32](repeating: 0, count: chapters.count))
        let stsz = buildStszAtom(defaultSize: 0, sizes: sampleSizes)
        let stsc = buildStscAtom()

        let stbl = buildContainerAtom(type: "stbl", children: [stts, stco, stsz, stsc])
        let minf = buildContainerAtom(type: "minf", children: [stbl])
        let mdia = buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = buildContainerAtom(type: "trak", children: [mdia])

        let ftyp = buildFtyp()
        let totalDuration = sampleCount * sampleDuration
        let mvhd = buildMVHD(timescale: timescale, duration: totalDuration)
        let moov = buildContainerAtom(type: "moov", children: [mvhd, trak])

        // Calculate actual offsets.
        let sampleDataStart = UInt32(ftyp.count + moov.count)
        var actualOffsets: [UInt32] = []
        var offset = sampleDataStart
        for sample in sampleData {
            actualOffsets.append(offset)
            offset += UInt32(sample.count)
        }

        let stcoFixed = buildStcoAtom(offsets: actualOffsets)
        let stblFixed = buildContainerAtom(type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = buildContainerAtom(type: "moov", children: [mvhd, trakFixed])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        for sample in sampleData {
            file.append(sample)
        }
        return file
    }

    // MARK: - File Helpers

    /// Creates a temporary file with the given data.
    static func createTempFile(data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        try data.write(to: url)
        return url
    }
}
