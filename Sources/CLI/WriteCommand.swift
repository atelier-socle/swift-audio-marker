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

/// Writes metadata to an audio file.
struct Write: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Write metadata to an audio file."
    )

    @Argument(help: "Path to the audio file.")
    var file: String

    @Option(name: .long, help: "Track title.")
    var title: String?

    @Option(name: .long, help: "Artist name.")
    var artist: String?

    @Option(name: .long, help: "Album name.")
    var album: String?

    @Option(name: .long, help: "Genre.")
    var genre: String?

    @Option(name: .long, help: "Year.")
    var year: Int?

    @Option(name: .long, help: "Track number.")
    var trackNumber: Int?

    @Option(name: .long, help: "Disc number.")
    var discNumber: Int?

    @Option(name: .long, help: "Composer.")
    var composer: String?

    @Option(name: .long, help: "Album artist.")
    var albumArtist: String?

    @Option(name: .long, help: "Comment.")
    var comment: String?

    @Option(name: .long, help: "BPM.")
    var bpm: Int?

    @Option(name: .long, help: "Path to artwork image (JPEG or PNG).")
    var artwork: String?

    @Option(name: .long, help: "Unsynchronized lyrics text.")
    var lyrics: String?

    @Option(name: .long, help: "Path to a lyrics file (.txt for unsync, .lrc for sync).")
    var lyricsFile: String?

    @Flag(name: .long, help: "Clear existing lyrics.")
    var clearLyrics: Bool = false

    mutating func run() throws {
        let url = CLIHelpers.resolveURL(file)
        let engine = AudioMarkerEngine()

        var info: AudioFileInfo
        do {
            info = try engine.read(from: url)
        } catch {
            info = AudioFileInfo()
        }

        applyTextFields(to: &info.metadata)
        applyNumericFields(to: &info.metadata)
        try applyLyrics(to: &info.metadata)

        if let artworkPath = artwork {
            let artworkURL = CLIHelpers.resolveURL(artworkPath)
            info.metadata.artwork = try Artwork(contentsOf: artworkURL)
        }

        try engine.modify(info, in: url)
        print("Metadata written to \(url.lastPathComponent).")
    }
}

// MARK: - Field Application

extension Write {

    private func applyTextFields(to metadata: inout AudioMetadata) {
        if let title { metadata.title = title }
        if let artist { metadata.artist = artist }
        if let album { metadata.album = album }
        if let genre { metadata.genre = genre }
        if let composer { metadata.composer = composer }
        if let albumArtist { metadata.albumArtist = albumArtist }
        if let comment { metadata.comment = comment }
    }

    private func applyNumericFields(to metadata: inout AudioMetadata) {
        if let year { metadata.year = year }
        if let trackNumber { metadata.trackNumber = trackNumber }
        if let discNumber { metadata.discNumber = discNumber }
        if let bpm { metadata.bpm = bpm }
    }

    private func applyLyrics(to metadata: inout AudioMetadata) throws {
        if clearLyrics {
            metadata.unsynchronizedLyrics = nil
            metadata.synchronizedLyrics = []
            return
        }

        if let lyrics {
            metadata.unsynchronizedLyrics = lyrics
        }

        if let lyricsFile {
            let url = CLIHelpers.resolveURL(lyricsFile)
            let content = try String(contentsOf: url, encoding: .utf8)

            if url.pathExtension.lowercased() == "lrc" {
                let syncLyrics = try LRCParser.parse(content)
                metadata.synchronizedLyrics.append(syncLyrics)
            } else {
                metadata.unsynchronizedLyrics = content
            }
        }
    }
}
