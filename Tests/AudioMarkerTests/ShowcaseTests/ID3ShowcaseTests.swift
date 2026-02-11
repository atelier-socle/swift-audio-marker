import Foundation
import Testing

@testable import AudioMarker

/// Demonstrates complete MP3/ID3v2 round-trip workflows: metadata, chapters, lyrics, artwork, strip.
@Suite("Showcase: MP3 / ID3v2")
struct ID3ShowcaseTests {

    let engine = AudioMarkerEngine()

    // MARK: - Metadata Round-Trip

    @Test("Read and write MP3 metadata — complete round-trip")
    func metadataRoundTrip() throws {
        // Build a synthetic MP3 with metadata
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 64)
        let frames: [Data] = [
            ID3TestHelper.buildTextFrame(id: "TIT2", text: "Original Title"),
            ID3TestHelper.buildTextFrame(id: "TPE1", text: "Artist"),
            ID3TestHelper.buildTextFrame(id: "TALB", text: "Album"),
            ID3TestHelper.buildTextFrame(id: "TCON", text: "Electronic"),
            ID3TestHelper.buildTextFrame(id: "TYER", text: "2025"),
            ID3TestHelper.buildTextFrame(id: "TRCK", text: "5"),
            ID3TestHelper.buildAPICFrame(imageData: jpegData)
        ]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Read and verify all fields
        let info = try engine.read(from: url)
        #expect(info.metadata.title == "Original Title")
        #expect(info.metadata.artist == "Artist")
        #expect(info.metadata.album == "Album")
        #expect(info.metadata.genre == "Electronic")
        #expect(info.metadata.year == 2025)
        #expect(info.metadata.trackNumber == 5)
        #expect(info.metadata.artwork?.format == .jpeg)

        // Modify title without losing other fields
        var modified = info
        modified.metadata.title = "Updated Title"
        try engine.write(modified, to: url)

        // Re-read and verify everything is preserved
        let reread = try engine.read(from: url)
        #expect(reread.metadata.title == "Updated Title")
        #expect(reread.metadata.artist == "Artist")
        #expect(reread.metadata.album == "Album")
        #expect(reread.metadata.artwork?.format == .jpeg)
    }

    // MARK: - Chapters

    @Test("MP3 chapters — CHAP and CTOC frames")
    func chaptersRoundTrip() throws {
        // Create an MP3 with 3 chapters
        let chap1 = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 0, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Opening")])
        let chap2 = ID3TestHelper.buildCHAPFrame(
            elementID: "ch2", startTime: 60_000, endTime: 120_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Main")])
        let chap3 = ID3TestHelper.buildCHAPFrame(
            elementID: "ch3", startTime: 180_000, endTime: 300_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Closing")])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [chap1, chap2, chap3])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Read chapters
        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Opening")
        #expect(chapters[1].title == "Main")
        #expect(chapters[2].title == "Closing")

        // Verify timestamps
        #expect(chapters[0].start == .zero)
        #expect(chapters[1].start == .milliseconds(60_000))
        #expect(chapters[2].start == .milliseconds(180_000))

        // Add a chapter, sort, and rewrite
        var allChapters = ChapterList(Array(chapters))
        allChapters.append(Chapter(start: .milliseconds(120_000), title: "Interlude"))
        allChapters.sort()
        try engine.writeChapters(allChapters, to: url)

        // Verify the new order
        let updated = try engine.readChapters(from: url)
        #expect(updated.count == 4)
        #expect(updated[0].title == "Opening")
        #expect(updated[1].title == "Main")
        #expect(updated[2].title == "Interlude")
        #expect(updated[3].title == "Closing")
    }

    // MARK: - Synchronized Lyrics

    @Test("MP3 synchronized lyrics — SYLT frames")
    func syncLyricsRoundTrip() throws {
        // Build MP3 with SYLT frame
        let syltFrame = ID3TestHelper.buildSYLTFrame(
            language: "eng",
            contentType: 1,
            events: [
                (text: "Hello world", timestamp: 0),
                (text: "Second line", timestamp: 3500),
                (text: "Final words", timestamp: 7000)
            ])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [syltFrame])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Read and verify
        let info = try engine.read(from: url)
        #expect(!info.metadata.synchronizedLyrics.isEmpty)

        let lyrics = info.metadata.synchronizedLyrics[0]
        #expect(lyrics.language == "eng")
        #expect(lyrics.contentType == .lyrics)
        #expect(lyrics.lines.count == 3)
        #expect(lyrics.lines[0].text == "Hello world")
        #expect(lyrics.lines[1].time == .milliseconds(3500))
    }

    // MARK: - Unsynchronized Lyrics

    @Test("MP3 unsynchronized lyrics — USLT frame")
    func unsyncLyricsRoundTrip() throws {
        let multiline = "Verse one lyrics\nSecond line\nThird line"
        let usltFrame = ID3TestHelper.buildUSLTFrame(text: multiline)
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [usltFrame])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try engine.read(from: url)
        #expect(info.metadata.unsynchronizedLyrics == multiline)
    }

    // MARK: - Strip

    @Test("MP3 strip — remove all metadata")
    func stripMP3() throws {
        // Create a full MP3 with metadata + chapters + artwork
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 32)
        let frames: [Data] = [
            ID3TestHelper.buildTextFrame(id: "TIT2", text: "Strip Test"),
            ID3TestHelper.buildTextFrame(id: "TPE1", text: "Artist"),
            ID3TestHelper.buildAPICFrame(imageData: jpegData),
            ID3TestHelper.buildCHAPFrame(
                elementID: "ch1", startTime: 0, endTime: 60_000,
                subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chapter")])
        ]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Verify data exists before strip
        let before = try engine.read(from: url)
        #expect(before.metadata.title == "Strip Test")
        #expect(before.metadata.artwork != nil)
        #expect(!before.chapters.isEmpty)

        // Strip removes the entire ID3 tag
        try engine.strip(from: url)

        // After stripping, the MP3 no longer has an ID3 tag — reading throws
        #expect(throws: AudioMarkerError.self) {
            _ = try engine.read(from: url)
        }
    }
}
