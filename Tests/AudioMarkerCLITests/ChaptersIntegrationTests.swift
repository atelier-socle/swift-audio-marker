import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCommands

@Suite("CLI Chapters Integration")
struct ChaptersIntegrationTests {

    // MARK: - Chapters List

    @Test("Chapters list command displays chapters")
    func chaptersListCommand() throws {
        let url = try CLITestHelper.createMP3WithChapters()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.List.parse([url.path])
        try cmd.run()

        let chapters = try AudioMarkerEngine().readChapters(from: url)
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "Intro")
        #expect(chapters[1].title == "Verse")
    }

    @Test("Chapters list command on file without chapters")
    func chaptersListEmpty() throws {
        let url = try CLITestHelper.createMP3(title: "No Chapters")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.List.parse([url.path])
        try cmd.run()

        let chapters = try AudioMarkerEngine().readChapters(from: url)
        #expect(chapters.isEmpty)
    }

    // MARK: - Chapters Add

    @Test("Chapters add command adds a chapter")
    func chaptersAddCommand() throws {
        let url = try CLITestHelper.createMP3(title: "With Chapters")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.Add.parse([
            url.path, "--start", "00:01:00", "--title", "First Chapter"
        ])
        try cmd.run()

        let chapters = try AudioMarkerEngine().readChapters(from: url)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "First Chapter")
    }

    @Test("Chapters add command with URL")
    func chaptersAddWithURL() throws {
        let url = try CLITestHelper.createMP3(title: "With URL Chapter")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.Add.parse([
            url.path, "--start", "00:00:00", "--title", "Link Chapter",
            "--url", "https://example.com"
        ])
        try cmd.run()

        let chapters = try AudioMarkerEngine().readChapters(from: url)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Link Chapter")
    }

    @Test("Chapters add on file without existing metadata")
    func chaptersAddToBareMp3() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0xFF, count: 256).write(to: url)

        var cmd = try Chapters.Add.parse([
            url.path, "--start", "00:00:00", "--title", "First"
        ])
        try cmd.run()

        let chapters = try AudioMarkerEngine().readChapters(from: url)
        #expect(chapters.count == 1)
    }

    // MARK: - Chapters Remove

    @Test("Chapters remove by index")
    func chaptersRemoveByIndex() throws {
        let url = try CLITestHelper.createMP3WithChapters()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.Remove.parse([url.path, "--index", "1"])
        try cmd.run()

        let chapters = try AudioMarkerEngine().readChapters(from: url)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Verse")
    }

    @Test("Chapters remove by title")
    func chaptersRemoveByTitle() throws {
        let url = try CLITestHelper.createMP3WithChapters()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.Remove.parse([url.path, "--title", "Verse"])
        try cmd.run()

        let chapters = try AudioMarkerEngine().readChapters(from: url)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Intro")
    }

    @Test("Chapters remove with out-of-range index throws")
    func chaptersRemoveOutOfRange() throws {
        let url = try CLITestHelper.createMP3WithChapters()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.Remove.parse([url.path, "--index", "99"])
        #expect(throws: Error.self) {
            try cmd.run()
        }
    }

    @Test("Chapters remove with unknown title throws")
    func chaptersRemoveUnknownTitle() throws {
        let url = try CLITestHelper.createMP3WithChapters()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.Remove.parse([url.path, "--title", "Nonexistent"])
        #expect(throws: Error.self) {
            try cmd.run()
        }
    }

    @Test("Chapters remove validation requires index or title")
    func chaptersRemoveValidation() {
        #expect(throws: Error.self) {
            try Chapters.Remove.parse(["song.mp3"])
        }
    }

    // MARK: - Chapters Clear

    @Test("Chapters clear command removes all chapters")
    func chaptersClearCommand() throws {
        let chapFrame = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 0, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chapter 1")])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [chapFrame])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.Clear.parse([url.path])
        try cmd.run()

        let chapters = try AudioMarkerEngine().readChapters(from: url)
        #expect(chapters.isEmpty)
    }

    @Test("Chapters clear on file without existing metadata")
    func chaptersClearBareMp3() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0xFF, count: 256).write(to: url)

        var cmd = try Chapters.Clear.parse([url.path])
        try cmd.run()
    }

    // MARK: - Chapters Export

    @Test("Chapters export command produces valid output")
    func chaptersExportCommand() throws {
        let chapFrame = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 0, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Intro")])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [chapFrame])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var cmd = try Chapters.Export.parse([
            url.path, "--to", outputURL.path, "--format", "podlove-json"
        ])
        try cmd.run()

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(content.contains("Intro"))
    }

    @Test("Chapters export to stdout")
    func chaptersExportToStdout() throws {
        let chapFrame = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 0, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Stdout")])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [chapFrame])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Chapters.Export.parse([url.path, "--format", "mp4chaps"])
        try cmd.run()
    }

    // MARK: - Chapters Import

    @Test("Chapters import command injects chapters")
    func chaptersImportCommand() throws {
        let url = try CLITestHelper.createMP3(title: "Import Target")
        defer { try? FileManager.default.removeItem(at: url) }

        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let json = """
            {
              "version": "1.2",
              "chapters": [
                { "start": "00:00:00.000", "title": "Imported" }
              ]
            }
            """
        try json.write(to: jsonURL, atomically: true, encoding: .utf8)

        var cmd = try Chapters.Import.parse([
            url.path, "--from", jsonURL.path, "--format", "podlove-json"
        ])
        try cmd.run()

        let chapters = try AudioMarkerEngine().readChapters(from: url)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Imported")
    }
}
