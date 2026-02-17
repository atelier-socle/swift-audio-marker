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
@testable import AudioMarkerCommands

/// Demonstrates the CLI write command: metadata fields, artwork, lyrics, and preservation.
@Suite("Showcase: CLI Write")
struct CLIWriteShowcaseTests {

    let engine = AudioMarkerEngine()

    // MARK: - All Metadata Fields

    @Test("audiomarker write — set all metadata fields")
    func writeAllFields() throws {
        let url = try CLITestHelper.createMP3(title: "Before")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Write.parse([
            url.path,
            "--title", "New Title",
            "--artist", "New Artist",
            "--album", "New Album",
            "--year", "2025",
            "--genre", "Rock",
            "--track-number", "3",
            "--disc-number", "1",
            "--composer", "Composer",
            "--album-artist", "VA",
            "--comment", "Great track",
            "--bpm", "128"
        ])
        try cmd.run()

        let info = try engine.read(from: url)
        #expect(info.metadata.title == "New Title")
        #expect(info.metadata.artist == "New Artist")
        #expect(info.metadata.album == "New Album")
        #expect(info.metadata.year == 2025)
        #expect(info.metadata.genre == "Rock")
        #expect(info.metadata.trackNumber == 3)
        #expect(info.metadata.discNumber == 1)
        #expect(info.metadata.composer == "Composer")
        #expect(info.metadata.albumArtist == "VA")
        #expect(info.metadata.comment == "Great track")
        #expect(info.metadata.bpm == 128)
    }

    // MARK: - Artwork

    @Test("audiomarker write --artwork — embed image")
    func writeArtwork() throws {
        let url = try CLITestHelper.createMP3(title: "Art Test")
        defer { try? FileManager.default.removeItem(at: url) }

        // Write a JPEG file to disk
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 64)
        let artURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".jpg")
        try jpegData.write(to: artURL)
        defer { try? FileManager.default.removeItem(at: artURL) }

        var cmd = try Write.parse([url.path, "--artwork", artURL.path])
        try cmd.run()

        let info = try engine.read(from: url)
        #expect(info.metadata.artwork != nil)
        #expect(info.metadata.artwork?.format == .jpeg)
    }

    // MARK: - Unsynchronized Lyrics

    @Test("audiomarker write --lyrics — set unsynchronized lyrics")
    func writeLyrics() throws {
        let url = try CLITestHelper.createMP3(title: "Lyrics Test")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Write.parse([url.path, "--lyrics", "Hello world\nSecond line"])
        try cmd.run()

        let info = try engine.read(from: url)
        #expect(info.metadata.unsynchronizedLyrics == "Hello world\nSecond line")
    }

    // MARK: - Synchronized Lyrics from LRC

    @Test("audiomarker write --lyrics-file — import LRC as synchronized lyrics")
    func writeLyricsFile() throws {
        let url = try CLITestHelper.createMP3(title: "LRC Import")
        defer { try? FileManager.default.removeItem(at: url) }

        // Create a .lrc file
        let lrcURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".lrc")
        try "[00:00.00]First line\n[00:05.50]Second line"
            .write(to: lrcURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: lrcURL) }

        var cmd = try Write.parse([url.path, "--lyrics-file", lrcURL.path])
        try cmd.run()

        let info = try engine.read(from: url)
        #expect(!info.metadata.synchronizedLyrics.isEmpty)
        #expect(info.metadata.synchronizedLyrics[0].lines.count == 2)
    }

    // MARK: - Clear Lyrics

    @Test("audiomarker write --clear-lyrics — remove all lyrics")
    func clearLyrics() throws {
        let url = try CLITestHelper.createMP3WithUnsyncLyrics(lyrics: "Old lyrics")
        defer { try? FileManager.default.removeItem(at: url) }

        // Verify lyrics exist
        let before = try engine.read(from: url)
        #expect(before.metadata.unsynchronizedLyrics != nil)

        // Clear
        var cmd = try Write.parse([url.path, "--clear-lyrics"])
        try cmd.run()

        let after = try engine.read(from: url)
        #expect(after.metadata.unsynchronizedLyrics == nil)
        #expect(after.metadata.synchronizedLyrics.isEmpty)
    }

    // MARK: - Preserve Existing

    @Test("audiomarker write — preserves existing metadata")
    func preserveExisting() throws {
        // Create a file with title + artist
        let frames: [Data] = [
            ID3TestHelper.buildTextFrame(id: "TIT2", text: "Keep Me"),
            ID3TestHelper.buildTextFrame(id: "TPE1", text: "Keep Artist")
        ]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Write only genre — don't touch title/artist
        var cmd = try Write.parse([url.path, "--genre", "Jazz"])
        try cmd.run()

        // Both original fields and new field should be present
        let info = try engine.read(from: url)
        #expect(info.metadata.title == "Keep Me")
        #expect(info.metadata.artist == "Keep Artist")
        #expect(info.metadata.genre == "Jazz")
    }
}
