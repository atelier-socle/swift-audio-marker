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

    /// Removes a chapter from an audio file.
    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove a chapter from an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Option(name: .long, help: "Chapter index (1-based).")
        var index: Int?

        @Option(name: .long, help: "Chapter title to remove.")
        var title: String?

        func validate() throws {
            guard index != nil || title != nil else {
                throw ValidationError("Provide either --index or --title to identify the chapter.")
            }
        }

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)
            let engine = AudioMarkerEngine()
            var info = try engine.read(from: fileURL)

            if let index {
                let zeroIndex = index - 1
                guard zeroIndex >= 0 && zeroIndex < info.chapters.count else {
                    throw ValidationError(
                        "Index \(index) is out of range. File has \(info.chapters.count) chapter(s)."
                    )
                }
                let removed = info.chapters.remove(at: zeroIndex)
                info.chapters.clearEndTimes()
                try engine.modify(info, in: fileURL)
                print("Removed chapter \"\(removed.title)\".")
            } else if let title {
                guard let idx = info.chapters.firstIndex(where: { $0.title == title }) else {
                    throw ValidationError("No chapter found with title \"\(title)\".")
                }
                info.chapters.remove(at: idx)
                info.chapters.clearEndTimes()
                try engine.modify(info, in: fileURL)
                print("Removed chapter \"\(title)\".")
            }
        }
    }
}
