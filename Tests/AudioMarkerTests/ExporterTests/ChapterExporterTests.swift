// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


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

    @Test("Exports to Podcast Namespace JSON")
    func exportPodcastNamespace() throws {
        let result = try exporter.export(sampleChapters, format: .podcastNamespace)
        #expect(result.contains("\"version\" : \"1.2.0\""))
        #expect(result.contains("Introduction"))
        #expect(result.contains("startTime"))
    }

    @Test("Imports from Podcast Namespace JSON")
    func importPodcastNamespace() throws {
        let json = try exporter.export(sampleChapters, format: .podcastNamespace)
        let imported = try exporter.importChapters(from: json, format: .podcastNamespace)
        #expect(imported.count == 3)
        #expect(imported[0].title == "Introduction")
    }

    @Test("Exports to Cue Sheet")
    func exportCueSheet() throws {
        let result = try exporter.export(sampleChapters, format: .cueSheet)
        #expect(result.contains("TRACK 01 AUDIO"))
        #expect(result.contains("Introduction"))
    }

    @Test("Imports from Cue Sheet")
    func importCueSheet() throws {
        let cue = try exporter.export(sampleChapters, format: .cueSheet)
        let imported = try exporter.importChapters(from: cue, format: .cueSheet)
        #expect(imported.count == 3)
        #expect(imported[0].title == "Introduction")
    }

    @Test("Markdown import throws importNotSupported")
    func markdownImportThrows() {
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: "anything", format: .markdown)
        }
    }

    // MARK: - Unsupported Lyrics Formats

    @Test("LRC export throws unsupportedFormat")
    func lrcExportThrows() {
        #expect(throws: ExportError.self) {
            try exporter.export(sampleChapters, format: .lrc)
        }
    }

    @Test("LRC import throws unsupportedFormat")
    func lrcImportThrows() {
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: "anything", format: .lrc)
        }
    }

    @Test("TTML export throws unsupportedFormat")
    func ttmlExportThrows() {
        #expect(throws: ExportError.self) {
            try exporter.export(sampleChapters, format: .ttml)
        }
    }

    @Test("TTML import throws unsupportedFormat")
    func ttmlImportThrows() {
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: "anything", format: .ttml)
        }
    }

    @Test("WebVTT export throws unsupportedFormat")
    func webvttExportThrows() {
        #expect(throws: ExportError.self) {
            try exporter.export(sampleChapters, format: .webvtt)
        }
    }

    @Test("WebVTT import throws unsupportedFormat")
    func webvttImportThrows() {
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: "anything", format: .webvtt)
        }
    }

    @Test("SRT export throws unsupportedFormat")
    func srtExportThrows() {
        #expect(throws: ExportError.self) {
            try exporter.export(sampleChapters, format: .srt)
        }
    }

    @Test("SRT import throws unsupportedFormat")
    func srtImportThrows() {
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: "anything", format: .srt)
        }
    }

    // MARK: - Round-Trip

    @Test(
        "Round-trip preserves chapters for importable formats",
        arguments: [ExportFormat.podloveJSON, .podloveXML, .mp4chaps, .podcastNamespace]
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

    @Test("Cue Sheet round-trip preserves titles and approximate timestamps")
    func cueSheetRoundTrip() throws {
        let exported = try exporter.export(sampleChapters, format: .cueSheet)
        let imported = try exporter.importChapters(from: exported, format: .cueSheet)
        #expect(imported.count == sampleChapters.count)
        for (orig, imp) in zip(sampleChapters, imported) {
            #expect(orig.title == imp.title)
            // Cue Sheet uses CD frames (1/75s precision), so allow small differences.
            #expect(abs(orig.start.timeInterval - imp.start.timeInterval) < 0.02)
        }
    }
}
