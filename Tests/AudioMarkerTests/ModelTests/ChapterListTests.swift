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

@Suite("ChapterList")
struct ChapterListTests {

    // MARK: - Initialization

    @Test("Creates empty by default")
    func emptyInit() {
        let list = ChapterList()
        #expect(list.count == 0)
        #expect(list.isEmpty)
    }

    @Test("Creates from array of chapters")
    func initFromArray() {
        let chapters = [
            Chapter(start: .seconds(0), title: "First"),
            Chapter(start: .seconds(60), title: "Second")
        ]
        let list = ChapterList(chapters)
        #expect(list.count == 2)
    }

    // MARK: - Mutation

    @Test("Append adds chapter at end")
    func append() {
        var list = ChapterList()
        list.append(Chapter(start: .zero, title: "First"))
        list.append(Chapter(start: .seconds(30), title: "Second"))
        #expect(list.count == 2)
        #expect(list[1].title == "Second")
    }

    @Test("Insert adds chapter at position")
    func insert() {
        var list = ChapterList([
            Chapter(start: .zero, title: "First"),
            Chapter(start: .seconds(60), title: "Third")
        ])
        list.insert(Chapter(start: .seconds(30), title: "Second"), at: 1)
        #expect(list.count == 3)
        #expect(list[1].title == "Second")
    }

    @Test("Remove removes chapter at position")
    func remove() {
        var list = ChapterList([
            Chapter(start: .zero, title: "First"),
            Chapter(start: .seconds(30), title: "Second"),
            Chapter(start: .seconds(60), title: "Third")
        ])
        let removed = list.remove(at: 1)
        #expect(removed.title == "Second")
        #expect(list.count == 2)
        #expect(list[1].title == "Third")
    }

    // MARK: - Sort

    @Test("Sort orders by start time")
    func sortByStartTime() {
        var list = ChapterList([
            Chapter(start: .seconds(60), title: "Third"),
            Chapter(start: .seconds(0), title: "First"),
            Chapter(start: .seconds(30), title: "Second")
        ])
        list.sort()
        #expect(list[0].title == "First")
        #expect(list[1].title == "Second")
        #expect(list[2].title == "Third")
    }

    // MARK: - Calculated end times

    @Test("withCalculatedEndTimes fills in end times from next chapter start")
    func calculatedEndTimes() {
        let list = ChapterList([
            Chapter(start: .seconds(0), title: "First"),
            Chapter(start: .seconds(30), title: "Second"),
            Chapter(start: .seconds(60), title: "Third")
        ])
        let result = list.withCalculatedEndTimes(audioDuration: .seconds(90))
        #expect(result[0].end == .seconds(30))
        #expect(result[1].end == .seconds(60))
        #expect(result[2].end == .seconds(90))
    }

    @Test("withCalculatedEndTimes sets last chapter end to audio duration")
    func lastChapterEndTime() {
        let list = ChapterList([
            Chapter(start: .seconds(0), title: "Only")
        ])
        let result = list.withCalculatedEndTimes(audioDuration: .seconds(300))
        #expect(result[0].end == .seconds(300))
    }

    @Test("withCalculatedEndTimes handles empty list")
    func calculatedEndTimesEmpty() {
        let list = ChapterList()
        let result = list.withCalculatedEndTimes(audioDuration: .seconds(90))
        #expect(result.isEmpty)
    }

    // MARK: - RandomAccessCollection conformance

    @Test("Supports subscript access")
    func subscriptAccess() {
        let list = ChapterList([
            Chapter(start: .zero, title: "First"),
            Chapter(start: .seconds(30), title: "Second")
        ])
        #expect(list[0].title == "First")
        #expect(list[1].title == "Second")
    }

    @Test("Supports iteration")
    func iteration() {
        let list = ChapterList([
            Chapter(start: .zero, title: "A"),
            Chapter(start: .seconds(10), title: "B"),
            Chapter(start: .seconds(20), title: "C")
        ])
        let titles = list.map(\.title)
        #expect(titles == ["A", "B", "C"])
    }

    @Test("startIndex and endIndex are correct")
    func indices() {
        let list = ChapterList([
            Chapter(start: .zero, title: "A"),
            Chapter(start: .seconds(10), title: "B")
        ])
        #expect(list.startIndex == 0)
        #expect(list.endIndex == 2)
    }
}
