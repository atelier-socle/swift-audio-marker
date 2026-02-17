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

/// Demonstrates CLI batch operations: reading directories, recursive mode, batch strip.
@Suite("Showcase: CLI Batch")
struct CLIBatchShowcaseTests {

    // MARK: - Batch Read

    @Test("audiomarker batch read — read all files in directory")
    func batchRead() async throws {
        let dir = try CLITestHelper.createTempDirectory(files: [
            "track1.mp3", "track2.mp3", "track3.mp3"
        ])
        defer { try? FileManager.default.removeItem(at: dir) }

        var cmd = try Batch.BatchRead.parse([dir.path])
        try await cmd.run()
    }

    // MARK: - Recursive

    @Test("audiomarker batch read --recursive — include subdirectories")
    func batchReadRecursive() async throws {
        // Create a directory with a subdirectory
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let subdir = dir.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Create files in root and subdirectory
        let rootFile = dir.appendingPathComponent("root.mp3")
        let subFile = subdir.appendingPathComponent("nested.mp3")
        for fileURL in [rootFile, subFile] {
            let tag = ID3TestHelper.buildTag(
                version: .v2_3,
                frames: [ID3TestHelper.buildTextFrame(id: "TIT2", text: fileURL.lastPathComponent)])
            var data = tag
            data.append(Data(repeating: 0xFF, count: 128))
            try data.write(to: fileURL)
        }

        var cmd = try Batch.BatchRead.parse([dir.path, "--recursive"])
        try await cmd.run()
    }

    // MARK: - Batch Strip

    @Test("audiomarker batch strip --force — strip all files")
    func batchStrip() async throws {
        let dir = try CLITestHelper.createTempDirectory(files: [
            "song1.mp3", "song2.mp3"
        ])
        defer { try? FileManager.default.removeItem(at: dir) }

        var cmd = try Batch.BatchStrip.parse([dir.path, "--force"])
        try await cmd.run()

        // Verify each file was stripped — MP3 no longer has ID3 tag
        let files = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "mp3" {
            #expect(throws: AudioMarkerError.self) {
                _ = try AudioMarkerEngine().read(from: file)
            }
        }
    }
}
