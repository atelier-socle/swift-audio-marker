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

@Suite("ID3 Writer")
struct ID3WriterTests {

    private let fakeAudio = Data(repeating: 0xFF, count: 256)

    // MARK: - Write

    @Test("Writes tag to file without existing tag")
    func writeToFileWithoutTag() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "New Title"
        info.metadata.artist = "New Artist"

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "New Title")
        #expect(result.metadata.artist == "New Artist")
    }

    @Test("Writes tag replacing existing tag")
    func writeReplacesExistingTag() throws {
        let existingTag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Old Title")])
        let url = try createTempFile(tagData: existingTag)
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "New Title"

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "New Title")
    }

    @Test("Audio data preserved after write")
    func audioDataPreservedAfterWrite() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "Test"

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let (header, _) = try reader.readRawFrames(from: url)
        let audioOffset = 10 + Int(header.tagSize)

        let fileData = try Data(contentsOf: url)
        let audioData = Data(fileData[audioOffset...])
        #expect(audioData == fakeAudio)
    }

    // MARK: - In-Place Optimization

    @Test("In-place write when new tag fits in existing space")
    func inPlaceWrite() throws {
        // Create a tag with 4096 bytes of padding to ensure plenty of space
        let existingTag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Old")])
        var paddedTag = existingTag
        paddedTag.append(Data(repeating: 0x00, count: 4096))

        // Manually rebuild with correct size
        let tagBuilder = ID3TagBuilder(version: .v2_3)
        var tempInfo = AudioFileInfo()
        tempInfo.metadata.title = "Old"
        let bigTag = tagBuilder.buildTag(from: tempInfo, padding: 4096)
        let url = try createTempFile(tagData: bigTag)
        defer { cleanup(url) }

        let originalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64

        var info = AudioFileInfo()
        info.metadata.title = "New"

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let newSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64
        // In-place write should keep same file size
        #expect(originalSize == newSize)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "New")
    }

    @Test("Temp file write when new tag is larger than existing space")
    func tempFileWrite() throws {
        // Create a minimal tag (small space)
        let tagBuilder = ID3TagBuilder(version: .v2_3)
        var tempInfo = AudioFileInfo()
        tempInfo.metadata.title = "X"
        let smallTag = tagBuilder.buildTag(from: tempInfo, padding: 0)
        let url = try createTempFile(tagData: smallTag)
        defer { cleanup(url) }

        // Write a much larger tag
        var info = AudioFileInfo()
        info.metadata.title = String(repeating: "A", count: 500)
        info.metadata.artist = String(repeating: "B", count: 500)

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == String(repeating: "A", count: 500))
        #expect(result.metadata.artist == String(repeating: "B", count: 500))
    }

    // MARK: - Modify

    @Test("Modify preserves unknown frames")
    func modifyPreservesUnknownFrames() throws {
        let unknownContent = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let existingTag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TIT2", text: "Old Title"),
                ID3TestHelper.buildRawFrame(id: "ZZZZ", content: unknownContent)
            ])
        let url = try createTempFile(tagData: existingTag)
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "New Title"

        let writer = ID3Writer()
        try writer.modify(info, in: url)

        let reader = ID3Reader()
        let (_, frames) = try reader.readRawFrames(from: url)
        let unknownFrames = frames.filter {
            if case .unknown = $0 { return true }
            return false
        }
        #expect(unknownFrames.count == 1)
        #expect(unknownFrames.first == .unknown(id: "ZZZZ", data: unknownContent))

        let result = try reader.read(from: url)
        #expect(result.metadata.title == "New Title")
    }

    @Test("Modify in-place when new tag fits in existing space")
    func modifyInPlace() throws {
        // Create a file with a large tag (lots of padding)
        let tagBuilder = ID3TagBuilder(version: .v2_3)
        var tempInfo = AudioFileInfo()
        tempInfo.metadata.title = "Old"
        let bigTag = tagBuilder.buildTag(from: tempInfo, padding: 4096)
        let url = try createTempFile(tagData: bigTag)
        defer { cleanup(url) }

        let originalSize =
            try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64

        var info = AudioFileInfo()
        info.metadata.title = "New"

        let writer = ID3Writer()
        try writer.modify(info, in: url)

        let newSize =
            try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64
        // In-place write keeps same file size
        #expect(originalSize == newSize)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "New")
    }

    @Test("Modify uses existing tag version when none specified")
    func modifyUsesExistingVersion() throws {
        let tagBuilder = ID3TagBuilder(version: .v2_4)
        var tempInfo = AudioFileInfo()
        tempInfo.metadata.title = "Old"
        let v24Tag = tagBuilder.buildTag(from: tempInfo, padding: 256)
        let url = try createTempFile(tagData: v24Tag)
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "Updated"

        let writer = ID3Writer()
        try writer.modify(info, in: url)

        let reader = ID3Reader()
        let (header, _) = try reader.readRawFrames(from: url)
        #expect(header.version == .v2_4)
    }

    @Test("Modify on file without tag behaves like write")
    func modifyWithoutExistingTag() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "Created"

        let writer = ID3Writer()
        try writer.modify(info, in: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "Created")
    }

    // MARK: - Strip Tag

    @Test("Strips tag from file with existing tag")
    func stripExistingTag() throws {
        let existingTag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Title")])
        let url = try createTempFile(tagData: existingTag)
        defer { cleanup(url) }

        let writer = ID3Writer()
        try writer.stripTag(from: url)

        let fileData = try Data(contentsOf: url)
        // File should only contain audio data
        #expect(fileData == fakeAudio)
    }

    @Test("Strip preserves chapters with original titles")
    func stripPreservesChapters() throws {
        let existingTag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TIT2", text: "Song Title"),
                ID3TestHelper.buildTextFrame(id: "TPE1", text: "Artist Name"),
                ID3TestHelper.buildCHAPFrame(
                    elementID: "chp0", startTime: 0, endTime: 30_000,
                    subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Intro")]),
                ID3TestHelper.buildCHAPFrame(
                    elementID: "chp1", startTime: 30_000, endTime: 60_000,
                    subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Main Topic")])
            ])
        let url = try createTempFile(tagData: existingTag)
        defer { cleanup(url) }

        let readerID3 = ID3Reader()
        let before = try readerID3.read(from: url)
        #expect(before.metadata.title == "Song Title")
        #expect(before.chapters.count == 2)

        let writer = ID3Writer()
        try writer.stripTag(from: url)

        let after = try readerID3.read(from: url)

        // Metadata must be gone.
        #expect(after.metadata.title == nil)
        #expect(after.metadata.artist == nil)

        // Chapters must be intact with original titles.
        #expect(after.chapters.count == 2)
        #expect(after.chapters[0].title == "Intro")
        #expect(after.chapters[1].title == "Main Topic")
    }

    @Test("Strip on file without tag is no-op")
    func stripNoTag() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        let originalData = try Data(contentsOf: url)

        let writer = ID3Writer()
        try writer.stripTag(from: url)

        let afterData = try Data(contentsOf: url)
        #expect(originalData == afterData)
    }

    // MARK: - Round-Trip

    @Test("Full round-trip: write then read matches AudioFileInfo")
    func fullRoundTrip() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "Podcast Episode"
        info.metadata.artist = "Host"
        info.metadata.album = "Podcast Name"
        info.metadata.genre = "Podcast"
        info.metadata.year = 2024
        info.metadata.trackNumber = 42
        info.metadata.comment = "A great episode"
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "Intro",
                end: .milliseconds(60_000)),
            Chapter(
                start: .milliseconds(60_000), title: "Main",
                end: .milliseconds(300_000)),
            Chapter(
                start: .milliseconds(300_000), title: "Outro",
                end: .milliseconds(360_000))
        ])

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "Podcast Episode")
        #expect(result.metadata.artist == "Host")
        #expect(result.metadata.album == "Podcast Name")
        #expect(result.metadata.genre == "Podcast")
        #expect(result.metadata.year == 2024)
        #expect(result.metadata.trackNumber == 42)
        #expect(result.metadata.comment == "A great episode")
        #expect(result.chapters.count == 3)
    }

    @Test("Round-trip preserves chapter details")
    func roundTripChapterDetails() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "Chapter 1",
                end: .milliseconds(30_000),
                url: URL(string: "https://example.com/ch1")),
            Chapter(
                start: .milliseconds(30_000), title: "Chapter 2",
                end: .milliseconds(60_000))
        ])

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.chapters.count == 2)
        #expect(result.chapters[0].title == "Chapter 1")
        #expect(result.chapters[1].title == "Chapter 2")
        #expect(result.chapters[0].url?.absoluteString == "https://example.com/ch1")
    }

    // MARK: - Helpers

    func createTempFile(tagData: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        var fileData = tagData
        fileData.append(fakeAudio)
        try fileData.write(to: url)
        return url
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - CHAP End Time

extension ID3WriterTests {

    @Test("CHAP endTime uses next chapter start when end is nil")
    func chapEndTimeFromNextChapter() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "First"),
            Chapter(start: .milliseconds(30_000), title: "Second"),
            Chapter(start: .milliseconds(60_000), title: "Third")
        ])

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let (_, frames) = try reader.readRawFrames(from: url)
        let chapFrames = frames.filter { $0.frameID == "CHAP" }
        #expect(chapFrames.count == 3)

        // Verify endTime of first chapter equals startTime of second.
        guard case .chapter(_, let startTime0, let endTime0, _) = chapFrames[0] else {
            Issue.record("Expected CHAP frame")
            return
        }
        #expect(startTime0 == 0)
        #expect(endTime0 == 30_000)

        // Verify endTime of second chapter equals startTime of third.
        guard case .chapter(_, let startTime1, let endTime1, _) = chapFrames[1] else {
            Issue.record("Expected CHAP frame")
            return
        }
        #expect(startTime1 == 30_000)
        #expect(endTime1 == 60_000)

        // Verify endTime of last chapter is startTime + 1.
        guard case .chapter(_, let startTime2, let endTime2, _) = chapFrames[2] else {
            Issue.record("Expected CHAP frame")
            return
        }
        #expect(startTime2 == 60_000)
        #expect(endTime2 == 60_001)
    }

    @Test("CHAP endTime uses explicit end when provided")
    func chapEndTimeExplicit() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "First",
                end: .milliseconds(25_000)),
            Chapter(
                start: .milliseconds(30_000), title: "Second",
                end: .milliseconds(55_000))
        ])

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let (_, frames) = try reader.readRawFrames(from: url)
        let chapFrames = frames.filter { $0.frameID == "CHAP" }
        #expect(chapFrames.count == 2)

        guard case .chapter(_, _, let endTime0, _) = chapFrames[0] else {
            Issue.record("Expected CHAP frame")
            return
        }
        #expect(endTime0 == 25_000)

        guard case .chapter(_, _, let endTime1, _) = chapFrames[1] else {
            Issue.record("Expected CHAP frame")
            return
        }
        #expect(endTime1 == 55_000)
    }
}

// MARK: - APIC Picture Type

extension ID3WriterTests {

    @Test("Written artwork has front cover picture type (0x03)")
    func writeArtworkHasFrontCoverPictureType() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0xAB), count: 50))
        var info = AudioFileInfo()
        info.metadata.artwork = Artwork(data: imageData, format: .jpeg)

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let (_, frames) = try reader.readRawFrames(from: url)
        let apicFrames = frames.filter { $0.frameID == "APIC" }
        #expect(apicFrames.count == 1)

        guard case .attachedPicture(let pictureType, let mimeType, _, let data) = apicFrames.first
        else {
            Issue.record("Expected APIC frame")
            return
        }
        #expect(pictureType == 3)
        #expect(mimeType == "image/jpeg")
        #expect(data == imageData)
    }

    @Test("APIC frame binary contains correct picture type byte")
    func apicFrameBinaryPictureType() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        let builder = ID3FrameBuilder(version: .v2_3)
        let frameData = builder.buildFrame(
            .attachedPicture(
                pictureType: 3, mimeType: "image/jpeg",
                description: "", data: imageData))

        // Frame layout: ID(4) + Size(4) + Flags(2) + Encoding(1) + MIME+null + PictureType(1) + ...
        // Find picture type byte: skip header (10), encoding (1), "image/jpeg\0" (11 bytes)
        let pictureTypeOffset = 10 + 1 + "image/jpeg".count + 1
        #expect(frameData[pictureTypeOffset] == 0x03)
    }

    @Test("Round-trip chapter URL and artwork")
    func roundTripChapterURLAndArtwork() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0xAB), count: 50))
        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "With URL and Art",
                end: .milliseconds(30_000),
                url: URL(string: "https://example.com/ch1"),
                artwork: Artwork(data: imageData, format: .jpeg)),
            Chapter(
                start: .milliseconds(30_000), title: "URL Only",
                end: .milliseconds(60_000),
                url: URL(string: "https://example.com/ch2"))
        ])

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.chapters.count == 2)
        #expect(result.chapters[0].url?.absoluteString == "https://example.com/ch1")
        #expect(result.chapters[0].artwork != nil)
        #expect(result.chapters[0].artwork?.format == .jpeg)
        #expect(result.chapters[1].url?.absoluteString == "https://example.com/ch2")
        #expect(result.chapters[1].artwork == nil)
    }

    @Test("Round-trip chapter with WXXX URL subframe")
    func roundTripChapterWXXXUrl() throws {
        // Build a CHAP frame with a WXXX subframe (instead of WOAR)
        let wxxxSubframe = ID3TestHelper.buildWXXXFrame(
            description: "chapter url", url: "https://example.com/wxxx")
        let titleSubframe = ID3TestHelper.buildTextFrame(id: "TIT2", text: "WXXX Chapter")
        let chapFrame = ID3TestHelper.buildCHAPFrame(
            elementID: "chp0", startTime: 0, endTime: 30_000,
            subframes: [titleSubframe, wxxxSubframe])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [chapFrame])
        let url = try createTempFile(tagData: tag)
        defer { cleanup(url) }

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.chapters.count == 1)
        #expect(result.chapters[0].title == "WXXX Chapter")
        #expect(result.chapters[0].url?.absoluteString == "https://example.com/wxxx")
    }

    @Test("Read APIC preserves custom picture type through round-trip")
    func readAPICPreservesPictureType() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0xCC), count: 20))
        let apicFrame = ID3TestHelper.buildAPICFrame(
            mimeType: "image/jpeg", pictureType: 5,
            description: "", imageData: imageData)
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [apicFrame])
        let url = try createTempFile(tagData: tag)
        defer { cleanup(url) }

        let reader = ID3Reader()
        let (_, frames) = try reader.readRawFrames(from: url)
        let apicFrames = frames.filter { $0.frameID == "APIC" }
        #expect(apicFrames.count == 1)

        guard case .attachedPicture(let pictureType, _, _, _) = apicFrames.first else {
            Issue.record("Expected APIC frame")
            return
        }
        #expect(pictureType == 5)
    }
}
