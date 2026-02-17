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

@Suite("CLI Lyrics Import Integration")
struct LyricsImportIntegrationTests {

    // MARK: - Import LRC

    @Test("Lyrics import from LRC file adds synchronized lyrics")
    func importLRC() throws {
        let url = try CLITestHelper.createMP3(title: "LRC Import")
        defer { try? FileManager.default.removeItem(at: url) }

        let lrcURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".lrc")
        defer { try? FileManager.default.removeItem(at: lrcURL) }
        try "[00:00.00]Hello\n[00:05.00]World".write(
            to: lrcURL, atomically: true, encoding: .utf8)

        var cmd = try Lyrics.Import.parse([
            url.path, "--from", lrcURL.path, "--format", "lrc"
        ])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.synchronizedLyrics.count == 1)
        #expect(info.metadata.synchronizedLyrics[0].lines.count == 2)
        #expect(info.metadata.synchronizedLyrics[0].lines[0].text == "Hello")
    }

    // MARK: - Import WebVTT

    @Test("Lyrics import from WebVTT file adds synchronized lyrics")
    func importWebVTT() throws {
        let url = try CLITestHelper.createMP3(title: "WebVTT Import")
        defer { try? FileManager.default.removeItem(at: url) }

        let vttURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".vtt")
        defer { try? FileManager.default.removeItem(at: vttURL) }
        let vttContent = """
            WEBVTT

            00:00:00.000 --> 00:00:05.000
            Hello

            00:00:05.000 --> 00:00:10.000
            World
            """
        try vttContent.write(to: vttURL, atomically: true, encoding: .utf8)

        var cmd = try Lyrics.Import.parse([
            url.path, "--from", vttURL.path, "--format", "webvtt"
        ])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.synchronizedLyrics.count == 1)
        #expect(info.metadata.synchronizedLyrics[0].lines.count == 2)
    }

    // MARK: - Import SRT

    @Test("Lyrics import from SRT file adds synchronized lyrics")
    func importSRT() throws {
        let url = try CLITestHelper.createMP3(title: "SRT Import")
        defer { try? FileManager.default.removeItem(at: url) }

        let srtURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".srt")
        defer { try? FileManager.default.removeItem(at: srtURL) }
        let srtContent = """
            1
            00:00:00,000 --> 00:00:05,000
            Hello

            2
            00:00:05,000 --> 00:00:10,000
            World
            """
        try srtContent.write(to: srtURL, atomically: true, encoding: .utf8)

        var cmd = try Lyrics.Import.parse([
            url.path, "--from", srtURL.path, "--format", "srt"
        ])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.synchronizedLyrics.count == 1)
        #expect(info.metadata.synchronizedLyrics[0].lines.count == 2)
    }

    // MARK: - Unsupported Import Format

    @Test("Lyrics import with unsupported format throws")
    func importUnsupportedFormatThrows() throws {
        let url = try CLITestHelper.createMP3(title: "Bad Format")
        defer { try? FileManager.default.removeItem(at: url) }

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".txt")
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        try "some text".write(to: tmpURL, atomically: true, encoding: .utf8)

        var cmd = try Lyrics.Import.parse([
            url.path, "--from", tmpURL.path, "--format", "markdown"
        ])
        #expect(throws: Error.self) {
            try cmd.run()
        }
    }

    // MARK: - Import with Language

    @Test("Lyrics import sets language code")
    func importWithLanguage() throws {
        let url = try CLITestHelper.createMP3(title: "Lang Import")
        defer { try? FileManager.default.removeItem(at: url) }

        let lrcURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".lrc")
        defer { try? FileManager.default.removeItem(at: lrcURL) }
        try "[00:00.00]Bonjour".write(to: lrcURL, atomically: true, encoding: .utf8)

        var cmd = try Lyrics.Import.parse([
            url.path, "--from", lrcURL.path, "--format", "lrc", "--language", "fra"
        ])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.synchronizedLyrics[0].language == "fra")
    }
}
