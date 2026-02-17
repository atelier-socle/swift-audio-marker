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

@Suite("Markdown Exporter")
struct MarkdownExporterTests {

    let exporter = MarkdownExporter()

    @Test("Exports basic chapters")
    func exportBasic() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Introduction"),
            Chapter(start: .seconds(60), title: "Main Topic"),
            Chapter(start: .seconds(300), title: "Conclusion")
        ])
        let md = exporter.export(chapters)
        let lines = md.split(separator: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "1. **00:00:00** \u{2014} Introduction")
        #expect(lines[1] == "2. **00:01:00** \u{2014} Main Topic")
        #expect(lines[2] == "3. **00:05:00** \u{2014} Conclusion")
    }

    @Test("Uses short description for whole seconds")
    func shortDescription() {
        let chapters = ChapterList([
            Chapter(start: .seconds(90), title: "Ninety Seconds")
        ])
        let md = exporter.export(chapters)
        #expect(md.contains("**00:01:30**"))
        #expect(!md.contains(".000"))
    }

    @Test("Uses full description for fractional seconds")
    func fullDescription() {
        let chapters = ChapterList([
            Chapter(start: .milliseconds(500), title: "Half Second")
        ])
        let md = exporter.export(chapters)
        #expect(md.contains("**00:00:00.500**"))
    }

    @Test("Exports empty chapter list")
    func exportEmpty() {
        let md = exporter.export(ChapterList())
        #expect(md == "\n")
    }

    @Test("Uses em-dash separator")
    func emDashSeparator() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Test")
        ])
        let md = exporter.export(chapters)
        #expect(md.contains("\u{2014}"))
    }
}
