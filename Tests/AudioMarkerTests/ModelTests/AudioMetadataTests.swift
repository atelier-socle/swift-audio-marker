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


import Foundation
import Testing

@testable import AudioMarker

@Suite("AudioMetadata")
struct AudioMetadataTests {

    // MARK: - Default init

    @Test("Default init has nil core fields")
    func defaultInit() {
        let metadata = AudioMetadata()
        #expect(metadata.title == nil)
        #expect(metadata.artist == nil)
        #expect(metadata.album == nil)
        #expect(metadata.artwork == nil)
        #expect(metadata.genre == nil)
        #expect(metadata.year == nil)
        #expect(metadata.trackNumber == nil)
        #expect(metadata.discNumber == nil)
    }

    @Test("Default init has empty collections")
    func defaultInitCollections() {
        let metadata = AudioMetadata()
        #expect(metadata.synchronizedLyrics.isEmpty)
        #expect(metadata.customURLs.isEmpty)
        #expect(metadata.customTextFields.isEmpty)
        #expect(metadata.privateData.isEmpty)
        #expect(metadata.uniqueFileIdentifiers.isEmpty)
    }

    // MARK: - Parameterized init

    @Test("Init with core fields")
    func initWithCoreFields() {
        let artwork = Artwork(data: Data([0xFF, 0xD8, 0xFF]), format: .jpeg)
        let metadata = AudioMetadata(
            title: "Test Track",
            artist: "Test Artist",
            album: "Test Album",
            artwork: artwork
        )
        #expect(metadata.title == "Test Track")
        #expect(metadata.artist == "Test Artist")
        #expect(metadata.album == "Test Album")
        #expect(metadata.artwork == artwork)
    }

    // MARK: - Mutability

    @Test("Professional fields are mutable")
    func professionalFieldsMutable() {
        var metadata = AudioMetadata()
        metadata.composer = "Bach"
        metadata.albumArtist = "Various Artists"
        metadata.publisher = "Acme Records"
        metadata.copyright = "2024 Acme"
        metadata.bpm = 120
        metadata.key = "Am"
        metadata.language = "eng"
        metadata.isrc = "US1234567890"

        #expect(metadata.composer == "Bach")
        #expect(metadata.albumArtist == "Various Artists")
        #expect(metadata.publisher == "Acme Records")
        #expect(metadata.copyright == "2024 Acme")
        #expect(metadata.bpm == 120)
        #expect(metadata.key == "Am")
        #expect(metadata.language == "eng")
        #expect(metadata.isrc == "US1234567890")
    }

    @Test("URL fields are mutable")
    func urlFieldsMutable() {
        var metadata = AudioMetadata()
        metadata.artistURL = URL(string: "https://example.com/artist")
        metadata.audioSourceURL = URL(string: "https://example.com/source")
        metadata.commercialURL = URL(string: "https://example.com/buy")
        metadata.customURLs["info"] = URL(string: "https://example.com/info")

        #expect(metadata.artistURL?.absoluteString == "https://example.com/artist")
        #expect(metadata.customURLs["info"]?.absoluteString == "https://example.com/info")
    }

    @Test("Statistics fields are mutable")
    func statisticsMutable() {
        var metadata = AudioMetadata()
        metadata.playCount = 42
        metadata.rating = 255

        #expect(metadata.playCount == 42)
        #expect(metadata.rating == 255)
    }

    @Test("Custom text fields are mutable")
    func customTextFieldsMutable() {
        var metadata = AudioMetadata()
        metadata.customTextFields["MOOD"] = "Happy"
        metadata.customTextFields["OCCASION"] = "Party"

        #expect(metadata.customTextFields.count == 2)
        #expect(metadata.customTextFields["MOOD"] == "Happy")
    }
}
