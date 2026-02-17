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

@Suite("CLI Lyrics Export Integration")
struct LyricsExportIntegrationTests {

    // MARK: - Export LRC

    @Test("Lyrics export produces LRC from SYLT")
    func exportLRC() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0),
            (text: "World", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Lyrics.Export.parse([url.path, "--format", "lrc"])
        try cmd.run()
    }

    // MARK: - Export TTML

    @Test("Lyrics export produces TTML from SYLT")
    func exportTTML() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0),
            (text: "World", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Lyrics.Export.parse([url.path, "--format", "ttml"])
        try cmd.run()
    }

    // MARK: - Export to File

    @Test("Lyrics export writes to --to file")
    func exportToFile() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0),
            (text: "World", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".lrc")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var cmd = try Lyrics.Export.parse([url.path, "--to", outputURL.path, "--format", "lrc"])
        try cmd.run()

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(content.contains("Hello"))
        #expect(content.contains("World"))
    }

    // MARK: - No Sync Lyrics Error

    @Test("Lyrics export throws when no synchronized lyrics")
    func exportNoSyncLyricsThrows() throws {
        let url = try CLITestHelper.createMP3(title: "No Lyrics")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Lyrics.Export.parse([url.path])
        #expect(throws: Error.self) {
            try cmd.run()
        }
    }

    // MARK: - Parsing

    @Test("Lyrics export parses format option")
    func parseFormat() throws {
        let cmd = try Lyrics.Export.parse(["song.mp3", "--format", "ttml"])
        #expect(cmd.format == "ttml")
    }

    @Test("Lyrics export defaults to lrc format")
    func defaultFormat() throws {
        let cmd = try Lyrics.Export.parse(["song.mp3"])
        #expect(cmd.format == "lrc")
    }

    // MARK: - Export WebVTT

    @Test("Lyrics export produces WebVTT from SYLT")
    func exportWebVTT() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0),
            (text: "World", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".vtt")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var cmd = try Lyrics.Export.parse([
            url.path, "--to", outputURL.path, "--format", "webvtt"
        ])
        try cmd.run()

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(content.contains("WEBVTT"))
        #expect(content.contains("Hello"))
    }

    // MARK: - Export SRT

    @Test("Lyrics export produces SRT from SYLT")
    func exportSRT() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0),
            (text: "World", timestamp: 5000)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".srt")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var cmd = try Lyrics.Export.parse([
            url.path, "--to", outputURL.path, "--format", "srt"
        ])
        try cmd.run()

        let content = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(content.contains("Hello"))
        #expect(content.contains("-->"))
    }

    // MARK: - Unsupported Format

    @Test("Lyrics export with unsupported format throws")
    func unsupportedFormatThrows() throws {
        let url = try CLITestHelper.createMP3WithSyncLyrics(events: [
            (text: "Hello", timestamp: 0)
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Lyrics.Export.parse([url.path, "--format", "markdown"])
        #expect(throws: Error.self) {
            try cmd.run()
        }
    }
}
