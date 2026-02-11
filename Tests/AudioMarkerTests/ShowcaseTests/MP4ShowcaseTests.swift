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

    // MARK: - Helpers

    /// Builds an MP4 file with metadata and an mdat atom (required for write/strip).
    private func buildMP4WithMdat(ilstItems: [Data]) -> Data {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: ilstItems)
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, udta])
        let mdat = MP4TestHelper.buildAtom(type: "mdat", data: Data(repeating: 0xFF, count: 128))
        var file = Data()
        file.append(ftyp)
        file.append(moov)
        file.append(mdat)
        return file
    }
}
