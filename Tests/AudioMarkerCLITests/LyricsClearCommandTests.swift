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

@Suite("CLI Lyrics Clear Command")
struct LyricsClearCommandTests {

    @Test("Clear lyrics removes synchronized and unsynchronized lyrics")
    func clearBothLyricsTypes() throws {
        // Create MP3 with both sync and unsync lyrics.
        let titleFrame = ID3TestHelper.buildTextFrame(id: "TIT2", text: "Both Lyrics")
        let usltFrame = ID3TestHelper.buildUSLTFrame(text: "Plain lyrics text")
        let syltFrame = ID3TestHelper.buildSYLTFrame(
            events: [
                (text: "Hello", timestamp: 0),
                (text: "World", timestamp: 1000)
            ]
        )
        let tag = ID3TestHelper.buildTag(
            version: .v2_3, frames: [titleFrame, usltFrame, syltFrame])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Verify lyrics exist before clear.
        let engine = AudioMarkerEngine()
        let before = try engine.read(from: url)
        #expect(before.metadata.unsynchronizedLyrics != nil)
        #expect(!before.metadata.synchronizedLyrics.isEmpty)

        // Clear with --force to skip confirmation.
        var cmd = try Lyrics.Clear.parse([url.path, "--force"])
        try cmd.run()

        // Verify both types are removed.
        let after = try engine.read(from: url)
        #expect(after.metadata.unsynchronizedLyrics == nil)
        #expect(after.metadata.synchronizedLyrics.isEmpty)
        // Title should be preserved.
        #expect(after.metadata.title == "Both Lyrics")
    }

    @Test("Clear lyrics on file without lyrics succeeds cleanly")
    func clearNoLyrics() throws {
        let url = try CLITestHelper.createMP3(title: "No Lyrics")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Lyrics.Clear.parse([url.path, "--force"])
        try cmd.run()

        let engine = AudioMarkerEngine()
        let info = try engine.read(from: url)
        #expect(info.metadata.unsynchronizedLyrics == nil)
        #expect(info.metadata.synchronizedLyrics.isEmpty)
        #expect(info.metadata.title == "No Lyrics")
    }

    @Test("Clear lyrics with --force skips confirmation")
    func clearWithForce() throws {
        let url = try CLITestHelper.createMP3WithUnsyncLyrics(lyrics: "Test lyrics")
        defer { try? FileManager.default.removeItem(at: url) }

        // Parsing with --force should succeed and run without interactive input.
        var cmd = try Lyrics.Clear.parse([url.path, "--force"])
        try cmd.run()

        let engine = AudioMarkerEngine()
        let info = try engine.read(from: url)
        #expect(info.metadata.unsynchronizedLyrics == nil)
    }
}
