import Foundation
import Testing

@testable import AudioMarker

@Suite("Podlove JSON Exporter")
struct PodloveJSONExporterTests {

    let exporter = PodloveJSONExporter()

    // MARK: - Export

    @Test("Exports basic chapters")
    func exportBasic() throws {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Introduction"),
            Chapter(start: .seconds(60), title: "Main Topic")
        ])
        let json = try exporter.export(chapters)
        #expect(json.contains("\"version\" : \"1.2\""))
        #expect(json.contains("\"start\" : \"00:00:00.000\""))
        #expect(json.contains("\"title\" : \"Introduction\""))
        #expect(json.contains("\"start\" : \"00:01:00.000\""))
        #expect(json.contains("\"title\" : \"Main Topic\""))
    }

    @Test("Exports chapters with URLs")
    func exportWithURL() throws {
        let link = try #require(URL(string: "https://example.com"))
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Linked", url: link)
        ])
        let json = try exporter.export(chapters)
        #expect(json.contains("\"href\" : \"https://example.com\""))
    }

    @Test("Exports empty chapter list")
    func exportEmpty() throws {
        let json = try exporter.export(ChapterList())
        #expect(json.contains("\"chapters\" : ["))
        #expect(json.contains("\"version\" : \"1.2\""))
    }

    // MARK: - Import

    @Test("Imports basic JSON")
    func importBasic() throws {
        let json = """
            {
              "version": "1.2",
              "chapters": [
                { "start": "00:00:00.000", "title": "First" },
                { "start": "00:05:30.000", "title": "Second" }
              ]
            }
            """
        let chapters = try exporter.importChapters(from: json)
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "First")
        #expect(chapters[0].start.timeInterval == 0)
        #expect(chapters[1].title == "Second")
        #expect(chapters[1].start.timeInterval == 330)
    }

    @Test("Imports chapters with href")
    func importWithHref() throws {
        let json = """
            {
              "version": "1.2",
              "chapters": [
                { "start": "00:00:00.000", "title": "Link", "href": "https://example.com" }
              ]
            }
            """
        let chapters = try exporter.importChapters(from: json)
        #expect(chapters[0].url?.absoluteString == "https://example.com")
    }

    @Test("Import rejects missing start")
    func importMissingStart() {
        let json = """
            { "chapters": [{ "title": "No Start" }] }
            """
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: json)
        }
    }

    @Test("Import rejects missing title")
    func importMissingTitle() {
        let json = """
            { "chapters": [{ "start": "00:00:00.000" }] }
            """
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: json)
        }
    }

    @Test("Import rejects invalid JSON")
    func importInvalidJSON() {
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: "not json")
        }
    }

    @Test("Import rejects non-object root")
    func importNonObject() {
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: "[1, 2, 3]")
        }
    }

    @Test("Import rejects missing chapters array")
    func importMissingChapters() {
        let json = """
            { "version": "1.2" }
            """
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: json)
        }
    }

    // MARK: - Round-Trip

    @Test("Round-trip preserves chapters")
    func roundTrip() throws {
        let link = try #require(URL(string: "https://example.com/ch2"))
        let original = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .milliseconds(90_500), title: "Chapter 2", url: link),
            Chapter(start: .seconds(300), title: "End")
        ])
        let json = try exporter.export(original)
        let imported = try exporter.importChapters(from: json)
        #expect(imported.count == original.count)
        for (orig, imp) in zip(original, imported) {
            #expect(orig.title == imp.title)
            #expect(orig.start.description == imp.start.description)
            #expect(orig.url == imp.url)
        }
    }
}
