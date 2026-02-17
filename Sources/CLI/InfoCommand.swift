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

/// Displays technical information about an audio file.
struct Info: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Display technical information about an audio file."
    )

    @Argument(help: "Path to the audio file.")
    var file: String

    mutating func run() throws {
        let url = CLIHelpers.resolveURL(file)
        let engine = AudioMarkerEngine()
        let format = try engine.detectFormat(of: url)
        let info = try engine.read(from: url)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs[.size] as? UInt64 ?? 0

        print("File:     \(url.lastPathComponent)")
        print("Format:   \(format.rawValue.uppercased())")
        print("Size:     \(CLIHelpers.formatFileSize(fileSize))")

        if let duration = info.duration {
            print("Duration: \(duration.shortDescription)")
        }

        if !info.chapters.isEmpty {
            print("Chapters: \(info.chapters.count)")
        }

        if let artwork = info.metadata.artwork {
            let artFormat = artwork.format.rawValue.uppercased()
            let artSize = CLIHelpers.formatFileSize(UInt64(artwork.data.count))
            print("Artwork:  \(artFormat) (\(artSize))")
        }
    }
}
