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

/// Demonstrates the CLI info command: technical details for MP3 and M4A files.
@Suite("Showcase: CLI Info")
struct CLIInfoShowcaseTests {

    // MARK: - MP3 Info

    @Test("audiomarker info — display MP3 file technical details")
    func infoMP3() throws {
        // Create an MP3 with metadata and artwork
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 32)
        let frames: [Data] = [
            ID3TestHelper.buildTextFrame(id: "TIT2", text: "Info Test"),
            ID3TestHelper.buildAPICFrame(imageData: jpegData),
            ID3TestHelper.buildCHAPFrame(
                elementID: "ch1", startTime: 0, endTime: 60_000,
                subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chapter")])
        ]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Info command runs without error
        var cmd = try Info.parse([url.path])
        try cmd.run()
    }

    // MARK: - M4A Info

    @Test("audiomarker info — M4A file")
    func infoM4A() throws {
        let url = try CLITestHelper.createM4A(title: "M4A Info Test")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Info.parse([url.path])
        try cmd.run()
    }
}
