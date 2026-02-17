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

/// Demonstrates all model types: timestamps, artwork, chapters, metadata, lyrics, and file info.
@Suite("Showcase: Model Types")
struct ModelShowcaseTests {

    // MARK: - AudioTimestamp

    @Test("Timestamp — creation, formatting, and comparison")
    func timestampShowcase() throws {
        // Factory methods
        let zero = AudioTimestamp.zero
        let fromSeconds = AudioTimestamp.seconds(90.5)
        let fromMillis = AudioTimestamp.milliseconds(5250)

        #expect(zero.timeInterval == 0)
        #expect(fromSeconds.timeInterval == 90.5)
        #expect(fromMillis.timeInterval == 5.25)

        // String parsing — HH:MM:SS format
        let parsed1 = try AudioTimestamp(string: "01:30:00")
        #expect(parsed1.timeInterval == 5400.0)

        // String parsing — MM:SS.mmm format
        let parsed2 = try AudioTimestamp(string: "05:30.250")
        #expect(parsed2.timeInterval == 330.25)

        // Formatting — description always shows HH:MM:SS.mmm
        #expect(fromSeconds.description == "00:01:30.500")

        // Formatting — shortDescription omits milliseconds when zero
        let wholeSecond = AudioTimestamp.seconds(60)
        #expect(wholeSecond.shortDescription == "00:01:00")
        #expect(fromSeconds.shortDescription == "00:01:30.500")

        // Comparable — sort timestamps
        let timestamps = [fromSeconds, zero, fromMillis, parsed1]
        let sorted = timestamps.sorted()
        #expect(sorted[0] == zero)
        #expect(sorted[1] == fromMillis)
        #expect(sorted[2] == fromSeconds)
        #expect(sorted[3] == parsed1)

        // Error handling — invalid format
        #expect(throws: AudioTimestampError.self) {
            try AudioTimestamp(string: "not-a-timestamp")
        }
    }

    // MARK: - Artwork

    @Test("Artwork — creation and format detection")
    func artworkShowcase() throws {
        // JPEG magic bytes: FF D8 FF
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 64)
        #expect(ArtworkFormat.detect(from: jpegData) == .jpeg)

        // PNG magic bytes: 89 50 4E 47
        let pngData = Data([0x89, 0x50, 0x4E, 0x47]) + Data(repeating: 0x00, count: 64)
        #expect(ArtworkFormat.detect(from: pngData) == .png)

        // Explicit init — format provided
        let explicit = Artwork(data: jpegData, format: .jpeg)
        #expect(explicit.format == .jpeg)
        #expect(explicit.data.count == 68)

        // Auto-detection init — format inferred from magic bytes
        let autoDetected = try Artwork(data: pngData)
        #expect(autoDetected.format == .png)

        // MIME types
        #expect(ArtworkFormat.jpeg.mimeType == "image/jpeg")
        #expect(ArtworkFormat.png.mimeType == "image/png")

        // Unrecognized format throws
        #expect(throws: ArtworkError.unrecognizedFormat) {
            try Artwork(data: Data([0x00, 0x01, 0x02, 0x03, 0x04]))
        }
    }

    // MARK: - Chapter and ChapterList

    @Test("Chapter and ChapterList — building a chapter timeline")
    func chapterListShowcase() throws {
        // Build 5 chapters with various properties
        let chapters = [
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .seconds(30), title: "Hook"),
            Chapter(
                start: .seconds(90), title: "Verse 1",
                url: URL(string: "https://example.com/verse1")),
            Chapter(start: .seconds(180), title: "Chorus"),
            Chapter(
                start: .seconds(270), title: "Outro",
                artwork: Artwork(
                    data: Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0, count: 32),
                    format: .jpeg))
        ]

        // ChapterList operations: init, count, subscript, iteration
        var list = ChapterList(chapters)
        #expect(list.count == 5)
        #expect(list[0].title == "Intro")
        #expect(list[4].title == "Outro")

        // Append
        list.append(Chapter(start: .seconds(350), title: "Bonus"))
        #expect(list.count == 6)

        // Sort
        var unsorted = ChapterList([
            Chapter(start: .seconds(60), title: "Second"),
            Chapter(start: .zero, title: "First")
        ])
        unsorted.sort()
        #expect(unsorted[0].title == "First")
        #expect(unsorted[1].title == "Second")

        // withCalculatedEndTimes fills in end times
        let audioDuration = AudioTimestamp.seconds(400)
        let withEnds = list.withCalculatedEndTimes(audioDuration: audioDuration)
        #expect(withEnds[0].end == withEnds[1].start)
        #expect(withEnds[withEnds.count - 1].end == audioDuration)

        // Identifiable — each chapter has a unique UUID
        let ch1 = Chapter(start: .zero, title: "A")
        let ch2 = Chapter(start: .zero, title: "A")
        #expect(ch1.id != ch2.id)

        // Hashable — two chapters with different IDs are not equal
        #expect(ch1 != ch2)
    }

    // MARK: - AudioMetadata

    @Test("AudioMetadata — comprehensive metadata")
    func metadataShowcase() throws {
        // Minimal init
        var meta = AudioMetadata(title: "My Song", artist: "Artist", album: "Album")
        #expect(meta.title == "My Song")
        #expect(meta.artist == "Artist")
        #expect(meta.album == "Album")

        // Core fields
        meta.genre = "Rock"
        meta.year = 2025
        meta.trackNumber = 3
        meta.discNumber = 1

        // Professional fields
        meta.composer = "Composer Name"
        meta.albumArtist = "Various Artists"
        meta.publisher = "Label Records"
        meta.copyright = "2025 Label Records"
        meta.encoder = "AudioMarker v0.1.0"
        meta.comment = "Mastered at Studio X"
        meta.bpm = 120
        meta.key = "Am"
        meta.language = "eng"
        meta.isrc = "USRC17607839"

        // URLs
        meta.artistURL = URL(string: "https://example.com/artist")
        meta.audioSourceURL = URL(string: "https://example.com/source")
        meta.audioFileURL = URL(string: "https://example.com/file")
        meta.publisherURL = URL(string: "https://example.com/publisher")
        meta.commercialURL = URL(string: "https://example.com/buy")
        let portfolioURL = try #require(URL(string: "https://example.com"))
        meta.customURLs = ["portfolio": portfolioURL]

        // Custom data
        meta.customTextFields = ["MOOD": "Energetic"]
        meta.privateData = [PrivateData(owner: "com.test", data: Data([0x01]))]
        meta.uniqueFileIdentifiers = [
            UniqueFileIdentifier(owner: "http://id3.org", identifier: Data("abc".utf8))
        ]

        // Statistics
        meta.playCount = 42
        meta.rating = 200

        // Verify everything was stored
        #expect(meta.genre == "Rock")
        #expect(meta.bpm == 120)
        #expect(meta.customTextFields["MOOD"] == "Energetic")
        #expect(meta.privateData.count == 1)
        #expect(meta.uniqueFileIdentifiers.count == 1)
        #expect(meta.rating == 200)
        #expect(meta.customURLs.count == 1)
    }

    // MARK: - SynchronizedLyrics

    @Test("SynchronizedLyrics and LyricLine — timestamped text")
    func syncLyricsShowcase() {
        // Create lyric lines
        let lines = [
            LyricLine(time: .milliseconds(500), text: "Hello"),
            LyricLine(time: .zero, text: "Intro"),
            LyricLine(time: .seconds(5), text: "World")
        ]

        // Build SynchronizedLyrics
        let lyrics = SynchronizedLyrics(
            language: "eng",
            contentType: .lyrics,
            descriptor: "Main vocals",
            lines: lines
        )
        #expect(lyrics.language == "eng")
        #expect(lyrics.contentType == .lyrics)
        #expect(lyrics.descriptor == "Main vocals")
        #expect(lyrics.lines.count == 3)

        // sorted() returns lines ordered by time
        let sorted = lyrics.sorted()
        #expect(sorted.lines[0].text == "Intro")
        #expect(sorted.lines[1].text == "Hello")
        #expect(sorted.lines[2].text == "World")

        // ContentType — all cases
        let allTypes: [ContentType] = [
            .other, .lyrics, .textTranscription, .movementOrPartName,
            .events, .chord, .trivia, .webpageURLs, .imageURLs
        ]
        #expect(allTypes.count == ContentType.allCases.count)
    }

    // MARK: - AudioFileInfo

    @Test("AudioFileInfo — complete file representation")
    func audioFileInfoShowcase() {
        // Default init — empty
        let empty = AudioFileInfo()
        #expect(empty.metadata.title == nil)
        #expect(empty.chapters.isEmpty)
        #expect(empty.duration == nil)

        // Full init
        let info = AudioFileInfo(
            metadata: AudioMetadata(title: "Title"),
            chapters: ChapterList([Chapter(start: .zero, title: "Ch1")]),
            duration: .seconds(300)
        )
        #expect(info.metadata.title == "Title")
        #expect(info.chapters.count == 1)
        #expect(info.duration?.timeInterval == 300)
    }
}
