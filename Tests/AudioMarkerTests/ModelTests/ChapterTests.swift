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

@Suite("Chapter")
struct ChapterTests {

    // MARK: - Basic creation

    @Test("Creates with required fields only")
    func basicCreation() {
        let chapter = Chapter(start: .seconds(10), title: "Introduction")
        #expect(chapter.title == "Introduction")
        #expect(chapter.start == AudioTimestamp.seconds(10))
        #expect(chapter.end == nil)
        #expect(chapter.url == nil)
        #expect(chapter.artwork == nil)
    }

    @Test("Creates with all optional fields")
    func fullCreation() {
        let artwork = Artwork(data: Data([0xFF, 0xD8, 0xFF]), format: .jpeg)
        let chapterURL = URL(string: "https://example.com")
        let chapter = Chapter(
            start: .seconds(0),
            title: "Prologue",
            end: .seconds(60),
            url: chapterURL,
            artwork: artwork
        )
        #expect(chapter.title == "Prologue")
        #expect(chapter.start == .zero)
        #expect(chapter.end == .seconds(60))
        #expect(chapter.url == chapterURL)
        #expect(chapter.artwork == artwork)
    }

    // MARK: - ID generation

    @Test("Generates unique IDs")
    func uniqueIDs() {
        let a = Chapter(start: .zero, title: "A")
        let b = Chapter(start: .zero, title: "A")
        #expect(a.id != b.id)
    }

    // MARK: - Hashable and Equatable

    @Test("Same chapter has consistent id")
    func identifiable() {
        let chapter = Chapter(start: .seconds(10), title: "Test")
        #expect(chapter.id == chapter.id)
    }

    @Test("Different chapters are not equal")
    func notEqual() {
        let a = Chapter(start: .zero, title: "A")
        let b = Chapter(start: .zero, title: "A")
        #expect(a != b)
    }
}
