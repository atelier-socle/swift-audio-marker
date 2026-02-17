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

@Suite("Podlove XML Exporter")
struct PodloveXMLExporterTests {

    let exporter = PodloveXMLExporter()

    // MARK: - Export

    @Test("Exports basic chapters")
    func exportBasic() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Introduction"),
            Chapter(start: .seconds(60), title: "Main Topic")
        ])
        let xml = exporter.export(chapters)
        #expect(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(xml.contains("xmlns:psc=\"http://podlove.org/simple-chapters\""))
        #expect(xml.contains("start=\"00:00:00.000\""))
        #expect(xml.contains("title=\"Introduction\""))
        #expect(xml.contains("start=\"00:01:00.000\""))
        #expect(xml.contains("title=\"Main Topic\""))
    }

    @Test("Exports chapters with URL")
    func exportWithURL() throws {
        let link = try #require(URL(string: "https://example.com"))
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Linked", url: link)
        ])
        let xml = exporter.export(chapters)
        #expect(xml.contains("href=\"https://example.com\""))
    }

    @Test("Exports empty chapter list")
    func exportEmpty() {
        let xml = exporter.export(ChapterList())
        #expect(xml.contains("<psc:chapters"))
        #expect(xml.contains("</psc:chapters>"))
        #expect(!xml.contains("<psc:chapter "))
    }

    @Test("Escapes XML special characters in title")
    func exportEscaping() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Rock & Roll <Live> \"2024\"")
        ])
        let xml = exporter.export(chapters)
        #expect(xml.contains("Rock &amp; Roll &lt;Live&gt; &quot;2024&quot;"))
    }

    // MARK: - Import

    @Test("Imports basic XML")
    func importBasic() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <psc:chapters version="1.2" xmlns:psc="http://podlove.org/simple-chapters">
              <psc:chapter start="00:00:00.000" title="First" />
              <psc:chapter start="00:05:30.000" title="Second" />
            </psc:chapters>
            """
        let chapters = try exporter.importChapters(from: xml)
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "First")
        #expect(chapters[0].start.timeInterval == 0)
        #expect(chapters[1].title == "Second")
        #expect(chapters[1].start.timeInterval == 330)
    }

    @Test("Imports chapters with href")
    func importWithHref() throws {
        let xml = """
            <psc:chapters version="1.2" xmlns:psc="http://podlove.org/simple-chapters">
              <psc:chapter start="00:00:00.000" title="Link" href="https://example.com" />
            </psc:chapters>
            """
        let chapters = try exporter.importChapters(from: xml)
        #expect(chapters[0].url?.absoluteString == "https://example.com")
    }

    @Test("Import rejects missing start attribute")
    func importMissingStart() {
        let xml = """
            <psc:chapters version="1.2" xmlns:psc="http://podlove.org/simple-chapters">
              <psc:chapter title="No Start" />
            </psc:chapters>
            """
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: xml)
        }
    }

    @Test("Import rejects missing title attribute")
    func importMissingTitle() {
        let xml = """
            <psc:chapters version="1.2" xmlns:psc="http://podlove.org/simple-chapters">
              <psc:chapter start="00:00:00.000" />
            </psc:chapters>
            """
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: xml)
        }
    }

    @Test("Import rejects invalid timestamp")
    func importInvalidTimestamp() {
        let xml = """
            <psc:chapters version="1.2" xmlns:psc="http://podlove.org/simple-chapters">
              <psc:chapter start="not-a-time" title="Bad" />
            </psc:chapters>
            """
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: xml)
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
        let xml = exporter.export(original)
        let imported = try exporter.importChapters(from: xml)
        #expect(imported.count == original.count)
        for (orig, imp) in zip(original, imported) {
            #expect(orig.title == imp.title)
            #expect(orig.start.description == imp.start.description)
            #expect(orig.url == imp.url)
        }
    }
}
