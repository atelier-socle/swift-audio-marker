import Foundation
import Testing

@testable import AudioMarker

@Suite("Chapter Exporter")
struct ChapterExporterTests {

    let exporter = ChapterExporter()

    let sampleChapters = ChapterList([
        Chapter(start: .zero, title: "Introduction"),
        Chapter(start: .seconds(60), title: "Main Topic"),
        Chapter(start: .seconds(300), title: "Conclusion")
    ])

    // MARK: - Export

    @Test("Exports to Podlove JSON")
    func exportPodloveJSON() throws {
        let result = try exporter.export(sampleChapters, format: .podloveJSON)
        #expect(result.contains("\"version\" : \"1.2\""))
        #expect(result.contains("Introduction"))
    }

    @Test("Exports to Podlove XML")
    func exportPodloveXML() throws {
        let result = try exporter.export(sampleChapters, format: .podloveXML)
        #expect(result.contains("<psc:chapters"))
        #expect(result.contains("Introduction"))
    }

    @Test("Exports to MP4Chaps")
    func exportMP4Chaps() throws {
        let result = try exporter.export(sampleChapters, format: .mp4chaps)
        #expect(result.contains("00:00:00.000 Introduction"))
    }

    @Test("Exports to FFMetadata")
    func exportFFMetadata() throws {
        let result = try exporter.export(sampleChapters, format: .ffmetadata)
        #expect(result.hasPrefix(";FFMETADATA1"))
        #expect(result.contains("title=Introduction"))
    }

    @Test("Exports to Markdown")
    func exportMarkdown() throws {
        let result = try exporter.export(sampleChapters, format: .markdown)
        #expect(result.contains("1. **00:00:00**"))
    }

    // MARK: - Import

    @Test("Imports from Podlove JSON")
    func importPodloveJSON() throws {
        let json = try exporter.export(sampleChapters, format: .podloveJSON)
        let imported = try exporter.importChapters(from: json, format: .podloveJSON)
        #expect(imported.count == 3)
        #expect(imported[0].title == "Introduction")
    }

    @Test("Imports from Podlove XML")
    func importPodloveXML() throws {
        let xml = try exporter.export(sampleChapters, format: .podloveXML)
        let imported = try exporter.importChapters(from: xml, format: .podloveXML)
        #expect(imported.count == 3)
        #expect(imported[0].title == "Introduction")
    }

    @Test("Imports from MP4Chaps")
    func importMP4Chaps() throws {
        let text = try exporter.export(sampleChapters, format: .mp4chaps)
        let imported = try exporter.importChapters(from: text, format: .mp4chaps)
        #expect(imported.count == 3)
        #expect(imported[0].title == "Introduction")
    }

    @Test("Imports from FFMetadata")
    func importFFMetadata() throws {
        let text = try exporter.export(sampleChapters, format: .ffmetadata)
        let imported = try exporter.importChapters(from: text, format: .ffmetadata)
        #expect(imported.count == 3)
        #expect(imported[0].title == "Introduction")
    }

    @Test("Markdown import throws importNotSupported")
    func markdownImportThrows() {
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: "anything", format: .markdown)
        }
    }

    // MARK: - Round-Trip

    @Test(
        "Round-trip preserves chapters for importable formats",
        arguments: [ExportFormat.podloveJSON, .podloveXML, .mp4chaps]
    )
    func roundTrip(format: ExportFormat) throws {
        let exported = try exporter.export(sampleChapters, format: format)
        let imported = try exporter.importChapters(from: exported, format: format)
        #expect(imported.count == sampleChapters.count)
        for (orig, imp) in zip(sampleChapters, imported) {
            #expect(orig.title == imp.title)
            #expect(orig.start.description == imp.start.description)
        }
    }
}
