import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCommands

/// Demonstrates CLI lyrics export: LRC output, TTML output, file output.
@Suite("Showcase: CLI Lyrics Export")
struct CLILyricsShowcaseTests {

    // MARK: - LRC Export

    @Test("audiomarker lyrics export --format lrc — LRC output")
    func exportLRC() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Welcome to the show", timestamp: 0),
            (text: "Here we go", timestamp: 3000),
            (text: "Goodbye", timestamp: 10_000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        // Export to stdout
        var cmd = try Lyrics.Export.parse([url.path, "--format", "lrc"])
        try cmd.run()
    }

    // MARK: - TTML Export

    @Test("audiomarker lyrics export --format ttml — TTML output")
    func exportTTML() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "First verse", timestamp: 0),
            (text: "Second verse", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Lyrics.Export.parse([url.path, "--format", "ttml"])
        try cmd.run()
    }

    // MARK: - File Output

    @Test("audiomarker lyrics export --to file — write to file")
    func exportToFile() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0),
            (text: "World", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".lrc")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var cmd = try Lyrics.Export.parse([
            url.path, "--to", outputURL.path, "--format", "lrc"
        ])
        try cmd.run()

        // Verify the output file exists and contains content
        let content = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(content.contains("Hello"))
        #expect(content.contains("World"))
    }
}
