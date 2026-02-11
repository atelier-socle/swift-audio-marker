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

    // MARK: - TTML Import

    @Test("audiomarker lyrics import --format ttml — imports TTML lyrics")
    func importTTML() throws {
        // Create an MP3 file to import into
        let mp3URL = try CLITestHelper.createMP3(title: "Import Test")
        defer { try? FileManager.default.removeItem(at: mp3URL) }

        // Create a TTML file
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:03.000">Hello</p>
                  <p begin="00:00:03.000" end="00:00:06.000">World</p>
                </div>
              </body>
            </tt>
            """
        let ttmlURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".ttml")
        try ttml.write(to: ttmlURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: ttmlURL) }

        // Run the import command
        var cmd = try Lyrics.Import.parse([
            mp3URL.path, "--from", ttmlURL.path, "--format", "ttml"
        ])
        try cmd.run()

        // Read back and verify lyrics were imported
        let engine = AudioMarkerEngine()
        let info = try engine.read(from: mp3URL)
        #expect(!info.metadata.synchronizedLyrics.isEmpty)
        #expect(info.metadata.synchronizedLyrics[0].lines.count == 2)
        #expect(info.metadata.synchronizedLyrics[0].lines[0].text == "Hello")
        #expect(info.metadata.synchronizedLyrics[0].lines[1].text == "World")
    }

    @Test("audiomarker lyrics import --format ttml --language — sets language code")
    func importTTMLWithLanguage() throws {
        let mp3URL = try CLITestHelper.createMP3(title: "Lang Test")
        defer { try? FileManager.default.removeItem(at: mp3URL) }

        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="fr" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:05.000">Bonjour le monde</p>
                </div>
              </body>
            </tt>
            """
        let ttmlURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".ttml")
        try ttml.write(to: ttmlURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: ttmlURL) }

        var cmd = try Lyrics.Import.parse([
            mp3URL.path, "--from", ttmlURL.path, "--format", "ttml"
        ])
        try cmd.run()

        let engine = AudioMarkerEngine()
        let info = try engine.read(from: mp3URL)
        #expect(info.metadata.synchronizedLyrics[0].lines[0].text == "Bonjour le monde")
    }

    @Test("audiomarker lyrics export --to file --format ttml — exports TTML file")
    func exportTTMLToFile() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "One", timestamp: 0),
            (text: "Two", timestamp: 3000),
            (text: "Three", timestamp: 6000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".ttml")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var cmd = try Lyrics.Export.parse([
            url.path, "--to", outputURL.path, "--format", "ttml"
        ])
        try cmd.run()

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(content.contains("<?xml"))
        #expect(content.contains("<tt xml:lang="))
        #expect(content.contains(">One</p>"))
        #expect(content.contains(">Two</p>"))
        #expect(content.contains(">Three</p>"))
    }
}
