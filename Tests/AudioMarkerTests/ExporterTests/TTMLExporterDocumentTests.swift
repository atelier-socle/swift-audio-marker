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

@Suite("TTML Exporter Document")
struct TTMLExporterDocumentTests {

    // MARK: - TTMLDocument Export

    @Test("Exports TTMLDocument with styles and regions")
    func exportDocument() {
        let doc = TTMLDocument(
            language: "en",
            styles: [
                TTMLStyle(
                    id: "s1", properties: ["tts:color": "#FFFFFF"])
            ],
            regions: [
                TTMLRegion(
                    id: "r1", origin: "10% 80%", extent: "80% 20%")
            ],
            divisions: [
                TTMLDivision(
                    language: "en",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(3), text: "Hello")
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("xml:lang=\"en\""))
        #expect(result.contains("xmlns:tts="))
        #expect(result.contains("<style xml:id=\"s1\""))
        #expect(result.contains("tts:color=\"#FFFFFF\""))
        #expect(result.contains("<region xml:id=\"r1\""))
        #expect(result.contains("tts:origin=\"10% 80%\""))
        #expect(result.contains(">Hello</p>"))
    }

    @Test("Exports TTMLDocument with title and description")
    func exportDocumentMetadata() {
        let doc = TTMLDocument(
            language: "en",
            title: "My Song",
            description: "A great song",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Line")
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("<ttm:title>My Song</ttm:title>"))
        #expect(result.contains("<ttm:desc>A great song</ttm:desc>"))
    }

    @Test("Exports TTMLDocument with agents")
    func exportDocumentAgents() {
        let doc = TTMLDocument(
            language: "en",
            agents: [
                TTMLAgent(id: "narrator", type: "person", name: "John")
            ],
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Line")
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("<ttm:agent xml:id=\"narrator\""))
        #expect(result.contains("type=\"person\""))
        #expect(result.contains("<ttm:name>John</ttm:name>"))
    }

    @Test("Exports TTMLDocument with paragraph attributes")
    func exportDocumentParagraphAttributes() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1),
                            text: "Line",
                            styleID: "s1",
                            regionID: "r1",
                            agentID: "narrator",
                            role: "dialog")
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("style=\"s1\""))
        #expect(result.contains("region=\"r1\""))
        #expect(result.contains("ttm:agent=\"narrator\""))
        #expect(result.contains("ttm:role=\"dialog\""))
    }

    @Test("Exports TTMLDocument with karaoke spans")
    func exportDocumentKaraoke() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(5),
                            text: "Hello world",
                            spans: [
                                TTMLSpan(
                                    begin: .zero, end: .seconds(2),
                                    text: "Hello"),
                                TTMLSpan(
                                    begin: .seconds(2), end: .seconds(5),
                                    text: "world")
                            ])
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("<span begin=\"00:00:00.000\" end=\"00:00:02.000\">Hello</span>"))
        #expect(result.contains("<span begin=\"00:00:02.000\" end=\"00:00:05.000\">world</span>"))
    }

    @Test("TTMLDocument export omits head when empty")
    func exportDocumentNoHead() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Line")
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(!result.contains("<head>"))
    }

    @Test("Exports TTMLDocument with frameRate")
    func exportDocumentFrameRate() {
        let doc = TTMLDocument(
            language: "en",
            timeBase: "smpte",
            frameRate: 25,
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Line")
                    ])
            ])
        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("ttp:frameRate=\"25\""))
    }

    @Test("Exports TTMLDocument with region displayAlign and properties")
    func exportDocumentRegionFull() {
        let doc = TTMLDocument(
            language: "en",
            regions: [
                TTMLRegion(
                    id: "r1",
                    origin: "10% 80%",
                    extent: "80% 20%",
                    displayAlign: "after",
                    properties: ["tts:overflow": "visible"])
            ],
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Line")
                    ])
            ])
        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("tts:displayAlign=\"after\""))
        #expect(result.contains("tts:overflow=\"visible\""))
    }

    @Test("Exports TTMLDocument div with style and region")
    func exportDocumentDivAttributes() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    language: "fr",
                    styleID: "s1",
                    regionID: "r1",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Bonjour")
                    ])
            ])
        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("xml:lang=\"fr\""))
        #expect(result.contains("style=\"s1\""))
        #expect(result.contains("region=\"r1\""))
    }

    @Test("TTMLDocument.from calculates end times from next line")
    func fromCalculatesEndTimes() {
        let lyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .seconds(5), text: "First"),
                    LyricLine(time: .seconds(10), text: "Second"),
                    LyricLine(time: .seconds(15), text: "Third")
                ])
        ]
        let doc = TTMLDocument.from(lyrics)
        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("begin=\"00:00:05.000\" end=\"00:00:10.000\""))
        #expect(result.contains("begin=\"00:00:10.000\" end=\"00:00:15.000\""))
        // Last line has no end time.
        #expect(result.contains("<p begin=\"00:00:15.000\">Third</p>"))
    }

    @Test("TTMLDocument.from preserves existing end times from segments")
    func fromPreservesSegmentEndTimes() {
        let lyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(
                        time: .zero, text: "Hello world",
                        segments: [
                            LyricSegment(
                                startTime: .zero, endTime: .seconds(2),
                                text: "Hello"),
                            LyricSegment(
                                startTime: .seconds(2), endTime: .seconds(5),
                                text: "world")
                        ])
                ])
        ]
        let doc = TTMLDocument.from(lyrics)
        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("<span begin=\"00:00:00.000\" end=\"00:00:02.000\">Hello</span>"))
        #expect(result.contains("<span begin=\"00:00:02.000\" end=\"00:00:05.000\">world</span>"))
    }

    @Test("Exports TTMLDocument span with style")
    func exportDocumentSpanStyle() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(5),
                            text: "Hello",
                            spans: [
                                TTMLSpan(
                                    begin: .zero, end: .seconds(2),
                                    text: "Hello", styleID: "hl")
                            ])
                    ])
            ])
        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("style=\"hl\""))
    }
}
