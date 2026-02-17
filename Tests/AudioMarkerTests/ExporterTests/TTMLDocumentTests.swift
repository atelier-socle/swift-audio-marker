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

@Suite("TTML Document")
struct TTMLDocumentTests {

    // MARK: - toSynchronizedLyrics

    @Test("Converts single division to synchronized lyrics")
    func toSynchronizedLyricsBasic() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    language: "en",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(3), text: "Hello"),
                        TTMLParagraph(
                            begin: .seconds(3), end: .seconds(6), text: "World")
                    ])
            ])

        let lyrics = doc.toSynchronizedLyrics()
        #expect(lyrics.count == 1)
        #expect(lyrics[0].language == "eng")
        #expect(lyrics[0].lines.count == 2)
        #expect(lyrics[0].lines[0].text == "Hello")
        #expect(lyrics[0].lines[0].time == .zero)
        #expect(lyrics[0].lines[1].text == "World")
    }

    @Test("Converts multiple divisions to multiple lyrics")
    func toSynchronizedLyricsMultiLang() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    language: "en",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(5), text: "Hello")
                    ]),
                TTMLDivision(
                    language: "fr",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(5), text: "Bonjour")
                    ])
            ])

        let lyrics = doc.toSynchronizedLyrics()
        #expect(lyrics.count == 2)
        #expect(lyrics[0].language == "eng")
        #expect(lyrics[1].language == "fra")
    }

    @Test("Preserves karaoke spans in conversion")
    func toSynchronizedLyricsKaraoke() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    language: "en",
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

        let lyrics = doc.toSynchronizedLyrics()
        let line = lyrics[0].lines[0]
        #expect(line.isKaraoke)
        #expect(line.segments.count == 2)
        #expect(line.segments[0].text == "Hello")
        #expect(line.segments[0].startTime == .zero)
        #expect(line.segments[0].endTime == .seconds(2))
        #expect(line.segments[1].text == "world")
    }

    @Test("Uses document language when division has no language")
    func fallsBackToDocumentLanguage() {
        let doc = TTMLDocument(
            language: "de",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Hallo")
                    ])
            ])

        let lyrics = doc.toSynchronizedLyrics()
        #expect(lyrics[0].language == "deu")
    }

    @Test("Passes through 3-letter language codes unchanged")
    func threeLetterCodePassthrough() {
        let doc = TTMLDocument(
            language: "eng",
            divisions: [
                TTMLDivision(
                    language: "eng",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Hi")
                    ])
            ])

        let lyrics = doc.toSynchronizedLyrics()
        #expect(lyrics[0].language == "eng")
    }

    // MARK: - from() Factory

    @Test("Creates document from synchronized lyrics")
    func fromSynchronizedLyrics() {
        let lyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "First"),
                    LyricLine(time: .seconds(5), text: "Second")
                ])
        ]

        let doc = TTMLDocument.from(lyrics)
        #expect(doc.language == "eng")
        #expect(doc.divisions.count == 1)
        #expect(doc.divisions[0].language == "eng")
        #expect(doc.divisions[0].paragraphs.count == 2)
        #expect(doc.divisions[0].paragraphs[0].text == "First")
        #expect(doc.divisions[0].paragraphs[0].begin == .zero)
        #expect(doc.divisions[0].paragraphs[1].text == "Second")
    }

    @Test("Preserves karaoke segments in from()")
    func fromPreservesKaraoke() {
        let segments = [
            LyricSegment(startTime: .zero, endTime: .seconds(2), text: "Hello"),
            LyricSegment(
                startTime: .seconds(2), endTime: .seconds(5), text: "world",
                styleID: "s1")
        ]
        let lyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(
                        time: .zero, text: "Hello world",
                        segments: segments)
                ])
        ]

        let doc = TTMLDocument.from(lyrics)
        let para = doc.divisions[0].paragraphs[0]
        #expect(para.spans.count == 2)
        #expect(para.spans[0].text == "Hello")
        #expect(para.spans[0].begin == .zero)
        #expect(para.spans[0].end == .seconds(2))
        #expect(para.spans[1].text == "world")
        #expect(para.spans[1].styleID == "s1")
    }

    @Test("from() with empty input uses und language")
    func fromEmptyLyrics() {
        let doc = TTMLDocument.from([])
        #expect(doc.language == "und")
        #expect(doc.divisions.isEmpty)
    }

    // MARK: - Round-Trip

    @Test("Round-trip: SynchronizedLyrics → TTMLDocument → SynchronizedLyrics")
    func roundTrip() {
        let original = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "Hello"),
                    LyricLine(time: .seconds(3), text: "World"),
                    LyricLine(time: .seconds(6), text: "Goodbye")
                ])
        ]

        let doc = TTMLDocument.from(original)
        let result = doc.toSynchronizedLyrics()

        #expect(result.count == 1)
        #expect(result[0].lines.count == 3)
        #expect(result[0].lines[0].text == "Hello")
        #expect(result[0].lines[0].time == .zero)
        #expect(result[0].lines[1].text == "World")
        #expect(result[0].lines[1].time == .seconds(3))
        #expect(result[0].lines[2].text == "Goodbye")
        #expect(result[0].lines[2].time == .seconds(6))
    }

    @Test("Round-trip with karaoke preserves segments")
    func roundTripKaraoke() {
        let segments = [
            LyricSegment(startTime: .zero, endTime: .seconds(1), text: "A"),
            LyricSegment(
                startTime: .seconds(1), endTime: .seconds(2), text: "B")
        ]
        let original = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(
                        time: .zero, text: "A B", segments: segments)
                ])
        ]

        let doc = TTMLDocument.from(original)
        let result = doc.toSynchronizedLyrics()

        #expect(result[0].lines[0].isKaraoke)
        #expect(result[0].lines[0].segments.count == 2)
        #expect(result[0].lines[0].segments[0].text == "A")
        #expect(result[0].lines[0].segments[1].text == "B")
    }

    // MARK: - Hashable / Equatable

    @Test("TTMLDocument is Equatable")
    func equatable() {
        let doc1 = TTMLDocument(language: "en")
        let doc2 = TTMLDocument(language: "en")
        let doc3 = TTMLDocument(language: "fr")
        #expect(doc1 == doc2)
        #expect(doc1 != doc3)
    }
}
