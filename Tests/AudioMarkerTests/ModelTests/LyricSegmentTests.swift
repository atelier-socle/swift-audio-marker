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

@Suite("Lyric Segment")
struct LyricSegmentTests {

    // MARK: - Basic Creation

    @Test("Creates segment with required fields")
    func basicCreation() {
        let segment = LyricSegment(
            startTime: .seconds(1),
            endTime: .seconds(2),
            text: "Hello")
        #expect(segment.startTime == .seconds(1))
        #expect(segment.endTime == .seconds(2))
        #expect(segment.text == "Hello")
        #expect(segment.styleID == nil)
    }

    @Test("Creates segment with styleID")
    func withStyleID() {
        let segment = LyricSegment(
            startTime: .zero,
            endTime: .seconds(1),
            text: "Word",
            styleID: "highlight")
        #expect(segment.styleID == "highlight")
    }

    // MARK: - Hashable / Equatable

    @Test("Equal segments are Equatable")
    func equatable() {
        let s1 = LyricSegment(
            startTime: .seconds(1), endTime: .seconds(2), text: "Hi")
        let s2 = LyricSegment(
            startTime: .seconds(1), endTime: .seconds(2), text: "Hi")
        #expect(s1 == s2)
    }

    @Test("Different segments are not equal")
    func notEqual() {
        let s1 = LyricSegment(
            startTime: .seconds(1), endTime: .seconds(2), text: "Hi")
        let s2 = LyricSegment(
            startTime: .seconds(1), endTime: .seconds(2), text: "Bye")
        #expect(s1 != s2)
    }

    @Test("Equal segments produce same hash")
    func hashable() {
        let s1 = LyricSegment(
            startTime: .zero, endTime: .seconds(1), text: "A", styleID: "s1")
        let s2 = LyricSegment(
            startTime: .zero, endTime: .seconds(1), text: "A", styleID: "s1")
        #expect(s1.hashValue == s2.hashValue)
    }

    @Test("Segments with different styleIDs are not equal")
    func styleIDDifference() {
        let s1 = LyricSegment(
            startTime: .zero, endTime: .seconds(1), text: "A", styleID: "s1")
        let s2 = LyricSegment(
            startTime: .zero, endTime: .seconds(1), text: "A", styleID: "s2")
        #expect(s1 != s2)
    }
}
