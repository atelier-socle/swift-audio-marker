import Foundation
import Testing

@testable import AudioMarker

/// Demonstrates chapter export and import across all supported formats.
@Suite("Showcase: Chapter Export/Import")
struct ExporterShowcaseTests {

    let exporter = ChapterExporter()

    let sampleChapters = ChapterList([
        Chapter(
            start: .zero, title: "Introduction",
            url: URL(string: "https://example.com/intro")),
        Chapter(start: .seconds(60), title: "Main Discussion"),
        Chapter(start: .seconds(300), title: "Q&A Session")
    ])

    // MARK: - Podlove JSON

    @Test("Export chapters to Podlove Simple Chapters JSON")
    func exportPodloveJSON() throws {
        let json = try exporter.export(sampleChapters, format: .podloveJSON)

        // Contains chapter data
        #expect(json.contains("Introduction"))
        #expect(json.contains("Main Discussion"))
        #expect(json.contains("Q&A Session"))
        #expect(json.contains("\"version\""))

        // Round-trip: import the exported JSON
        let imported = try exporter.importChapters(from: json, format: .podloveJSON)
        #expect(imported.count == 3)
        #expect(imported[0].title == "Introduction")
        #expect(imported[2].title == "Q&A Session")
    }

    // MARK: - Podlove XML

    @Test("Export chapters to Podlove Simple Chapters XML")
    func exportPodloveXML() throws {
        let xml = try exporter.export(sampleChapters, format: .podloveXML)

        // Valid XML structure
        #expect(xml.contains("<psc:chapters"))
        #expect(xml.contains("psc:chapter"))
        #expect(xml.contains("Introduction"))

        // Round-trip
        let imported = try exporter.importChapters(from: xml, format: .podloveXML)
        #expect(imported.count == 3)
        #expect(imported[0].title == "Introduction")
    }

    // MARK: - MP4Chaps

    @Test("Export chapters to MP4chaps format")
    func exportMP4Chaps() throws {
        let text = try exporter.export(sampleChapters, format: .mp4chaps)

        // "HH:MM:SS.mmm Title" per line
        #expect(text.contains("00:00:00.000 Introduction"))
        #expect(text.contains("00:01:00.000 Main Discussion"))

        // Round-trip
        let imported = try exporter.importChapters(from: text, format: .mp4chaps)
        #expect(imported.count == 3)
        #expect(imported[0].title == "Introduction")
    }

    // MARK: - FFMetadata

    @Test("Export chapters to FFmetadata format")
    func exportFFMetadata() throws {
        let text = try exporter.export(sampleChapters, format: .ffmetadata)

        // Starts with FFmetadata header
        #expect(text.hasPrefix(";FFMETADATA1"))
        // Contains chapter sections
        #expect(text.contains("[CHAPTER]"))
        #expect(text.contains("title=Introduction"))

        // Round-trip
        let imported = try exporter.importChapters(from: text, format: .ffmetadata)
        #expect(imported.count == 3)
    }

    // MARK: - Markdown

    @Test("Export chapters to Markdown")
    func exportMarkdown() throws {
        let md = try exporter.export(sampleChapters, format: .markdown)

        // Markdown list format
        #expect(md.contains("Introduction"))
        #expect(md.contains("00:00:00"))

        // Markdown is export-only — import throws
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: md, format: .markdown)
        }
    }

    // MARK: - Import into Audio File

    @Test("Import chapters from all formats into audio file")
    func importIntoFile() throws {
        let engine = AudioMarkerEngine()

        // Create a bare MP3
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Export to Podlove JSON, then import into the file
        let json = try exporter.export(sampleChapters, format: .podloveJSON)
        try engine.importChapters(from: json, format: .podloveJSON, to: url)

        // Verify chapters are in the file
        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Introduction")

        // Also verify with a second format (MP4Chaps)
        let mp4chaps = try exporter.export(sampleChapters, format: .mp4chaps)
        let reimported = try exporter.importChapters(from: mp4chaps, format: .mp4chaps)
        #expect(reimported.count == 3)
    }
}
