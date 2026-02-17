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

    /// Exports chapters to a text file or stdout.
    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export chapters to a text format."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Option(name: .long, help: "Output file path (stdout if omitted).")
        var to: String?

        @Option(
            name: .long,
            help: "Export format: podlove-json, podlove-xml, mp4chaps, ffmetadata, markdown, podcast-ns, cue."
        )
        var format: String = "podlove-json"

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)
            let exportFormat = try CLIHelpers.parseExportFormat(format)

            let engine = AudioMarkerEngine()
            let output = try engine.exportChapters(from: fileURL, format: exportFormat)

            if let outputPath = to {
                let outputURL = CLIHelpers.resolveURL(outputPath)
                try output.write(to: outputURL, atomically: true, encoding: .utf8)
                print("Chapters exported to \(outputURL.lastPathComponent).")
            } else {
                print(output)
            }
        }
    }
}
