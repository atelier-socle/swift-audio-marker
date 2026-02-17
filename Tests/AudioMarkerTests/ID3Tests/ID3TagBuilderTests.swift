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

@Suite("ID3 Tag Builder")
struct ID3TagBuilderTests {

    // MARK: - Header Structure

    @Test("Tag starts with ID3 marker bytes")
    func tagMarkerBytes() {
        let builder = ID3TagBuilder(version: .v2_3)
        let data = builder.buildTag(from: AudioFileInfo())
        #expect(data[0] == 0x49)  // 'I'
        #expect(data[1] == 0x44)  // 'D'
        #expect(data[2] == 0x33)  // '3'
    }

    @Test("v2.3 tag has version byte 3")
    func versionByteV23() {
        let builder = ID3TagBuilder(version: .v2_3)
        let data = builder.buildTag(from: AudioFileInfo())
        #expect(data[3] == 3)
        #expect(data[4] == 0)  // Revision
    }

    @Test("v2.4 tag has version byte 4")
    func versionByteV24() {
        let builder = ID3TagBuilder(version: .v2_4)
        let data = builder.buildTag(from: AudioFileInfo())
        #expect(data[3] == 4)
        #expect(data[4] == 0)
    }

    @Test("Tag flags byte is 0x00")
    func flagsByte() {
        let builder = ID3TagBuilder(version: .v2_3)
        let data = builder.buildTag(from: AudioFileInfo())
        #expect(data[5] == 0x00)
    }

    @Test("Tag size is syncsafe encoded")
    func tagSizeSyncsafe() {
        let builder = ID3TagBuilder(version: .v2_3)
        let data = builder.buildTag(from: AudioFileInfo(), padding: 100)
        var reader = BinaryReader(data: Data(data[6..<10]))
        let size = try? reader.readSyncsafeUInt32()
        #expect(size == 100)
    }

    // MARK: - Padding

    @Test("Default padding is 2048 bytes")
    func defaultPadding() {
        let builder = ID3TagBuilder(version: .v2_3)
        let data = builder.buildTag(from: AudioFileInfo())
        #expect(data.count == 10 + 2048)
    }

    @Test("Custom padding value")
    func customPadding() {
        let builder = ID3TagBuilder(version: .v2_3)
        let data = builder.buildTag(from: AudioFileInfo(), padding: 512)
        #expect(data.count == 10 + 512)
    }

    @Test("Zero padding produces minimal tag")
    func zeroPadding() {
        let builder = ID3TagBuilder(version: .v2_3)
        let data = builder.buildTag(from: AudioFileInfo(), padding: 0)
        #expect(data.count == 10)
    }

    // MARK: - Metadata Mapping

    @Test("Title maps to TIT2 frame")
    func titleMapping() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.title = "Test Title"
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(frames.contains(.text(id: "TIT2", text: "Test Title")))
    }

    @Test("Artist maps to TPE1 frame")
    func artistMapping() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.artist = "Test Artist"
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(frames.contains(.text(id: "TPE1", text: "Test Artist")))
    }

    @Test("Year maps to TYER for v2.3 and TDRC for v2.4")
    func yearFrameMapping() throws {
        let v23Builder = ID3TagBuilder(version: .v2_3)
        let v24Builder = ID3TagBuilder(version: .v2_4)
        var info = AudioFileInfo()
        info.metadata.year = 2024

        let v23Data = v23Builder.buildTag(from: info, padding: 0)
        let v23Frames = try parseFrames(from: v23Data, version: .v2_3)
        #expect(v23Frames.contains(.text(id: "TYER", text: "2024")))

        let v24Data = v24Builder.buildTag(from: info, padding: 0)
        let v24Frames = try parseFrames(from: v24Data, version: .v2_4)
        #expect(v24Frames.contains(.text(id: "TDRC", text: "2024")))
    }

    @Test("All core metadata fields produce frames")
    func allCoreFields() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.title = "Title"
        info.metadata.artist = "Artist"
        info.metadata.album = "Album"
        info.metadata.genre = "Rock"
        info.metadata.year = 2024
        info.metadata.trackNumber = 5
        info.metadata.discNumber = 1
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(frames.contains(.text(id: "TIT2", text: "Title")))
        #expect(frames.contains(.text(id: "TPE1", text: "Artist")))
        #expect(frames.contains(.text(id: "TALB", text: "Album")))
        #expect(frames.contains(.text(id: "TCON", text: "Rock")))
        #expect(frames.contains(.text(id: "TYER", text: "2024")))
        #expect(frames.contains(.text(id: "TRCK", text: "5")))
        #expect(frames.contains(.text(id: "TPOS", text: "1")))
    }

    @Test("Professional metadata fields produce frames")
    func professionalFields() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.albumArtist = "Various"
        info.metadata.composer = "Bach"
        info.metadata.publisher = "Label"
        info.metadata.copyright = "2024"
        info.metadata.encoder = "AudioMarker"
        info.metadata.bpm = 120
        info.metadata.key = "Am"
        info.metadata.language = "eng"
        info.metadata.isrc = "USRC12345678"
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(frames.contains(.text(id: "TPE2", text: "Various")))
        #expect(frames.contains(.text(id: "TCOM", text: "Bach")))
        #expect(frames.contains(.text(id: "TPUB", text: "Label")))
        #expect(frames.contains(.text(id: "TCOP", text: "2024")))
        #expect(frames.contains(.text(id: "TENC", text: "AudioMarker")))
        #expect(frames.contains(.text(id: "TBPM", text: "120")))
        #expect(frames.contains(.text(id: "TKEY", text: "Am")))
        #expect(frames.contains(.text(id: "TLAN", text: "eng")))
        #expect(frames.contains(.text(id: "TSRC", text: "USRC12345678")))
    }
}

// MARK: - Chapters & Unknown Frames

extension ID3TagBuilderTests {

    @Test("Chapters produce CTOC + CHAP frames")
    func chapterGeneration() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "Intro", end: .milliseconds(60_000)),
            Chapter(start: .milliseconds(60_000), title: "Main", end: .milliseconds(120_000))
        ])
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)

        let ctocFrames = frames.filter {
            if case .tableOfContents = $0 { return true }
            return false
        }
        #expect(ctocFrames.count == 1)

        let chapFrames = frames.filter {
            if case .chapter = $0 { return true }
            return false
        }
        #expect(chapFrames.count == 2)
    }

    @Test("CTOC references all chapter element IDs")
    func ctocReferencesChapters() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "A"),
            Chapter(start: .milliseconds(30_000), title: "B")
        ])
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)

        guard
            case .tableOfContents(_, let isTopLevel, let isOrdered, let childIDs, _) =
                frames.first(where: {
                    if case .tableOfContents = $0 { return true }
                    return false
                })
        else {
            Issue.record("Expected CTOC frame")
            return
        }
        #expect(isTopLevel)
        #expect(isOrdered)
        #expect(childIDs == ["chp0", "chp1"])
    }

    @Test("Empty chapters produce no chapter frames")
    func emptyChapters() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        let data = builder.buildTag(from: AudioFileInfo(), padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        let chapFrames = frames.filter {
            if case .chapter = $0 { return true }
            if case .tableOfContents = $0 { return true }
            return false
        }
        #expect(chapFrames.isEmpty)
    }

    @Test("Chapter with artwork includes APIC subframe")
    func chapterArtwork() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "Chapter 1",
                end: .milliseconds(60_000),
                artwork: Artwork(data: jpegData, format: .jpeg))
        ])
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        guard
            case .chapter(_, _, _, let subframes) =
                frames.first(where: {
                    if case .chapter = $0 { return true }
                    return false
                })
        else {
            Issue.record("Expected CHAP frame")
            return
        }
        let hasAPIC = subframes.contains {
            if case .attachedPicture = $0 { return true }
            return false
        }
        #expect(hasAPIC)
    }

    @Test("Unknown frames are preserved in output")
    func unknownFramePreservation() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        let unknownData = Data([0x01, 0x02, 0x03])
        let data = builder.buildTag(
            from: AudioFileInfo(),
            unknownFrames: [.unknown(id: "ZZZZ", data: unknownData)],
            padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(frames.contains(.unknown(id: "ZZZZ", data: unknownData)))
    }
}

// MARK: - URLs, Media & Data Frames

extension ID3TagBuilderTests {

    @Test("Custom text fields produce TXXX frames")
    func customTextFields() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.customTextFields["REPLAYGAIN"] = "-6.5 dB"
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(frames.contains(.userDefinedText(description: "REPLAYGAIN", value: "-6.5 dB")))
    }

    @Test("All URL metadata fields produce frames")
    func allURLMetadata() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.artistURL = URL(string: "https://example.com/artist")
        info.metadata.audioSourceURL = URL(string: "https://example.com/source")
        info.metadata.audioFileURL = URL(string: "https://example.com/file")
        info.metadata.publisherURL = URL(string: "https://example.com/pub")
        info.metadata.commercialURL = URL(string: "https://example.com/com")
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(frames.contains(.url(id: "WOAR", url: "https://example.com/artist")))
        #expect(frames.contains(.url(id: "WOAS", url: "https://example.com/source")))
        #expect(frames.contains(.url(id: "WOAF", url: "https://example.com/file")))
        #expect(frames.contains(.url(id: "WPUB", url: "https://example.com/pub")))
        #expect(frames.contains(.url(id: "WCOM", url: "https://example.com/com")))
    }

    @Test("Custom URLs produce WXXX frames")
    func customURLs() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        guard let feedURL = URL(string: "https://example.com/feed") else {
            Issue.record("Invalid URL")
            return
        }
        info.metadata.customURLs["podcast"] = feedURL
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(
            frames.contains(
                .userDefinedURL(description: "podcast", url: "https://example.com/feed")))
    }

    @Test("Artwork produces APIC frame")
    func artworkFrame() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        info.metadata.artwork = Artwork(data: jpegData, format: .jpeg)
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        let hasAPIC = frames.contains {
            if case .attachedPicture(3, "image/jpeg", _, _) = $0 { return true }
            return false
        }
        #expect(hasAPIC)
    }

    @Test("Unsynchronized lyrics produce USLT frame")
    func unsyncLyricsFrame() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.unsynchronizedLyrics = "These are lyrics."
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        let hasUSLT = frames.contains {
            if case .unsyncLyrics(_, _, "These are lyrics.") = $0 { return true }
            return false
        }
        #expect(hasUSLT)
    }

    @Test("Synchronized lyrics produce SYLT frame")
    func syncLyricsFrame() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.synchronizedLyrics = [
            SynchronizedLyrics(
                language: "eng", contentType: .lyrics, descriptor: "",
                lines: [
                    LyricLine(time: .zero, text: "Line one"),
                    LyricLine(time: .milliseconds(5000), text: "Line two")
                ])
        ]
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        let hasSYLT = frames.contains {
            if case .syncLyrics = $0 { return true }
            return false
        }
        #expect(hasSYLT)
    }

    @Test("Private data produces PRIV frames")
    func privateDataFrames() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.privateData = [PrivateData(owner: "com.example", data: Data([0x01]))]
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(frames.contains(.privateData(owner: "com.example", data: Data([0x01]))))
    }

    @Test("Unique file identifiers produce UFID frames")
    func ufidFrames() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.uniqueFileIdentifiers = [
            UniqueFileIdentifier(owner: "http://id3.org", identifier: Data([0xAA]))
        ]
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(
            frames.contains(.uniqueFileID(owner: "http://id3.org", identifier: Data([0xAA]))))
    }

    @Test("Play count produces PCNT frame")
    func playCountFrame() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.playCount = 42
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(frames.contains(.playCounter(count: 42)))
    }

    @Test("Rating produces POPM frame")
    func ratingFrame() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.rating = 196
        let data = builder.buildTag(from: info, padding: 0)
        let frames = try parseFrames(from: data, version: .v2_3)
        #expect(frames.contains(.popularimeter(email: "", rating: 196, playCount: 0)))
    }
}

// MARK: - Round-Trip & Helpers

extension ID3TagBuilderTests {

    @Test("Tag round-trips through reader")
    func tagRoundTrip() throws {
        let builder = ID3TagBuilder(version: .v2_3)
        var info = AudioFileInfo()
        info.metadata.title = "Round Trip"
        info.metadata.artist = "Test Artist"
        info.metadata.album = "Test Album"

        let tagData = builder.buildTag(from: info, padding: 256)

        var fileData = tagData
        fileData.append(Data(repeating: 0xFF, count: 128))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        try fileData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "Round Trip")
        #expect(result.metadata.artist == "Test Artist")
        #expect(result.metadata.album == "Test Album")
    }

    fileprivate func parseFrames(from tagData: Data, version: ID3Version) throws -> [ID3Frame] {
        let header = try ID3Header(data: Data(tagData.prefix(10)))
        let frameData = Data(tagData[10..<(10 + Int(header.tagSize))])
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: version)
        var frames: [ID3Frame] = []
        while reader.hasRemaining {
            guard reader.remainingCount >= 10 else { break }
            guard let frame = try parser.parseFrame(&reader) else { break }
            frames.append(frame)
        }
        return frames
    }
}
