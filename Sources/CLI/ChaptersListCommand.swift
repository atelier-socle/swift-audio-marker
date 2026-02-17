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

    /// Lists chapters in an audio file.
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List chapters in an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        mutating func run() throws {
            let url = CLIHelpers.resolveURL(file)
            let engine = AudioMarkerEngine()
            let chapters = try engine.readChapters(from: url)

            if chapters.isEmpty {
                print("No chapters found in \(url.lastPathComponent).")
                return
            }

            print("Chapters (\(chapters.count)) in \(url.lastPathComponent):")
            for (index, chapter) in chapters.enumerated() {
                let number = index + 1
                var line =
                    "  \(number). \(chapter.start.shortDescription) \u{2014} \(chapter.title)"
                if let artwork = chapter.artwork {
                    let sizeKB = Double(artwork.data.count) / 1024.0
                    line +=
                        " [artwork: \(artwork.format.rawValue.uppercased()) \(String(format: "%.1f", sizeKB)) KB]"
                }
                if let url = chapter.url {
                    line += " (\(url.absoluteString))"
                }
                print(line)
            }
        }
    }
}
