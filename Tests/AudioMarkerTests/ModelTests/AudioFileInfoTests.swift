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

@Suite("AudioFileInfo")
struct AudioFileInfoTests {

    // MARK: - Default init

    @Test("Default init has empty metadata and chapters")
    func defaultInit() {
        let info = AudioFileInfo()
        #expect(info.metadata.title == nil)
        #expect(info.chapters.isEmpty)
        #expect(info.duration == nil)
    }

    // MARK: - Populated init

    @Test("Init with populated data")
    func populatedInit() {
        let metadata = AudioMetadata(title: "Test", artist: "Artist")
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .seconds(60), title: "Main")
        ])
        let duration = AudioTimestamp.seconds(120)

        let info = AudioFileInfo(
            metadata: metadata,
            chapters: chapters,
            duration: duration
        )

        #expect(info.metadata.title == "Test")
        #expect(info.metadata.artist == "Artist")
        #expect(info.chapters.count == 2)
        #expect(info.duration == duration)
    }

    // MARK: - Mutability

    @Test("Fields are mutable")
    func mutability() {
        var info = AudioFileInfo()
        info.metadata.title = "Updated"
        info.duration = .seconds(300)

        #expect(info.metadata.title == "Updated")
        #expect(info.duration == .seconds(300))
    }
}
