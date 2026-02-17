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

@Suite("Podcast Namespace Parser")
struct PodcastNamespaceParserTests {

    // MARK: - Parse

    @Test("Parse basic chapters")
    func parseBasic() throws {
        let json = """
            {
              "version": "1.2.0",
              "chapters": [
                { "startTime": 0, "title": "Intro" },
                { "startTime": 60, "title": "Main" },
                { "startTime": 300, "title": "Outro" }
              ]
            }
            """
        let chapters = try PodcastNamespaceParser.parse(json)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Intro")
        #expect(chapters[0].start.timeInterval == 0)
        #expect(chapters[1].title == "Main")
        #expect(chapters[1].start.timeInterval == 60)
        #expect(chapters[2].title == "Outro")
        #expect(chapters[2].start.timeInterval == 300)
    }

    @Test("Parse integer and decimal startTime")
    func parseStartTimeTypes() throws {
        let json = """
            {
              "version": "1.2.0",
              "chapters": [
                { "startTime": 0, "title": "Zero" },
                { "startTime": 168.5, "title": "Decimal" },
                { "startTime": 3600, "title": "Hour" }
              ]
            }
            """
        let chapters = try PodcastNamespaceParser.parse(json)
        #expect(chapters[0].start.timeInterval == 0)
        #expect(chapters[1].start.timeInterval == 168.5)
        #expect(chapters[2].start.timeInterval == 3600)
    }

    @Test("Parse with optional URL")
    func parseWithURL() throws {
        let json = """
            {
              "version": "1.2.0",
              "chapters": [
                { "startTime": 0, "title": "Intro", "url": "https://example.com/intro" },
                { "startTime": 60, "title": "No URL" }
              ]
            }
            """
        let chapters = try PodcastNamespaceParser.parse(json)
        #expect(chapters[0].url?.absoluteString == "https://example.com/intro")
        #expect(chapters[1].url == nil)
    }

    @Test("Parse ignores unknown fields (img, toc, location)")
    func parseIgnoresUnknown() throws {
        let json = """
            {
              "version": "1.2.0",
              "chapters": [
                {
                  "startTime": 0,
                  "title": "Intro",
                  "img": "https://example.com/img.jpg",
                  "toc": false,
                  "location": { "name": "Somewhere" }
                }
              ]
            }
            """
        let chapters = try PodcastNamespaceParser.parse(json)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Intro")
    }

    @Test("Parse missing title throws")
    func parseMissingTitle() {
        let json = """
            {
              "version": "1.2.0",
              "chapters": [
                { "startTime": 0 }
              ]
            }
            """
        #expect(throws: ExportError.self) {
            _ = try PodcastNamespaceParser.parse(json)
        }
    }

    @Test("Parse missing startTime throws")
    func parseMissingStartTime() {
        let json = """
            {
              "version": "1.2.0",
              "chapters": [
                { "title": "No time" }
              ]
            }
            """
        #expect(throws: ExportError.self) {
            _ = try PodcastNamespaceParser.parse(json)
        }
    }

    @Test("Parse invalid JSON throws")
    func parseInvalidJSON() {
        #expect(throws: ExportError.self) {
            _ = try PodcastNamespaceParser.parse("not json at all")
        }
    }

    @Test("Parse missing chapters array throws")
    func parseMissingChapters() {
        let json = """
            { "version": "1.2.0" }
            """
        #expect(throws: ExportError.self) {
            _ = try PodcastNamespaceParser.parse(json)
        }
    }

    // MARK: - Export

    @Test("Export basic chapters")
    func exportBasic() throws {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .seconds(60), title: "Main"),
            Chapter(start: .seconds(300), title: "Outro")
        ])
        let json = try PodcastNamespaceParser.export(chapters)
        #expect(json.contains("\"version\" : \"1.2.0\""))
        #expect(json.contains("\"title\" : \"Intro\""))
        #expect(json.contains("\"title\" : \"Main\""))
        #expect(json.contains("\"title\" : \"Outro\""))
        #expect(json.contains("startTime"))
    }

    @Test("Export with URL")
    func exportWithURL() throws {
        let chapters = ChapterList([
            Chapter(
                start: .zero, title: "Intro",
                url: URL(string: "https://example.com"))
        ])
        let json = try PodcastNamespaceParser.export(chapters)
        #expect(json.contains("\"url\" : \"https://example.com\""))
    }

    @Test("Export empty chapters")
    func exportEmpty() throws {
        let chapters = ChapterList()
        let json = try PodcastNamespaceParser.export(chapters)
        #expect(json.contains("\"chapters\" : ["))
        #expect(json.contains("\"version\" : \"1.2.0\""))
    }

    @Test("Export fractional seconds preserves precision")
    func exportFractionalSeconds() throws {
        let chapters = ChapterList([
            Chapter(start: .seconds(168.5), title: "Halfway")
        ])
        let json = try PodcastNamespaceParser.export(chapters)
        #expect(json.contains("168.5"))
    }

    @Test("Export milliseconds rounds to 3 decimal places without floating-point artifacts")
    func exportMillisecondsRounded() throws {
        let chapters = ChapterList([
            Chapter(start: .milliseconds(30508), title: "Precise")
        ])
        let json = try PodcastNamespaceParser.export(chapters)
        #expect(json.contains("30.508"))
        #expect(!json.contains("30.507"))
        #expect(!json.contains("30.509"))
    }

    @Test("Export whole seconds as integer without decimals")
    func exportWholeSecondsAsInteger() throws {
        let chapters = ChapterList([
            Chapter(start: .seconds(480), title: "Eight Minutes")
        ])
        let json = try PodcastNamespaceParser.export(chapters)
        #expect(json.contains("\"startTime\" : 480"))
        #expect(!json.contains("480."))
    }

    // MARK: - Round-Trip

    @Test("Round-trip preserves data")
    func roundTrip() throws {
        let original = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(
                start: .seconds(168.5), title: "Discussion",
                url: URL(string: "https://example.com")),
            Chapter(start: .seconds(3600), title: "End")
        ])

        let exported = try PodcastNamespaceParser.export(original)
        let imported = try PodcastNamespaceParser.parse(exported)

        #expect(imported.count == original.count)
        for (orig, imp) in zip(original, imported) {
            #expect(orig.title == imp.title)
            #expect(abs(orig.start.timeInterval - imp.start.timeInterval) < 0.001)
            #expect(orig.url == imp.url)
        }
    }
}
