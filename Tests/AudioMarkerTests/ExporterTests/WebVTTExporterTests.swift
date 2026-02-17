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

@Suite("WebVTT Exporter")
struct WebVTTExporterTests {

    // MARK: - Parse

    @Test("Parses basic WebVTT cues")
    func parseBasic() throws {
        let vtt = """
            WEBVTT

            1
            00:00:05.000 --> 00:00:08.500
            Welcome to the show

            2
            00:00:10.000 --> 00:00:14.000
            Feel the music
            """
        let lyrics = try WebVTTExporter.parse(vtt)
        #expect(lyrics.lines.count == 2)
        #expect(lyrics.lines[0].text == "Welcome to the show")
        #expect(lyrics.lines[0].time == .milliseconds(5000))
        #expect(lyrics.lines[1].text == "Feel the music")
        #expect(lyrics.lines[1].time == .milliseconds(10_000))
    }

    @Test("Parses cues without sequence numbers")
    func parsesWithoutSequenceNumbers() throws {
        let vtt = """
            WEBVTT

            00:00:05.000 --> 00:00:08.500
            First cue

            00:00:10.000 --> 00:00:14.000
            Second cue
            """
        let lyrics = try WebVTTExporter.parse(vtt)
        #expect(lyrics.lines.count == 2)
        #expect(lyrics.lines[0].text == "First cue")
        #expect(lyrics.lines[1].text == "Second cue")
    }

    @Test("Parses short timestamp format MM:SS.mmm")
    func parsesShortTimestamp() throws {
        let vtt = """
            WEBVTT

            01:30.000 --> 02:00.000
            Short format
            """
        let lyrics = try WebVTTExporter.parse(vtt)
        #expect(lyrics.lines[0].time == .milliseconds(90_000))
    }

    @Test("Skips NOTE comments")
    func skipsNoteComments() throws {
        let vtt = """
            WEBVTT

            NOTE
            This is a comment that spans
            multiple lines

            1
            00:00:05.000 --> 00:00:08.000
            Actual content
            """
        let lyrics = try WebVTTExporter.parse(vtt)
        #expect(lyrics.lines.count == 1)
        #expect(lyrics.lines[0].text == "Actual content")
    }

    @Test("Strips HTML tags from text")
    func stripsHTMLTags() throws {
        let vtt = """
            WEBVTT

            00:00:00.000 --> 00:00:05.000
            <b>Bold</b> and <i>italic</i>
            """
        let lyrics = try WebVTTExporter.parse(vtt)
        #expect(lyrics.lines[0].text == "Bold and italic")
    }

    @Test("Joins multi-line cue text with space")
    func joinsMultilineText() throws {
        let vtt = """
            WEBVTT

            00:00:00.000 --> 00:00:05.000
            First line
            Second line
            """
        let lyrics = try WebVTTExporter.parse(vtt)
        #expect(lyrics.lines[0].text == "First line Second line")
    }

    @Test("Missing WEBVTT header throws invalidFormat")
    func missingHeaderThrows() {
        #expect(throws: ExportError.self) {
            try WebVTTExporter.parse("00:00:00.000 --> 00:00:05.000\nHello")
        }
    }

    @Test("Empty input throws invalidFormat")
    func emptyInputThrows() {
        #expect(throws: ExportError.self) {
            try WebVTTExporter.parse("")
        }
    }

    @Test("No cues throws invalidData")
    func noCuesThrows() {
        #expect(throws: ExportError.self) {
            try WebVTTExporter.parse("WEBVTT\n\n")
        }
    }

    @Test("Uses provided language")
    func usesLanguage() throws {
        let vtt = "WEBVTT\n\n00:00:00.000 --> 00:00:05.000\nHello"
        let lyrics = try WebVTTExporter.parse(vtt, language: "eng")
        #expect(lyrics.language == "eng")
    }

    @Test("Default language is und")
    func defaultLanguage() throws {
        let vtt = "WEBVTT\n\n00:00:00.000 --> 00:00:05.000\nHello"
        let lyrics = try WebVTTExporter.parse(vtt)
        #expect(lyrics.language == "und")
    }

    // MARK: - Export

    @Test("Exports basic lyrics to WebVTT")
    func exportBasic() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .milliseconds(5000), text: "Welcome"),
                LyricLine(time: .milliseconds(10_000), text: "Hello")
            ]
        )
        let result = WebVTTExporter.export([lyrics])
        #expect(result.hasPrefix("WEBVTT\n"))
        #expect(result.contains("00:00:05.000 --> 00:00:10.000"))
        #expect(result.contains("Welcome"))
        #expect(result.contains("Hello"))
    }

    @Test("Export uses audioDuration for last cue end time")
    func exportUsesAudioDuration() {
        let lyrics = SynchronizedLyrics(
            language: "und",
            lines: [LyricLine(time: .milliseconds(5000), text: "Only line")]
        )
        let result = WebVTTExporter.export([lyrics], audioDuration: .seconds(120))
        #expect(result.contains("00:00:05.000 --> 00:02:00.000"))
    }

    @Test("Export defaults to 5-second duration for last cue without audioDuration")
    func exportDefaultsDuration() {
        let lyrics = SynchronizedLyrics(
            language: "und",
            lines: [LyricLine(time: .milliseconds(10_000), text: "Last line")]
        )
        let result = WebVTTExporter.export([lyrics])
        #expect(result.contains("00:00:10.000 --> 00:00:15.000"))
    }

    @Test("Export with empty lyrics produces header only")
    func exportEmpty() {
        let lyrics = SynchronizedLyrics(language: "und", lines: [])
        let result = WebVTTExporter.export([lyrics])
        #expect(result == "WEBVTT\n")
    }

    @Test("Export merges and sorts multiple lyrics")
    func exportMergesMultiple() {
        let lyrics1 = SynchronizedLyrics(
            language: "eng",
            lines: [LyricLine(time: .milliseconds(10_000), text: "Second")]
        )
        let lyrics2 = SynchronizedLyrics(
            language: "eng",
            lines: [LyricLine(time: .milliseconds(5000), text: "First")]
        )
        let result = WebVTTExporter.export([lyrics1, lyrics2])
        guard let firstRange = result.range(of: "First"),
            let secondRange = result.range(of: "Second")
        else {
            Issue.record("Expected both 'First' and 'Second' in output")
            return
        }
        #expect(firstRange.lowerBound < secondRange.lowerBound)
    }

    // MARK: - Round-Trip

    @Test("Round-trip preserves content")
    func roundTrip() throws {
        let original = SynchronizedLyrics(
            language: "und",
            lines: [
                LyricLine(time: .zero, text: "First line"),
                LyricLine(time: .milliseconds(5000), text: "Second line"),
                LyricLine(time: .milliseconds(90_000), text: "Third line")
            ]
        )
        let exported = WebVTTExporter.export([original])
        let reimported = try WebVTTExporter.parse(exported)

        #expect(reimported.lines.count == original.lines.count)
        for (orig, reimp) in zip(original.lines, reimported.lines) {
            #expect(orig.text == reimp.text)
            #expect(orig.time == reimp.time)
        }
    }
}
