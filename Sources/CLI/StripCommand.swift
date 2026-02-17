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

/// Strips all metadata and chapters from an audio file.
struct Strip: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Strip all metadata and chapters from an audio file."
    )

    @Argument(help: "Path to the audio file.")
    var file: String

    @Flag(name: .long, help: "Skip confirmation prompt.")
    var force: Bool = false

    mutating func run() throws {
        let url = CLIHelpers.resolveURL(file)

        if !force {
            print("This will remove ALL metadata from \(url.lastPathComponent). Continue? [y/N] ", terminator: "")
            guard let answer = Swift.readLine(), answer.lowercased() == "y" else {
                print("Aborted.")
                return
            }
        }

        let engine = AudioMarkerEngine()
        try engine.strip(from: url)
        print("All metadata stripped from \(url.lastPathComponent).")
    }
}
