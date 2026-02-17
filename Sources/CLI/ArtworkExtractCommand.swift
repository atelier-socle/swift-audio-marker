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

extension ArtworkGroup {

    /// Extracts embedded artwork from an audio file and saves it to disk.
    struct Extract: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Extract embedded artwork from an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Option(name: [.short, .long], help: "Output file path. Defaults to cover.<ext> in current directory.")
        var output: String?

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)
            let engine = AudioMarkerEngine()
            let info = try engine.read(from: fileURL)

            guard let artwork = info.metadata.artwork else {
                throw ValidationError("No artwork found in \"\(fileURL.lastPathComponent)\".")
            }

            let outputURL: URL
            if let output {
                outputURL = CLIHelpers.resolveURL(output)
            } else {
                let ext = artwork.format == .png ? "png" : "jpg"
                let cwd = FileManager.default.currentDirectoryPath
                outputURL = URL(fileURLWithPath: cwd).appendingPathComponent("cover.\(ext)")
            }

            try artwork.data.write(to: outputURL)
            let size = CLIHelpers.formatFileSize(UInt64(artwork.data.count))
            print(
                "Artwork extracted to \(outputURL.lastPathComponent) (\(artwork.format.rawValue.uppercased()), \(size))."
            )
        }
    }
}
