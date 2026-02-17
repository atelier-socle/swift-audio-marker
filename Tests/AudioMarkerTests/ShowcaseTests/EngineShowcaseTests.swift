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

/// Demonstrates the AudioMarkerEngine facade: format detection, full MP3/M4A workflows, and config.
@Suite("Showcase: AudioMarkerEngine")
struct EngineShowcaseTests {

    // MARK: - Format Detection

    @Test("Engine — detect audio format")
    func detectFormat() throws {
        // From file extension
        #expect(AudioFormat.detect(fromExtension: "mp3") == .mp3)
        #expect(AudioFormat.detect(fromExtension: "m4a") == .m4a)
        #expect(AudioFormat.detect(fromExtension: "m4b") == .m4b)
        #expect(AudioFormat.detect(fromExtension: "wav") == nil)

        // From magic bytes — MP3 with ID3 header
        let id3Bytes = Data([0x49, 0x44, 0x33, 0x03, 0x00])
        #expect(AudioFormat.detect(fromMagicBytes: id3Bytes) == .mp3)

        // From magic bytes — MP3 sync word
        let syncWord = Data([0xFF, 0xE0, 0x00])
        #expect(AudioFormat.detect(fromMagicBytes: syncWord) == .mp3)

        // From magic bytes — MP4 ftyp box
        var mp4Data = Data(repeating: 0, count: 4)
        mp4Data[0] = 0x00
        mp4Data[1] = 0x00
        mp4Data[2] = 0x00
        mp4Data[3] = 0x10
        mp4Data.append(contentsOf: "ftypM4A ".utf8)
        mp4Data.append(Data(repeating: 0, count: 4))
        #expect(AudioFormat.detect(fromMagicBytes: mp4Data) == .m4a)

        // Properties
        #expect(AudioFormat.mp3.usesID3)
        #expect(!AudioFormat.mp3.usesMP4)
        #expect(AudioFormat.m4a.usesMP4)
        #expect(!AudioFormat.m4a.usesID3)
        #expect(AudioFormat.mp3.fileExtensions == ["mp3"])
    }

    // MARK: - Complete MP3 Workflow

    @Test("Engine — complete MP3 workflow")
    func mp3Workflow() throws {
        let engine = AudioMarkerEngine()

        // 1. Create a synthetic MP3
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Initial")])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // 2. Read
        var info = try engine.read(from: url)
        #expect(info.metadata.title == "Initial")

        // 3. Modify metadata
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 32)
        info.metadata.title = "Updated Song"
        info.metadata.artist = "New Artist"
        info.metadata.album = "New Album"
        info.metadata.year = 2025
        info.metadata.genre = "Indie"
        info.metadata.artwork = Artwork(data: jpegData, format: .jpeg)

        // 4. Add chapters
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .seconds(30), title: "Verse"),
            Chapter(start: .seconds(90), title: "Chorus")
        ])

        // 5. Add synchronized lyrics
        info.metadata.synchronizedLyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "Starting..."),
                    LyricLine(time: .seconds(5), text: "Singing now")
                ])
        ]

        // 6. Write
        try engine.write(info, to: url)

        // 7. Read back and verify
        let verified = try engine.read(from: url)
        #expect(verified.metadata.title == "Updated Song")
        #expect(verified.metadata.artist == "New Artist")
        #expect(verified.metadata.year == 2025)
        #expect(verified.metadata.artwork?.format == .jpeg)
        #expect(verified.chapters.count == 3)
        #expect(!verified.metadata.synchronizedLyrics.isEmpty)

        // 8. Export chapters
        let exported = try engine.exportChapters(from: url, format: .podloveJSON)
        #expect(exported.contains("Intro"))
        #expect(exported.contains("Verse"))

        // 9. Strip removes metadata but preserves chapters
        try engine.strip(from: url)

        // 10. Metadata is gone, chapters are intact
        let stripped = try engine.read(from: url)
        #expect(stripped.metadata.title == nil)
        #expect(stripped.metadata.artist == nil)
        #expect(stripped.metadata.artwork == nil)
        #expect(stripped.chapters.count == 3)
        #expect(stripped.chapters[0].title == "Intro")
    }

    // MARK: - Complete M4A Workflow

    @Test("Engine — complete M4A workflow")
    func m4aWorkflow() throws {
        let engine = AudioMarkerEngine()

        // 1. Create a synthetic M4A (with mdat atom required for write/strip)
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd])
        let mdat = MP4TestHelper.buildAtom(type: "mdat", data: Data(repeating: 0xFF, count: 128))
        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moov)
        fileData.append(mdat)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        // 2. Read
        var info = try engine.read(from: url)

        // 3. Add metadata
        info.metadata.title = "M4A Song"
        info.metadata.artist = "M4A Artist"

        // 4. Write
        try engine.write(info, to: url)

        // 5. Read back
        let verified = try engine.read(from: url)
        #expect(verified.metadata.title == "M4A Song")
        #expect(verified.metadata.artist == "M4A Artist")

        // 6. Strip
        try engine.strip(from: url)
        let stripped = try engine.read(from: url)
        #expect(stripped.metadata.title == nil)
    }

    // MARK: - Chapter Import/Export

    @Test("Engine — chapter import/export through engine")
    func chapterImportExport() throws {
        let engine = AudioMarkerEngine()

        // Create a bare MP3
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Import chapters from a Podlove JSON string
        let json = """
            {
              "version": "1.2",
              "chapters": [
                { "start": "00:00:00.000", "title": "Opening" },
                { "start": "00:01:00.000", "title": "Middle" },
                { "start": "00:05:00.000", "title": "End" }
              ]
            }
            """
        try engine.importChapters(from: json, format: .podloveJSON, to: url)

        // Read chapters back via engine
        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Opening")

        // Export chapters via engine
        let exported = try engine.exportChapters(from: url, format: .podloveJSON)
        #expect(exported.contains("Opening"))
        #expect(exported.contains("Middle"))

        // Write chapters directly
        let newChapters = ChapterList([Chapter(start: .zero, title: "Solo")])
        try engine.writeChapters(newChapters, to: url)
        let reread = try engine.readChapters(from: url)
        #expect(reread.count == 1)
        #expect(reread[0].title == "Solo")
    }

    // MARK: - Configuration

    @Test("Engine — configuration options")
    func configurationShowcase() {
        // Default configuration
        let defaultConfig = Configuration.default
        #expect(defaultConfig.id3Version == .v2_3)
        #expect(defaultConfig.validateBeforeWriting)
        #expect(defaultConfig.preserveUnknownData)
        #expect(defaultConfig.id3PaddingSize == 2048)

        // Custom configuration
        let custom = Configuration(
            id3Version: .v2_4,
            validateBeforeWriting: false,
            preserveUnknownData: false,
            id3PaddingSize: 4096
        )
        #expect(custom.id3Version == .v2_4)
        #expect(!custom.validateBeforeWriting)
        #expect(!custom.preserveUnknownData)
        #expect(custom.id3PaddingSize == 4096)

        // Pass config to engine
        let engine = AudioMarkerEngine(configuration: custom)
        #expect(engine.configuration.id3Version == .v2_4)
    }
}
