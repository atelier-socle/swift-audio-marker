import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCommands

@Suite("CLI Lyrics Integration")
struct LyricsIntegrationTests {

    // MARK: - Write Unsynchronized Lyrics

    @Test("Write --lyrics sets unsynchronized lyrics")
    func writeLyricsText() throws {
        let url = try CLITestHelper.createMP3(title: "Lyrics Write Test")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Write.parse([url.path, "--lyrics", "Hello world\nSecond line"])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.unsynchronizedLyrics == "Hello world\nSecond line")
    }

    // MARK: - Write Lyrics File (unsync .txt)

    @Test("Write --lyrics-file with .txt sets unsynchronized lyrics")
    func writeLyricsFileTxt() throws {
        let url = try CLITestHelper.createMP3(title: "Lyrics File Test")
        defer { try? FileManager.default.removeItem(at: url) }

        let txtURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        defer { try? FileManager.default.removeItem(at: txtURL) }
        try "Plain text lyrics\nLine two".write(to: txtURL, atomically: true, encoding: .utf8)

        var cmd = try Write.parse([url.path, "--lyrics-file", txtURL.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.unsynchronizedLyrics?.contains("Plain text lyrics") == true)
    }

    // MARK: - Write Lyrics File (sync .lrc)

    @Test("Write --lyrics-file with .lrc adds synchronized lyrics")
    func writeLyricsFileLrc() throws {
        let url = try CLITestHelper.createMP3(title: "LRC File Test")
        defer { try? FileManager.default.removeItem(at: url) }

        let lrcURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".lrc")
        defer { try? FileManager.default.removeItem(at: lrcURL) }
        let lrcContent = "[00:00.00]First line\n[00:05.50]Second line"
        try lrcContent.write(to: lrcURL, atomically: true, encoding: .utf8)

        var cmd = try Write.parse([url.path, "--lyrics-file", lrcURL.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(!info.metadata.synchronizedLyrics.isEmpty)
        #expect(info.metadata.synchronizedLyrics[0].lines.count == 2)
    }

    // MARK: - Clear Lyrics

    @Test("Write --clear-lyrics removes existing lyrics")
    func clearLyrics() throws {
        let url = try CLITestHelper.createMP3WithUnsyncLyrics(lyrics: "Old lyrics")
        defer { try? FileManager.default.removeItem(at: url) }

        let infoBefore = try AudioMarkerEngine().read(from: url)
        #expect(infoBefore.metadata.unsynchronizedLyrics != nil)

        var cmd = try Write.parse([url.path, "--clear-lyrics"])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.unsynchronizedLyrics == nil)
        #expect(info.metadata.synchronizedLyrics.isEmpty)
    }

    // MARK: - Read Displays Lyrics

    @Test("Read command displays unsynchronized lyrics in text format")
    func readShowsUnsyncLyrics() throws {
        let url = try CLITestHelper.createMP3WithUnsyncLyrics(lyrics: "Some lyrics text")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.unsynchronizedLyrics == "Some lyrics text")
    }

    @Test("Read command displays synchronized lyrics in text format")
    func readShowsSyncLyrics() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0),
            (text: "World", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(!info.metadata.synchronizedLyrics.isEmpty)
        #expect(info.metadata.synchronizedLyrics[0].lines.count == 2)
    }

    // MARK: - JSON Output with Lyrics

    @Test("Read JSON includes unsynchronized lyrics")
    func readJSONShowsUnsyncLyrics() throws {
        let url = try CLITestHelper.createMP3WithUnsyncLyrics(lyrics: "JSON lyrics test")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path, "--format", "json"])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.unsynchronizedLyrics == "JSON lyrics test")
    }

    @Test("Read JSON includes synchronized lyrics")
    func readJSONShowsSyncLyrics() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Line 1", timestamp: 0),
            (text: "Line 2", timestamp: 3000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path, "--format", "json"])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(!info.metadata.synchronizedLyrics.isEmpty)
    }

    // MARK: - Read with Extended Metadata

    @Test("Read text displays all metadata fields")
    func readTextAllFields() throws {
        let url = try CLITestHelper.createMP3(title: "Full")
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = AudioMarkerEngine()
        var info = try engine.read(from: url)
        info.metadata.year = 2025
        info.metadata.trackNumber = 3
        info.metadata.discNumber = 1
        info.metadata.genre = "Rock"
        info.metadata.composer = "Bach"
        info.metadata.albumArtist = "VA"
        info.metadata.comment = "Nice"
        info.metadata.bpm = 120
        try engine.modify(info, in: url)

        var cmd = try Read.parse([url.path])
        try cmd.run()
    }

    @Test("Read JSON includes extended metadata fields")
    func readJSONAllFields() throws {
        let url = try CLITestHelper.createMP3(title: "Full JSON")
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = AudioMarkerEngine()
        var info = try engine.read(from: url)
        info.metadata.artist = "Artist"
        info.metadata.album = "Album"
        info.metadata.year = 2025
        info.metadata.trackNumber = 5
        info.metadata.genre = "Pop"
        try engine.modify(info, in: url)

        var cmd = try Read.parse([url.path, "--format", "json"])
        try cmd.run()
    }

    // MARK: - Lyrics Truncation

    @Test("Read text truncates long unsynchronized lyrics")
    func readTruncatesLongLyrics() throws {
        let longLyrics = (1...20).map { "Line \($0) of lyrics" }.joined(separator: "\n")
        let url = try CLITestHelper.createMP3WithUnsyncLyrics(lyrics: longLyrics)
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path])
        try cmd.run()
    }

    @Test("Read text truncates many synchronized lyrics lines")
    func readTruncatesSyncLyrics() throws {
        let events: [(text: String, timestamp: UInt32)] = (0..<25).map {
            (text: "Sync line \($0)", timestamp: UInt32($0 * 2000))
        }
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: events)
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.synchronizedLyrics[0].lines.count == 25)
    }
}
