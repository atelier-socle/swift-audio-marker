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

extension Lyrics {

    /// Removes all lyrics (synchronized and unsynchronized) from an audio file.
    struct Clear: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove all lyrics from an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Flag(name: .long, help: "Skip confirmation prompt.")
        var force: Bool = false

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)

            if !force {
                print(
                    "This will remove ALL lyrics from \(fileURL.lastPathComponent). Continue? [y/N] ",
                    terminator: "")
                guard let answer = Swift.readLine(), answer.lowercased() == "y" else {
                    print("Aborted.")
                    return
                }
            }

            let engine = AudioMarkerEngine()

            var info: AudioFileInfo
            do {
                info = try engine.read(from: fileURL)
            } catch {
                info = AudioFileInfo()
            }

            info.metadata.synchronizedLyrics = []
            info.metadata.unsynchronizedLyrics = nil
            try engine.modify(info, in: fileURL)
            print("All lyrics removed from \(fileURL.lastPathComponent).")
        }
    }
}
