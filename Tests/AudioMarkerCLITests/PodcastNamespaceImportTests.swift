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

@Suite("CLI Podcast Namespace Import")
struct PodcastNamespaceImportTests {

    @Test("Import Podcasting 2.0 chapters via CLI")
    func importPodcastNamespace() throws {
        let url = try CLITestHelper.createMP3(title: "Podcast Episode")
        defer { try? FileManager.default.removeItem(at: url) }

        let json = """
            {
              "version": "1.2.0",
              "chapters": [
                { "startTime": 0, "title": "Introduction" },
                { "startTime": 60, "title": "Topic 1", "url": "https://example.com" },
                { "startTime": 300, "title": "Conclusion" }
              ]
            }
            """

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try json.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        var cmd = try Chapters.Import.parse(
            [url.path, "--from", tempFile.path, "--format", "podcast-ns"])
        try cmd.run()

        let engine = AudioMarkerEngine()
        let info = try engine.read(from: url)
        #expect(info.chapters.count == 3)

        let chapters = Array(info.chapters)
        #expect(chapters[0].title == "Introduction")
        #expect(chapters[0].start.timeInterval == 0)
        #expect(chapters[1].title == "Topic 1")
        #expect(chapters[1].start.timeInterval == 60)
        #expect(chapters[1].url?.absoluteString == "https://example.com")
        #expect(chapters[2].title == "Conclusion")
        #expect(chapters[2].start.timeInterval == 300)
    }

    @Test("podcast-namespace format alias works")
    func podcastNamespaceAlias() throws {
        // Verify the longer alias also works.
        let format = try CLIHelpers.parseExportFormat("podcast-namespace")
        #expect(format == .podcastNamespace)
    }
}
