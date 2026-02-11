import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCommands

/// Demonstrates CLI chapter management: list, add, remove, clear, export, import.
@Suite("Showcase: CLI Chapters")
struct CLIChaptersShowcaseTests {

    let engine = AudioMarkerEngine()

    // MARK: - List

    @Test("audiomarker chapters list — display chapters")
    func chaptersList() throws {
        let url = try CLITestHelper.createMP3WithChapters()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.List.parse([url.path])
        try cmd.run()

        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 2)
    }

    @Test("audiomarker chapters list — shows URL and artwork")
    func chaptersListShowsURLAndArtwork() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0x00), count: 32))
        let frames: [Data] = [
            ID3TestHelper.buildTextFrame(id: "TIT2", text: "URL Art Test"),
            ID3TestHelper.buildCHAPFrame(
                elementID: "ch1", startTime: 0, endTime: 60_000,
                subframes: [
                    ID3TestHelper.buildTextFrame(id: "TIT2", text: "Intro"),
                    ID3TestHelper.buildURLFrame(id: "WOAR", url: "https://example.com/ch1"),
                    ID3TestHelper.buildAPICFrame(imageData: imageData)
                ])
        ]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.List.parse([url.path])
        try cmd.run()

        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 1)
        #expect(chapters[0].url?.absoluteString == "https://example.com/ch1")
        #expect(chapters[0].artwork != nil)
        #expect(chapters[0].artwork?.format == .jpeg)
    }

    // MARK: - Add

    @Test("audiomarker chapters add — add a chapter")
    func chaptersAdd() throws {
        let url = try CLITestHelper.createMP3(title: "Empty")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.Add.parse([
            url.path, "--start", "00:01:30", "--title", "Verse 1"
        ])
        try cmd.run()

        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Verse 1")
    }

    @Test("audiomarker chapters add — multiple chapters auto-sorted")
    func chaptersAddMultiple() throws {
        let url = try CLITestHelper.createMP3(title: "Multi")
        defer { try? FileManager.default.removeItem(at: url) }

        // Add 3 chapters in reverse order
        var cmd3 = try Chapters.Add.parse([
            url.path, "--start", "00:05:00", "--title", "Third"
        ])
        try cmd3.run()

        var cmd1 = try Chapters.Add.parse([
            url.path, "--start", "00:00:00", "--title", "First"
        ])
        try cmd1.run()

        var cmd2 = try Chapters.Add.parse([
            url.path, "--start", "00:02:30", "--title", "Second"
        ])
        try cmd2.run()

        // Should be sorted by start time
        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "First")
        #expect(chapters[1].title == "Second")
        #expect(chapters[2].title == "Third")
    }

    // MARK: - Remove

    @Test("audiomarker chapters remove --index — remove by position")
    func chaptersRemoveByIndex() throws {
        let url = try createMP3With3Chapters()
        defer { try? FileManager.default.removeItem(at: url) }

        // Remove index 3 (the third chapter: "Chorus", 1-indexed)
        var cmd = try Chapters.Remove.parse([url.path, "--index", "3"])
        try cmd.run()

        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 2)
        // Verify the correct one was removed
        let titles = chapters.map(\.title)
        #expect(!titles.contains("Chorus"))
    }

    @Test("audiomarker chapters remove --title — remove by name")
    func chaptersRemoveByTitle() throws {
        let url = try createMP3With3Chapters()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.Remove.parse([url.path, "--title", "Bridge"])
        try cmd.run()

        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 2)
        let titles = chapters.map(\.title)
        #expect(!titles.contains("Bridge"))
    }

    // MARK: - Clear

    @Test("audiomarker chapters clear — remove all chapters")
    func chaptersClear() throws {
        let url = try CLITestHelper.createMP3WithChapters()
        defer { try? FileManager.default.removeItem(at: url) }

        // Verify chapters exist
        let before = try engine.readChapters(from: url)
        #expect(!before.isEmpty)

        var cmd = try Chapters.Clear.parse([url.path, "--force"])
        try cmd.run()

        let after = try engine.readChapters(from: url)
        #expect(after.isEmpty)
    }

    // MARK: - Export

    @Test("audiomarker chapters export — all formats")
    func chaptersExport() throws {
        let url = try createMP3With3Chapters()
        defer { try? FileManager.default.removeItem(at: url) }

        // Export to Podlove JSON (to file)
        let jsonOutput = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: jsonOutput) }

        var jsonCmd = try Chapters.Export.parse([
            url.path, "--to", jsonOutput.path, "--format", "podlove-json"
        ])
        try jsonCmd.run()

        let jsonContent = try String(contentsOf: jsonOutput, encoding: .utf8)
        #expect(jsonContent.contains("Intro"))
        #expect(jsonContent.contains("Bridge"))

        // Export to mp4chaps (to stdout)
        var mp4Cmd = try Chapters.Export.parse([url.path, "--format", "mp4chaps"])
        try mp4Cmd.run()
    }

    // MARK: - Import

    @Test("audiomarker chapters import — import from file")
    func chaptersImport() throws {
        let url = try CLITestHelper.createMP3(title: "Import Target")
        defer { try? FileManager.default.removeItem(at: url) }

        // Create a Podlove JSON file
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: jsonURL) }
        let json = """
            {
              "version": "1.2",
              "chapters": [
                { "start": "00:00:00.000", "title": "Opening" },
                { "start": "00:01:30.000", "title": "Main Content" },
                { "start": "00:10:00.000", "title": "Wrap Up" }
              ]
            }
            """
        try json.write(to: jsonURL, atomically: true, encoding: .utf8)

        var cmd = try Chapters.Import.parse([
            url.path, "--from", jsonURL.path, "--format", "podlove-json"
        ])
        try cmd.run()

        // Verify chapters were imported
        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Opening")
        #expect(chapters[1].title == "Main Content")
        #expect(chapters[2].title == "Wrap Up")
    }

    // MARK: - Helpers

    private func createMP3With3Chapters() throws -> URL {
        let frames: [Data] = [
            ID3TestHelper.buildTextFrame(id: "TIT2", text: "3 Chapters"),
            ID3TestHelper.buildCHAPFrame(
                elementID: "ch1", startTime: 0, endTime: 60_000,
                subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Intro")]),
            ID3TestHelper.buildCHAPFrame(
                elementID: "ch2", startTime: 60_000, endTime: 120_000,
                subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Bridge")]),
            ID3TestHelper.buildCHAPFrame(
                elementID: "ch3", startTime: 120_000, endTime: 180_000,
                subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chorus")])
        ]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        return try ID3TestHelper.createTempFile(tagData: tag)
    }
}
