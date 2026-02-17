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


import Testing

@testable import AudioMarker

@Suite("Export Format")
struct ExportFormatTests {

    @Test("Has eleven cases")
    func caseCount() {
        #expect(ExportFormat.allCases.count == 11)
    }

    @Test("Podlove JSON has json extension")
    func podloveJSONExtension() {
        #expect(ExportFormat.podloveJSON.fileExtension == "json")
    }

    @Test("Podlove XML has xml extension")
    func podloveXMLExtension() {
        #expect(ExportFormat.podloveXML.fileExtension == "xml")
    }

    @Test("MP4Chaps has txt extension")
    func mp4chapsExtension() {
        #expect(ExportFormat.mp4chaps.fileExtension == "txt")
    }

    @Test("FFMetadata has ini extension")
    func ffmetadataExtension() {
        #expect(ExportFormat.ffmetadata.fileExtension == "ini")
    }

    @Test("Markdown has md extension")
    func markdownExtension() {
        #expect(ExportFormat.markdown.fileExtension == "md")
    }

    @Test("LRC has lrc extension")
    func lrcExtension() {
        #expect(ExportFormat.lrc.fileExtension == "lrc")
    }

    @Test("TTML has ttml extension")
    func ttmlExtension() {
        #expect(ExportFormat.ttml.fileExtension == "ttml")
    }

    @Test("Podcast namespace has json extension")
    func podcastNamespaceExtension() {
        #expect(ExportFormat.podcastNamespace.fileExtension == "json")
    }

    @Test("WebVTT has vtt extension")
    func webvttExtension() {
        #expect(ExportFormat.webvtt.fileExtension == "vtt")
    }

    @Test("SRT has srt extension")
    func srtExtension() {
        #expect(ExportFormat.srt.fileExtension == "srt")
    }

    @Test("Cue Sheet has cue extension")
    func cueSheetExtension() {
        #expect(ExportFormat.cueSheet.fileExtension == "cue")
    }

    @Test("Import-capable formats support import")
    func supportsImport() {
        #expect(ExportFormat.podloveJSON.supportsImport)
        #expect(ExportFormat.podloveXML.supportsImport)
        #expect(ExportFormat.mp4chaps.supportsImport)
        #expect(ExportFormat.ffmetadata.supportsImport)
        #expect(ExportFormat.lrc.supportsImport)
        #expect(ExportFormat.podcastNamespace.supportsImport)
        #expect(!ExportFormat.markdown.supportsImport)
        #expect(ExportFormat.ttml.supportsImport)
        #expect(ExportFormat.webvtt.supportsImport)
        #expect(ExportFormat.srt.supportsImport)
        #expect(ExportFormat.cueSheet.supportsImport)
    }

    // MARK: - ExportError Descriptions

    @Test("importNotSupported has description")
    func importNotSupportedDescription() {
        let error = ExportError.importNotSupported("markdown")
        #expect(error.errorDescription?.contains("markdown") == true)
    }

    @Test("invalidData has description")
    func invalidDataDescription() {
        let error = ExportError.invalidData("bad bytes")
        #expect(error.errorDescription?.contains("bad bytes") == true)
    }

    @Test("invalidFormat has description")
    func invalidFormatDescription() {
        let error = ExportError.invalidFormat("missing field")
        #expect(error.errorDescription?.contains("missing field") == true)
    }

    @Test("ioError has description")
    func ioErrorDescription() {
        let error = ExportError.ioError("disk full")
        #expect(error.errorDescription?.contains("disk full") == true)
    }

    @Test("unsupportedFormat has description")
    func unsupportedFormatDescription() {
        let error = ExportError.unsupportedFormat("LRC is a lyrics format")
        #expect(error.errorDescription?.contains("LRC is a lyrics format") == true)
    }
}
