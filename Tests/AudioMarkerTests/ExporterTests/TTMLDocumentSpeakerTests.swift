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

@Suite("TTML Document Speaker")
struct TTMLDocumentSpeakerTests {

    // MARK: - toSynchronizedLyrics with Agents

    @Test("toSynchronizedLyrics resolves agent name as speaker")
    func toSynchronizedLyricsWithAgents() {
        let doc = TTMLDocument(
            language: "en",
            agents: [
                TTMLAgent(id: "narrator", type: "person", name: "DJ Wlad")
            ],
            divisions: [
                TTMLDivision(
                    language: "en",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(3), text: "Hello",
                            agentID: "narrator")
                    ])
            ])

        let lyrics = doc.toSynchronizedLyrics()
        #expect(lyrics[0].lines[0].speaker == "DJ Wlad")
        #expect(lyrics[0].lines[0].hasSpeaker)
    }

    @Test("toSynchronizedLyrics uses agent ID when name is nil")
    func toSynchronizedLyricsAgentMissingName() {
        let doc = TTMLDocument(
            language: "en",
            agents: [
                TTMLAgent(id: "narrator")
            ],
            divisions: [
                TTMLDivision(
                    language: "en",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(3), text: "Hello",
                            agentID: "narrator")
                    ])
            ])

        let lyrics = doc.toSynchronizedLyrics()
        #expect(lyrics[0].lines[0].speaker == "narrator")
    }

    @Test("toSynchronizedLyrics uses raw agentID when agent is undeclared")
    func toSynchronizedLyricsUndeclaredAgent() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    language: "en",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(3), text: "Hello",
                            agentID: "mystery-speaker")
                    ])
            ])

        let lyrics = doc.toSynchronizedLyrics()
        #expect(lyrics[0].lines[0].speaker == "mystery-speaker")
    }

    @Test("toSynchronizedLyrics without agents produces nil speakers")
    func toSynchronizedLyricsNoAgents() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    language: "en",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(3), text: "Hello")
                    ])
            ])

        let lyrics = doc.toSynchronizedLyrics()
        #expect(lyrics[0].lines[0].speaker == nil)
        #expect(!lyrics[0].lines[0].hasSpeaker)
    }

    // MARK: - from() with Speakers

    @Test("from() generates agents from speakers with slugified IDs")
    func fromWithSpeakers() {
        let lyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "Hello", speaker: "DJ Wlad"),
                    LyricLine(
                        time: .seconds(3), text: "World",
                        speaker: "Alice Bob")
                ])
        ]

        let doc = TTMLDocument.from(lyrics)
        #expect(doc.agents.count == 2)
        #expect(doc.agents[0].id == "dj-wlad")
        #expect(doc.agents[0].name == "DJ Wlad")
        #expect(doc.agents[0].type == "person")
        #expect(doc.agents[1].id == "alice-bob")
        #expect(doc.agents[1].name == "Alice Bob")
        #expect(doc.divisions[0].paragraphs[0].agentID == "dj-wlad")
        #expect(doc.divisions[0].paragraphs[1].agentID == "alice-bob")
    }

    @Test("from() without speakers generates no agents")
    func fromWithoutSpeakers() {
        let lyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "Hello")
                ])
        ]

        let doc = TTMLDocument.from(lyrics)
        #expect(doc.agents.isEmpty)
        #expect(doc.divisions[0].paragraphs[0].agentID == nil)
    }

    // MARK: - Round-Trip

    @Test("Round-trip preserves speakers through from() and toSynchronizedLyrics()")
    func roundTripSpeakers() {
        let original = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "Hello", speaker: "Alice"),
                    LyricLine(
                        time: .seconds(3), text: "World", speaker: "Bob"),
                    LyricLine(time: .seconds(6), text: "!", speaker: "Alice")
                ])
        ]

        let doc = TTMLDocument.from(original)
        let result = doc.toSynchronizedLyrics()

        #expect(result[0].lines[0].speaker == "Alice")
        #expect(result[0].lines[1].speaker == "Bob")
        #expect(result[0].lines[2].speaker == "Alice")
    }
}
