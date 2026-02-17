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


import ArgumentParser
import AudioMarker
import Foundation

extension Chapters {

    /// Imports chapters from a text file.
    struct Import: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "import",
            abstract: "Import chapters from a text file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Option(name: .long, help: "Path to the chapter file.")
        var from: String

        @Option(
            name: .long,
            help: "Chapter format: podlove-json, podlove-xml, mp4chaps, ffmetadata, podcast-ns, cue."
        )
        var format: String = "podlove-json"

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)
            let sourceURL = CLIHelpers.resolveURL(from)
            let exportFormat = try CLIHelpers.parseExportFormat(format)

            let content = try String(contentsOf: sourceURL, encoding: .utf8)
            let engine = AudioMarkerEngine()
            try engine.importChapters(from: content, format: exportFormat, to: fileURL)

            print("Chapters imported from \(sourceURL.lastPathComponent) to \(fileURL.lastPathComponent).")
        }
    }
}
