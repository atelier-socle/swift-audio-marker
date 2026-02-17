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

@Suite("LRC Parser")
struct LRCParserTests {

    // MARK: - Parse

    @Test("Parses basic LRC lines")
    func parseBasic() throws {
        let lrc = """
            [00:00.00]First line
            [00:05.50]Second line
            [01:30.00]Third line
            """
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines.count == 3)
        #expect(lyrics.lines[0].text == "First line")
        #expect(lyrics.lines[0].time == .zero)
        #expect(lyrics.lines[1].text == "Second line")
        #expect(lyrics.lines[1].time == .milliseconds(5500))
        #expect(lyrics.lines[2].text == "Third line")
        #expect(lyrics.lines[2].time == .seconds(90))
    }

    @Test("Parses 2-digit centiseconds")
    func parseCentiseconds() throws {
        let lrc = "[00:01.50]Half second offset"
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines[0].time == .milliseconds(1500))
    }

    @Test("Parses 3-digit milliseconds")
    func parseMilliseconds() throws {
        let lrc = "[00:01.500]Half second offset"
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines[0].time == .milliseconds(1500))
    }

    @Test("Skips metadata lines")
    func skipsMetadata() throws {
        let lrc = """
            [ti:My Song]
            [ar:My Artist]
            [al:My Album]
            [00:00.00]Actual lyric
            """
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines.count == 1)
        #expect(lyrics.lines[0].text == "Actual lyric")
    }

    @Test("Skips blank lines")
    func skipsBlankLines() throws {
        let lrc = """
            [00:00.00]First

            [00:05.00]Second
            """
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines.count == 2)
    }

    @Test("No valid lines throws invalidData")
    func noValidLinesThrows() {
        let lrc = """
            [ti:Title]
            [ar:Artist]
            just some text
            """
        #expect(throws: ExportError.self) {
            try LRCParser.parse(lrc)
        }
    }

    @Test("Sorts lines by timestamp")
    func sortsLines() throws {
        let lrc = """
            [01:00.00]Second
            [00:00.00]First
            [02:00.00]Third
            """
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines[0].text == "First")
        #expect(lyrics.lines[1].text == "Second")
        #expect(lyrics.lines[2].text == "Third")
    }

    @Test("Uses provided language")
    func usesLanguage() throws {
        let lyrics = try LRCParser.parse("[00:00.00]Hello", language: "eng")
        #expect(lyrics.language == "eng")
    }

    @Test("Default language is und")
    func defaultLanguage() throws {
        let lyrics = try LRCParser.parse("[00:00.00]Hello")
        #expect(lyrics.language == "und")
    }

    @Test("Minutes exceeding 59")
    func highMinutes() throws {
        let lrc = "[99:59.99]Near end"
        let lyrics = try LRCParser.parse(lrc)
        let expectedMs = 99 * 60_000 + 59 * 1000 + 990
        #expect(lyrics.lines[0].time == .milliseconds(expectedMs))
    }

    // MARK: - Export

    @Test("Exports synchronized lyrics to LRC format")
    func exportBasic() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .zero, text: "First line"),
                LyricLine(time: .milliseconds(5500), text: "Second line"),
                LyricLine(time: .seconds(90), text: "Third line")
            ]
        )
        let result = LRCParser.export(lyrics)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == "[la:eng]")
        #expect(lines[1] == "[00:00.00]First line")
        #expect(lines[2] == "[00:05.50]Second line")
        #expect(lines[3] == "[01:30.00]Third line")
    }

    @Test("Export includes language tag when not und")
    func exportIncludesLanguageTag() {
        let lyrics = SynchronizedLyrics(
            language: "fra",
            lines: [LyricLine(time: .zero, text: "Bonjour")]
        )
        let result = LRCParser.export(lyrics)
        #expect(result.hasPrefix("[la:fra]"))
    }

    @Test("Export omits language tag when und")
    func exportOmitsLanguageTagForUnd() {
        let lyrics = SynchronizedLyrics(
            language: "und",
            lines: [LyricLine(time: .zero, text: "Hello")]
        )
        let result = LRCParser.export(lyrics)
        #expect(!result.contains("[la:"))
    }

    @Test("Parse reads embedded language tag")
    func parseEmbeddedLanguage() throws {
        let lrc = "[la:eng]\n[00:00.00]Hello"
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.language == "eng")
        #expect(lyrics.lines.count == 1)
    }

    @Test("Explicit language parameter overrides embedded tag")
    func explicitLanguageOverridesEmbedded() throws {
        let lrc = "[la:eng]\n[00:00.00]Hello"
        let lyrics = try LRCParser.parse(lrc, language: "fra")
        #expect(lyrics.language == "fra")
    }

    @Test("Language round-trip through LRC preserves code")
    func languageRoundTrip() throws {
        let original = SynchronizedLyrics(
            language: "eng",
            lines: [LyricLine(time: .zero, text: "Hello")]
        )
        let exported = LRCParser.export(original)
        let reimported = try LRCParser.parse(exported)
        #expect(reimported.language == "eng")
    }

    // MARK: - Round-Trip

    @Test("Round-trip parse then export preserves content")
    func roundTrip() throws {
        let original = """
            [00:00.00]First line
            [00:05.50]Second line
            [01:30.00]Third line
            """
        let lyrics = try LRCParser.parse(original)
        let exported = LRCParser.export(lyrics)
        let reimported = try LRCParser.parse(exported)

        #expect(reimported.lines.count == lyrics.lines.count)
        for (orig, reimp) in zip(lyrics.lines, reimported.lines) {
            #expect(orig.text == reimp.text)
            #expect(orig.time == reimp.time)
        }
    }
}
