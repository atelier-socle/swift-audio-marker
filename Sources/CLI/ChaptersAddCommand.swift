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

    /// Adds a chapter to an audio file.
    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add a chapter to an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Option(name: .long, help: "Chapter start time (HH:MM:SS or HH:MM:SS.mmm).")
        var start: String

        @Option(name: .long, help: "Chapter title.")
        var title: String

        @Option(name: .long, help: "Chapter URL.")
        var url: String?

        @Option(
            name: .long,
            help: "Path to artwork image (JPEG or PNG) for this chapter."
        )
        var artwork: String?

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)
            let engine = AudioMarkerEngine()

            var info: AudioFileInfo
            do {
                info = try engine.read(from: fileURL)
            } catch {
                info = AudioFileInfo()
            }

            let timestamp = try AudioTimestamp(string: start)
            let chapterURL = url.flatMap { URL(string: $0) }
            let chapterArtwork: Artwork?
            if let artworkPath = artwork {
                chapterArtwork = try Artwork(contentsOf: CLIHelpers.resolveURL(artworkPath))
            } else {
                chapterArtwork = nil
            }
            let chapter = Chapter(
                start: timestamp, title: title, url: chapterURL, artwork: chapterArtwork)

            info.chapters.append(chapter)
            info.chapters.sort()
            info.chapters.clearEndTimes()

            try engine.modify(info, in: fileURL)

            print("Added chapter \"\(title)\" at \(timestamp.shortDescription).")
        }
    }
}
