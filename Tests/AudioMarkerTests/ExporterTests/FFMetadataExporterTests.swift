import Foundation
import Testing

@testable import AudioMarker

@Suite("FFMetadata Exporter")
struct FFMetadataExporterTests {

    let exporter = FFMetadataExporter()

    // MARK: - Export

    @Test("Exports chapters with end times")
    func exportWithEndTimes() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Introduction", end: .seconds(60)),
            Chapter(start: .seconds(60), title: "Main Topic", end: .seconds(300))
        ])
        let text = exporter.export(chapters)
        #expect(text.hasPrefix(";FFMETADATA1\n"))
        #expect(text.contains("[CHAPTER]"))
        #expect(text.contains("TIMEBASE=1/1000"))
        #expect(text.contains("START=0"))
        #expect(text.contains("END=60000"))
        #expect(text.contains("START=60000"))
        #expect(text.contains("END=300000"))
        #expect(text.contains("title=Introduction"))
        #expect(text.contains("title=Main Topic"))
    }

    @Test("Exports chapters without end times")
    func exportWithoutEndTimes() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Intro")
        ])
        let text = exporter.export(chapters)
        #expect(text.contains("START=0"))
        #expect(!text.contains("END="))
        #expect(text.contains("title=Intro"))
    }

    @Test("Escapes special characters in title")
    func exportEscaping() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Key=Value; #comment")
        ])
        let text = exporter.export(chapters)
        #expect(text.contains("title=Key\\=Value\\; \\#comment"))
    }

    // MARK: - Import

    @Test("Imports basic chapters")
    func importBasic() throws {
        let text = """
            ;FFMETADATA1

            [CHAPTER]
            TIMEBASE=1/1000
            START=0
            END=60000
            title=Introduction

            [CHAPTER]
            TIMEBASE=1/1000
            START=60000
            END=300000
            title=Main Topic
            """
        let chapters = try exporter.importChapters(from: text)
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "Introduction")
        #expect(chapters[0].start.timeInterval == 0)
        #expect(chapters[0].end?.timeInterval == 60)
        #expect(chapters[1].title == "Main Topic")
        #expect(chapters[1].start.timeInterval == 60)
        #expect(chapters[1].end?.timeInterval == 300)
    }

    @Test("Imports with microsecond timebase")
    func importMicrosecondTimebase() throws {
        let text = """
            ;FFMETADATA1

            [CHAPTER]
            TIMEBASE=1/1000000
            START=0
            END=60000000
            title=First
            """
        let chapters = try exporter.importChapters(from: text)
        #expect(chapters.count == 1)
        #expect(chapters[0].start.timeInterval == 0)
        #expect(chapters[0].end?.timeInterval == 60)
    }

    @Test("Imports escaped special characters")
    func importEscaping() throws {
        let text = """
            ;FFMETADATA1

            [CHAPTER]
            TIMEBASE=1/1000
            START=0
            title=Key\\=Value\\; \\#comment
            """
        let chapters = try exporter.importChapters(from: text)
        #expect(chapters[0].title == "Key=Value; #comment")
    }

    @Test("Import rejects missing START")
    func importMissingStart() {
        let text = """
            ;FFMETADATA1

            [CHAPTER]
            TIMEBASE=1/1000
            title=No Start
            """
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: text)
        }
    }

    @Test("Imports chapter without end time")
    func importWithoutEndTime() throws {
        let text = """
            ;FFMETADATA1

            [CHAPTER]
            TIMEBASE=1/1000
            START=0
            title=Open Ended
            """
        let chapters = try exporter.importChapters(from: text)
        #expect(chapters.count == 1)
        #expect(chapters[0].end == nil)
    }

    @Test("Imports chapter without title")
    func importWithoutTitle() throws {
        let text = """
            ;FFMETADATA1

            [CHAPTER]
            TIMEBASE=1/1000
            START=0
            """
        let chapters = try exporter.importChapters(from: text)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "")
    }

    // MARK: - Round-Trip

    @Test("Round-trip preserves chapters with end times")
    func roundTrip() throws {
        let original = ChapterList([
            Chapter(start: .zero, title: "Intro", end: .seconds(60)),
            Chapter(start: .seconds(60), title: "Chapter 2", end: .seconds(180)),
            Chapter(start: .seconds(180), title: "End", end: .seconds(300))
        ])
        let text = exporter.export(original)
        let imported = try exporter.importChapters(from: text)
        #expect(imported.count == original.count)
        for (orig, imp) in zip(original, imported) {
            #expect(orig.title == imp.title)
            #expect(orig.start.description == imp.start.description)
            #expect(orig.end?.description == imp.end?.description)
        }
    }
}
