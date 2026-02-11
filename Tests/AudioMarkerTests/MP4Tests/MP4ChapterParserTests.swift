import Foundation
import Testing

@testable import AudioMarker

@Suite("MP4ChapterParser")
struct MP4ChapterParserTests {

    let chapterParser = MP4ChapterParser()
    let atomParser = MP4AtomParser()

    // MARK: - Nero Chapters

    @Test("Parses Nero chapters from chpl atom")
    func parseNeroChapters() throws {
        let data = MP4TestHelper.buildMP4WithNeroChapters(
            chapters: [
                (startTime100ns: 0, title: "Intro"),
                (startTime100ns: 300_000_000, title: "Part 1"),
                (startTime100ns: 600_000_000, title: "Part 2")
            ]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Intro")
        #expect(chapters[0].start.timeInterval == 0.0)
        #expect(chapters[1].title == "Part 1")
        #expect(chapters[1].start.timeInterval == 30.0)
        #expect(chapters[2].title == "Part 2")
        #expect(chapters[2].start.timeInterval == 60.0)
    }

    @Test("Nero chapter timestamp conversion from 100ns units")
    func neroTimestampConversion() throws {
        // 10_000_000 units of 100ns = 1 second.
        let data = MP4TestHelper.buildMP4WithNeroChapters(
            chapters: [
                (startTime100ns: 0, title: "Start"),
                (startTime100ns: 10_000_000, title: "At 1s"),
                (startTime100ns: 600_000_000, title: "At 60s")
            ]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)
        #expect(chapters[1].start.timeInterval == 1.0)
        #expect(chapters[2].start.timeInterval == 60.0)
    }

    @Test("Returns empty chapter list when no chpl atom exists")
    func noChplAtom() throws {
        let data = MP4TestHelper.buildMinimalMP4()
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)
        #expect(chapters.isEmpty)
    }

    @Test("Returns empty chapter list when moov is missing")
    func noMoov() throws {
        let ftyp = MP4TestHelper.buildAtom(type: "ftyp", data: Data(repeating: 0x00, count: 4))
        let url = try MP4TestHelper.createTempFile(data: ftyp)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)
        #expect(chapters.isEmpty)
    }

    @Test("Parses single Nero chapter")
    func singleNeroChapter() throws {
        let data = MP4TestHelper.buildMP4WithNeroChapters(
            chapters: [(startTime100ns: 0, title: "Only Chapter")]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Only Chapter")
    }

    // MARK: - QuickTime Chapters

    @Test("Parses QuickTime chapter track")
    func parseQuickTimeChapters() throws {
        let fileData = MP4TestHelper.buildMP4WithQuickTimeChapters(
            titles: ["Chapter 1", "Chapter 2", "Chapter 3"]
        )
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Chapter 1")
        #expect(chapters[0].start.timeInterval == 0.0)
        #expect(chapters[1].title == "Chapter 2")
        #expect(chapters[1].start.timeInterval == 10.0)
        #expect(chapters[2].title == "Chapter 3")
        #expect(chapters[2].start.timeInterval == 20.0)
    }

    @Test("No text track returns empty chapters")
    func noTextTrack() throws {
        // Build a trak with "soun" handler instead of "text".
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [hdlr])
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])

        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trak])

        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moov)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)
        #expect(chapters.isEmpty)
    }

    // MARK: - Edge Cases

    @Test("Nero chapters with UTF-8 titles")
    func neroUTF8Titles() throws {
        let data = MP4TestHelper.buildMP4WithNeroChapters(
            chapters: [
                (startTime100ns: 0, title: "Début"),
                (startTime100ns: 100_000_000, title: "日本語チャプター")
            ]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "Début")
        #expect(chapters[1].title == "日本語チャプター")
    }

    @Test("Nero chapter with empty title gets default name")
    func neroEmptyTitle() throws {
        // Build chpl with a chapter that has title length 0.
        var payload = BinaryWriter()
        payload.writeUInt32(1)  // version
        payload.writeUInt32(0)  // reserved
        payload.writeUInt8(1)  // 1 chapter
        payload.writeUInt64(0)  // start time
        payload.writeUInt8(0)  // title length 0

        let chpl = MP4TestHelper.buildAtom(type: "chpl", data: payload.data)
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [chpl])
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, udta])

        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moov)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Chapter 1")
    }

}

// MARK: - tx3g Sample Parsing (href URLs)

extension MP4ChapterParserTests {

    @Test("Parses tx3g sample with href URL")
    func parseTx3gWithHrefURL() throws {
        let fileData = MP4TestHelper.buildMP4WithQuickTimeChaptersAndURLs(
            chapters: [
                (title: "Intro", url: "https://example.com/intro"),
                (title: "Main", url: "https://example.com/main"),
                (title: "Outro", url: nil)
            ]
        )
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)

        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Intro")
        #expect(chapters[0].url?.absoluteString == "https://example.com/intro")
        #expect(chapters[1].title == "Main")
        #expect(chapters[1].url?.absoluteString == "https://example.com/main")
        #expect(chapters[2].title == "Outro")
        #expect(chapters[2].url == nil)
    }

    @Test("Parses tx3g sample without href — URL is nil")
    func parseTx3gWithoutHref() throws {
        let fileData = MP4TestHelper.buildMP4WithQuickTimeChapters(
            titles: ["No URL Chapter"]
        )
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)

        #expect(chapters.count == 1)
        #expect(chapters[0].url == nil)
    }

    @Test("Spacer samples are filtered out")
    func parseTx3gSpacerFiltered() throws {
        // Build samples with a spacer (whitespace, duration 1).
        let regularSample = MP4TestHelper.buildTx3gSample(title: "Chapter 1")
        let spacerSample = MP4TestHelper.buildTx3gSample(title: " ")
        let nextSample = MP4TestHelper.buildTx3gSample(title: "Chapter 2")

        let sampleSizes: [UInt32] = [
            UInt32(regularSample.count),
            UInt32(spacerSample.count),
            UInt32(nextSample.count)
        ]

        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "text")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 1000)
        // Durations: 10000, 1 (spacer), 10000.
        let stts = MP4TestHelper.buildSttsAtom(entries: [
            (count: 1, duration: 10_000),
            (count: 1, duration: 1),
            (count: 1, duration: 10_000)
        ])
        let stco = MP4TestHelper.buildStcoAtom(offsets: [0, 0, 0])
        let stsz = MP4TestHelper.buildStszAtom(defaultSize: 0, sizes: sampleSizes)
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])

        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 1000, duration: 20_001)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trak])

        // Calculate offsets.
        let dataStart = UInt32(ftyp.count + moov.count)
        let offsets: [UInt32] = [
            dataStart,
            dataStart + UInt32(regularSample.count),
            dataStart + UInt32(regularSample.count) + UInt32(spacerSample.count)
        ]
        let stcoFixed = MP4TestHelper.buildStcoAtom(offsets: offsets)
        let stblFixed = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = MP4TestHelper.buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trakFixed])

        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moovFixed)
        fileData.append(regularSample)
        fileData.append(spacerSample)
        fileData.append(nextSample)

        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)

        // Spacer should be filtered out.
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "Chapter 1")
        #expect(chapters[1].title == "Chapter 2")
    }

    @Test("Malformed href atom is gracefully ignored")
    func parseTx3gMalformedHref() throws {
        // Build a tx3g sample with a truncated href atom.
        let textBytes = Data("Test".utf8)
        var writer = BinaryWriter()
        writer.writeUInt16(UInt16(textBytes.count))
        writer.writeData(textBytes)
        // Write href atom with size but truncated payload.
        writer.writeUInt32(10)  // atom size
        writer.writeLatin1String("href")
        // Only 2 bytes instead of the needed payload.
        writer.writeUInt16(0x0005)
        let sampleData = writer.data

        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "text")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 1000)
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 10_000)])
        let stsz = MP4TestHelper.buildStszAtom(defaultSize: 0, sizes: [UInt32(sampleData.count)])
        let stco = MP4TestHelper.buildStcoAtom(offsets: [0])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 1000, duration: 10_000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trak])

        let dataStart = UInt32(ftyp.count + moov.count)
        let stcoFixed = MP4TestHelper.buildStcoAtom(offsets: [dataStart])
        let stblFixed = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = MP4TestHelper.buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trakFixed])

        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moovFixed)
        fileData.append(sampleData)

        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)

        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Test")
        #expect(chapters[0].url == nil)
    }
}

// MARK: - Truncated Edge Cases

extension MP4ChapterParserTests {

    @Test("Truncated chpl payload returns nil chapters")
    func truncatedChpl() throws {
        // chpl with payload too small (< 9 bytes).
        let chpl = MP4TestHelper.buildAtom(type: "chpl", data: Data(repeating: 0x00, count: 4))
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [chpl])
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, udta])

        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moov)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)
        #expect(chapters.isEmpty)
    }
}
