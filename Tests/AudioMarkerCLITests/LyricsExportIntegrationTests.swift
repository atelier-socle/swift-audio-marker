import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCLI

@Suite("CLI Lyrics Export Integration")
struct LyricsExportIntegrationTests {

    // MARK: - Export LRC

    @Test("Lyrics export produces LRC from SYLT")
    func exportLRC() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0),
            (text: "World", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Lyrics.Export.parse([url.path, "--format", "lrc"])
        try cmd.run()
    }

    // MARK: - Export TTML

    @Test("Lyrics export produces TTML from SYLT")
    func exportTTML() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0),
            (text: "World", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Lyrics.Export.parse([url.path, "--format", "ttml"])
        try cmd.run()
    }

    // MARK: - Export to File

    @Test("Lyrics export writes to --to file")
    func exportToFile() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0),
            (text: "World", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".lrc")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var cmd = try Lyrics.Export.parse([url.path, "--to", outputURL.path, "--format", "lrc"])
        try cmd.run()

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(content.contains("Hello"))
        #expect(content.contains("World"))
    }

    // MARK: - No Sync Lyrics Error

    @Test("Lyrics export throws when no synchronized lyrics")
    func exportNoSyncLyricsThrows() throws {
        let url = try CLITestHelper.createMP3(title: "No Lyrics")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Lyrics.Export.parse([url.path])
        #expect(throws: Error.self) {
            try cmd.run()
        }
    }

    // MARK: - Parsing

    @Test("Lyrics export parses format option")
    func parseFormat() throws {
        let cmd = try Lyrics.Export.parse(["song.mp3", "--format", "ttml"])
        #expect(cmd.format == "ttml")
    }

    @Test("Lyrics export defaults to lrc format")
    func defaultFormat() throws {
        let cmd = try Lyrics.Export.parse(["song.mp3"])
        #expect(cmd.format == "lrc")
    }

    // MARK: - Unsupported Format

    @Test("Lyrics export with unsupported format throws")
    func unsupportedFormatThrows() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Lyrics.Export.parse([url.path, "--format", "markdown"])
        #expect(throws: Error.self) {
            try cmd.run()
        }
    }
}
