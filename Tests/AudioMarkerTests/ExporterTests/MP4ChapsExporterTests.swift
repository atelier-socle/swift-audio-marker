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

@Suite("MP4Chaps Exporter")
struct MP4ChapsExporterTests {

    let exporter = MP4ChapsExporter()

    // MARK: - Export

    @Test("Exports basic chapters")
    func exportBasic() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Introduction"),
            Chapter(start: .seconds(60), title: "Main Topic")
        ])
        let text = exporter.export(chapters)
        let lines = text.split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "00:00:00.000 Introduction")
        #expect(lines[1] == "00:01:00.000 Main Topic")
    }

    @Test("Exports chapters with milliseconds")
    func exportWithMilliseconds() {
        let chapters = ChapterList([
            Chapter(start: .milliseconds(500), title: "Half Second"),
            Chapter(start: .milliseconds(90_500), title: "Ninety Point Five")
        ])
        let text = exporter.export(chapters)
        #expect(text.contains("00:00:00.500 Half Second"))
        #expect(text.contains("00:01:30.500 Ninety Point Five"))
    }

    @Test("Exports empty chapter list")
    func exportEmpty() {
        let text = exporter.export(ChapterList())
        #expect(text == "\n")
    }

    // MARK: - Import

    @Test("Imports basic chapters")
    func importBasic() throws {
        let text = """
            00:00:00.000 Introduction
            00:01:00.000 Main Topic
            """
        let chapters = try exporter.importChapters(from: text)
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "Introduction")
        #expect(chapters[0].start.timeInterval == 0)
        #expect(chapters[1].title == "Main Topic")
        #expect(chapters[1].start.timeInterval == 60)
    }

    @Test("Imports chapters with milliseconds")
    func importWithMilliseconds() throws {
        let text = "00:01:30.500 Chapter One\n"
        let chapters = try exporter.importChapters(from: text)
        #expect(chapters.count == 1)
        #expect(chapters[0].start.timeInterval == 90.5)
        #expect(chapters[0].title == "Chapter One")
    }

    @Test("Skips empty lines")
    func importSkipsEmptyLines() throws {
        let text = """
            00:00:00.000 First

            00:01:00.000 Second
            """
        let chapters = try exporter.importChapters(from: text)
        #expect(chapters.count == 2)
    }

    @Test("Import rejects line without space")
    func importRejectsInvalid() {
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: "00:00:00.000")
        }
    }

    @Test("Import rejects line with empty title")
    func importRejectsEmptyTitle() {
        #expect(throws: ExportError.self) {
            try exporter.importChapters(from: "00:00:00.000  ")
        }
    }

    // MARK: - Round-Trip

    @Test("Round-trip preserves chapters")
    func roundTrip() throws {
        let original = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .milliseconds(90_500), title: "Chapter 2"),
            Chapter(start: .seconds(300), title: "End")
        ])
        let text = exporter.export(original)
        let imported = try exporter.importChapters(from: text)
        #expect(imported.count == original.count)
        for (orig, imp) in zip(original, imported) {
            #expect(orig.title == imp.title)
            #expect(orig.start.description == imp.start.description)
        }
    }
}
