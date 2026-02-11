import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCommands

/// Demonstrates the CLI read command: text format, JSON format, lyrics display.
@Suite("Showcase: CLI Read")
struct CLIReadShowcaseTests {

    // MARK: - Text Format

    @Test("audiomarker read — display all metadata in text format")
    func readTextFormat() throws {
        // Create an MP3 with complete metadata
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 32)
        let frames: [Data] = [
            ID3TestHelper.buildTextFrame(id: "TIT2", text: "Showcase Song"),
            ID3TestHelper.buildTextFrame(id: "TPE1", text: "Showcase Artist"),
            ID3TestHelper.buildTextFrame(id: "TALB", text: "Showcase Album"),
            ID3TestHelper.buildTextFrame(id: "TCON", text: "Pop"),
            ID3TestHelper.buildTextFrame(id: "TYER", text: "2025"),
            ID3TestHelper.buildAPICFrame(imageData: jpegData)
        ]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Execute read command in text mode (default)
        var cmd = try Read.parse([url.path])
        try cmd.run()

        // Verify the file was read correctly by checking engine
        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.title == "Showcase Song")
        #expect(info.metadata.artist == "Showcase Artist")
    }

    // MARK: - JSON Format

    @Test("audiomarker read --format json — structured output")
    func readJSONFormat() throws {
        let url = try CLITestHelper.createMP3(title: "JSON Test")
        defer { try? FileManager.default.removeItem(at: url) }

        // Execute read with JSON format
        var cmd = try Read.parse([url.path, "--format", "json"])
        try cmd.run()
    }

    // MARK: - Lyrics Display

    @Test("audiomarker read — shows lyrics when present")
    func readWithLyrics() throws {
        // Create MP3 with both unsynchronized and synchronized lyrics
        let frames: [Data] = [
            ID3TestHelper.buildTextFrame(id: "TIT2", text: "Lyrics Song"),
            ID3TestHelper.buildUSLTFrame(text: "Unsynchronized lyrics text here"),
            ID3TestHelper.buildSYLTFrame(events: [
                (text: "Sync line 1", timestamp: 0),
                (text: "Sync line 2", timestamp: 5000)
            ])
        ]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Read command runs without error
        var cmd = try Read.parse([url.path])
        try cmd.run()

        // Verify both lyrics types are in the data
        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.unsynchronizedLyrics != nil)
        #expect(!info.metadata.synchronizedLyrics.isEmpty)
    }
}
