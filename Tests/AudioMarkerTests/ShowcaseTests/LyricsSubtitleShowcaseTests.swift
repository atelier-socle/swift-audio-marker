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

/// Demonstrates WebVTT, SRT, speaker attribution, and TTML document round-trips.
@Suite("Showcase: Lyrics Subtitles & Speakers")
struct LyricsSubtitleShowcaseTests {

    // MARK: - WebVTT

    @Test("Export and import WebVTT format")
    func webvttRoundTrip() throws {
        let lyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "First cue"),
                    LyricLine(time: .seconds(5), text: "Second cue"),
                    LyricLine(time: .seconds(10), text: "Third cue")
                ])
        ]

        // Export to WebVTT
        let vtt = WebVTTExporter.export(lyrics, audioDuration: .seconds(15))
        #expect(vtt.hasPrefix("WEBVTT"))
        #expect(vtt.contains("First cue"))
        #expect(vtt.contains("-->"))

        // Re-import
        let reparsed = try WebVTTExporter.parse(vtt, language: "eng")
        #expect(reparsed.lines.count == 3)
        #expect(reparsed.lines[0].text == "First cue")
        #expect(reparsed.lines[2].text == "Third cue")
    }

    // MARK: - SRT

    @Test("Export and import SRT format")
    func srtRoundTrip() throws {
        let lyrics = [
            SynchronizedLyrics(
                language: "fra",
                lines: [
                    LyricLine(time: .zero, text: "Bonjour"),
                    LyricLine(time: .seconds(5), text: "Au revoir")
                ])
        ]

        // Export to SRT
        let srt = SRTExporter.export(lyrics, audioDuration: .seconds(10))
        #expect(srt.contains("Bonjour"))
        #expect(srt.contains("-->"))
        // SRT uses comma for milliseconds
        #expect(srt.contains(","))

        // Re-import
        let reparsed = try SRTExporter.parse(srt, language: "fra")
        #expect(reparsed.lines.count == 2)
        #expect(reparsed.language == "fra")
        #expect(reparsed.lines[0].text == "Bonjour")
    }

    // MARK: - Speaker Attribution

    @Test("LyricLine with speaker for TTML agent round-trip")
    func speakerRoundTrip() throws {
        let lyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "Hello!", speaker: "Alice"),
                    LyricLine(
                        time: .seconds(3), text: "Hi there!", speaker: "Bob"),
                    LyricLine(
                        time: .seconds(6), text: "How are you?",
                        speaker: "Alice")
                ])
        ]

        // Convert to TTMLDocument — agents are generated
        let doc = TTMLDocument.from(lyrics)
        #expect(doc.agents.count == 2)
        #expect(doc.agents[0].name == "Alice")
        #expect(doc.agents[1].name == "Bob")

        // Export to TTML XML
        let ttml = TTMLExporter.exportDocument(doc)
        #expect(ttml.contains("ttm:agent"))
        #expect(ttml.contains("<ttm:name>Alice</ttm:name>"))

        // Re-parse document
        let parser = TTMLParser()
        let reparsedDoc = try parser.parseDocument(from: ttml)
        let reparsedLyrics = reparsedDoc.toSynchronizedLyrics()

        // Speakers survive the round-trip
        #expect(reparsedLyrics[0].lines[0].speaker == "Alice")
        #expect(reparsedLyrics[0].lines[1].speaker == "Bob")
        #expect(reparsedLyrics[0].lines[2].speaker == "Alice")
    }

    // MARK: - TTML Document Round-Trip

    @Test("TTML document round-trip preserves structure")
    func ttmlDocumentRoundTrip() throws {
        let parser = TTMLParser()

        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:ttm="http://www.w3.org/ns/ttml#metadata"
                xmlns:tts="http://www.w3.org/ns/ttml#styling"
                xmlns:ttp="http://www.w3.org/ns/ttml#parameter"
                ttp:timeBase="media">
              <head>
                <metadata>
                  <ttm:title>Round Trip Song</ttm:title>
                </metadata>
                <styling>
                  <style xml:id="s1" tts:color="#FFFFFF"/>
                </styling>
              </head>
              <body>
                <div xml:lang="en">
                  <p begin="00:00:00.000" end="00:00:05.000" style="s1">Hello</p>
                </div>
              </body>
            </tt>
            """

        // Parse full document
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.title == "Round Trip Song")
        #expect(doc.styles.count == 1)

        // Export as document
        let exported = TTMLExporter.exportDocument(doc)

        // Re-parse
        let reparsed = try parser.parseDocument(from: exported)
        #expect(reparsed.title == "Round Trip Song")
        #expect(reparsed.styles.count == 1)
        #expect(reparsed.styles[0].id == "s1")
        #expect(reparsed.divisions[0].paragraphs[0].text == "Hello")
    }
}
