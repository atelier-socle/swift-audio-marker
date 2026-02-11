import Foundation
import Testing

@testable import AudioMarker

/// Demonstrates complete M4A/MP4 round-trip workflows: metadata, chapters, lyrics, strip.
@Suite("Showcase: M4A / MP4")
struct MP4ShowcaseTests {

    let engine = AudioMarkerEngine()

    // MARK: - Metadata Round-Trip

    @Test("Read and write M4A metadata — complete round-trip")
    func metadataRoundTrip() throws {
        // Build a synthetic M4A with metadata (including mdat for write support)
        let pngData = Data([0x89, 0x50, 0x4E, 0x47]) + Data(repeating: 0x00, count: 64)
        let ilstItems: [Data] = [
            MP4TestHelper.buildILSTTextItem(type: "\u{00A9}nam", text: "Original Title"),
            MP4TestHelper.buildILSTTextItem(type: "\u{00A9}ART", text: "Artist"),
            MP4TestHelper.buildILSTTextItem(type: "\u{00A9}alb", text: "Album"),
            MP4TestHelper.buildILSTTextItem(type: "\u{00A9}gen", text: "Jazz"),
            MP4TestHelper.buildILSTTextItem(type: "\u{00A9}day", text: "2025"),
            MP4TestHelper.buildILSTIntegerPair(type: "trkn", value: 7),
            MP4TestHelper.buildILSTArtwork(typeIndicator: 14, imageData: pngData)
        ]
        let fileData = buildMP4WithMdat(ilstItems: ilstItems)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        // Read and verify
        let info = try engine.read(from: url)
        #expect(info.metadata.title == "Original Title")
        #expect(info.metadata.artist == "Artist")
        #expect(info.metadata.album == "Album")
        #expect(info.metadata.genre == "Jazz")
        #expect(info.metadata.year == 2025)
        #expect(info.metadata.trackNumber == 7)
        #expect(info.metadata.artwork?.format == .png)

        // Modify and rewrite
        var modified = info
        modified.metadata.title = "Updated Title"
        try engine.write(modified, to: url)

        // Re-read and verify preservation
        let reread = try engine.read(from: url)
        #expect(reread.metadata.title == "Updated Title")
        #expect(reread.metadata.artist == "Artist")
    }

    // MARK: - Chapters

    @Test("M4A chapters — nero-style chpl chapters")
    func chaptersRoundTrip() throws {
        // Build M4A with Nero chapters (startTime in 100-nanosecond units)
        let fileData = MP4TestHelper.buildMP4WithNeroChapters(chapters: [
            (startTime100ns: 0, title: "Intro"),
            (startTime100ns: 600_000_000, title: "Verse"),
            (startTime100ns: 1_200_000_000, title: "Chorus")
        ])
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        // Read and verify
        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Intro")
        #expect(chapters[1].title == "Verse")
        #expect(chapters[2].title == "Chorus")
    }

    // MARK: - Lyrics

    @Test("M4A lyrics — text atom")
    func lyricsRoundTrip() throws {
        // Build M4A with lyrics in the ilst
        let ilstItems: [Data] = [
            MP4TestHelper.buildILSTTextItem(type: "\u{00A9}nam", text: "Song"),
            MP4TestHelper.buildILSTTextItem(type: "\u{00A9}lyr", text: "These are the lyrics")
        ]
        let fileData = MP4TestHelper.buildMP4WithMetadata(ilstItems: ilstItems)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try engine.read(from: url)
        #expect(info.metadata.unsynchronizedLyrics == "These are the lyrics")
    }

    // MARK: - Strip

    @Test("M4A strip — remove all metadata")
    func stripM4A() throws {
        let ilstItems: [Data] = [
            MP4TestHelper.buildILSTTextItem(type: "\u{00A9}nam", text: "Strip Me"),
            MP4TestHelper.buildILSTTextItem(type: "\u{00A9}ART", text: "Artist")
        ]
        let fileData = buildMP4WithMdat(ilstItems: ilstItems)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        // Verify data exists
        let before = try engine.read(from: url)
        #expect(before.metadata.title == "Strip Me")

        // Strip
        try engine.strip(from: url)

        // Verify everything is gone
        let after = try engine.read(from: url)
        #expect(after.metadata.title == nil)
        #expect(after.metadata.artist == nil)
    }

    // MARK: - Chapter URLs & Artwork

    @Test("M4A chapter URL round-trip")
    func m4aChapterURLRoundTrip() throws {
        let fileData = buildMP4WithMdat(ilstItems: [])
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "With URL",
                url: URL(string: "https://example.com/chapter1")),
            Chapter(start: .seconds(30.0), title: "No URL")
        ])
        try engine.write(info, to: url)

        let readBack = try engine.read(from: url)
        #expect(readBack.chapters.count == 2)
        #expect(readBack.chapters[0].url?.absoluteString == "https://example.com/chapter1")
        #expect(readBack.chapters[1].url == nil)
    }

    @Test("M4A chapter artwork round-trip")
    func m4aChapterArtworkRoundTrip() throws {
        let fileData = buildMP4WithMdat(ilstItems: [])
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let jpegData = MP4TestHelper.buildMinimalJPEG(size: 100)
        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "Art Chapter",
                artwork: Artwork(data: jpegData, format: .jpeg)),
            Chapter(
                start: .seconds(30.0), title: "Art Chapter 2",
                artwork: Artwork(data: jpegData, format: .jpeg))
        ])
        try engine.write(info, to: url)

        let readBack = try engine.read(from: url)
        #expect(readBack.chapters.count == 2)
        #expect(readBack.chapters[0].artwork?.format == .jpeg)
        #expect(readBack.chapters[0].artwork?.data == jpegData)
    }

    @Test("M4A chapter URL and artwork round-trip")
    func m4aChapterURLAndArtworkRoundTrip() throws {
        let fileData = buildMP4WithMdat(ilstItems: [])
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let jpegData = MP4TestHelper.buildMinimalJPEG(size: 80)
        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "Full Chapter",
                url: URL(string: "https://example.com"),
                artwork: Artwork(data: jpegData, format: .jpeg)),
            Chapter(
                start: .seconds(30.0), title: "Second",
                url: URL(string: "https://example.com/2"),
                artwork: Artwork(data: jpegData, format: .jpeg))
        ])
        try engine.write(info, to: url)

        let readBack = try engine.read(from: url)
        #expect(readBack.chapters.count == 2)
        #expect(readBack.chapters[0].url?.absoluteString == "https://example.com")
        #expect(readBack.chapters[0].artwork?.format == .jpeg)
        #expect(readBack.chapters[1].url?.absoluteString == "https://example.com/2")
        #expect(readBack.chapters[1].artwork?.format == .jpeg)
    }

    // MARK: - Helpers

    /// Builds an MP4 file with metadata, audio track, and mdat (required for write/strip).
    private func buildMP4WithMdat(ilstItems: [Data]) -> Data {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: ilstItems)
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])

        // Audio track (required for tref/chap during chapter write).
        let mdatContent = Data(repeating: 0xFF, count: 128)
        let stco = MP4TestHelper.buildStcoAtom(offsets: [0])
        let stsz = MP4TestHelper.buildStszAtom(
            defaultSize: UInt32(mdatContent.count), sizes: [])
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 441_000)])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 44100)
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [mdhd, hdlr, minf])
        let audioTrak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])

        let moov = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, audioTrak, udta])
        let mdat = MP4TestHelper.buildAtom(type: "mdat", data: mdatContent)
        var file = Data()
        file.append(ftyp)
        file.append(moov)
        file.append(mdat)
        return file
    }
}
