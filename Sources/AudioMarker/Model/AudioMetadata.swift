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

/// Global metadata for an audio file.
public struct AudioMetadata: Sendable, Hashable {

    // MARK: - Core

    /// Track title.
    public var title: String?
    /// Primary artist or performer.
    public var artist: String?
    /// Album name.
    public var album: String?
    /// Genre.
    public var genre: String?
    /// Release year.
    public var year: Int?
    /// Track number within the album.
    public var trackNumber: Int?
    /// Disc number.
    public var discNumber: Int?

    // MARK: - Professional

    /// Composer or songwriter.
    public var composer: String?
    /// Album-level artist (for compilations).
    public var albumArtist: String?
    /// Publisher or label.
    public var publisher: String?
    /// Copyright notice.
    public var copyright: String?
    /// Encoder software name.
    public var encoder: String?
    /// General comment.
    public var comment: String?
    /// Beats per minute.
    public var bpm: Int?
    /// Musical key (e.g., `"Am"`, `"C#"`).
    public var key: String?
    /// ISO 639-2 language code.
    public var language: String?
    /// International Standard Recording Code.
    public var isrc: String?

    // MARK: - Artwork

    /// Embedded cover artwork.
    public var artwork: Artwork?

    // MARK: - Lyrics

    /// Unsynchronized (plain text) lyrics.
    public var unsynchronizedLyrics: String?
    /// Synchronized (timestamped) lyrics.
    public var synchronizedLyrics: [SynchronizedLyrics]

    // MARK: - URLs

    /// Official artist URL.
    public var artistURL: URL?
    /// Audio source URL.
    public var audioSourceURL: URL?
    /// Audio file URL.
    public var audioFileURL: URL?
    /// Publisher URL.
    public var publisherURL: URL?
    /// Commercial information URL.
    public var commercialURL: URL?
    /// Custom URL entries keyed by description.
    public var customURLs: [String: URL]

    // MARK: - Custom data

    /// Custom text fields keyed by field name.
    public var customTextFields: [String: String]
    /// Private data frames (ID3v2 PRIV).
    public var privateData: [PrivateData]
    /// Unique file identifiers (ID3v2 UFID).
    public var uniqueFileIdentifiers: [UniqueFileIdentifier]

    // MARK: - Statistics

    /// Play count.
    public var playCount: Int?
    /// User rating (0–255).
    public var rating: UInt8?

    // MARK: - Initializer

    /// Creates audio metadata with optional core fields.
    /// - Parameters:
    ///   - title: Track title.
    ///   - artist: Primary artist or performer.
    ///   - album: Album name.
    ///   - artwork: Embedded cover artwork.
    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        artwork: Artwork? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.synchronizedLyrics = []
        self.customURLs = [:]
        self.customTextFields = [:]
        self.privateData = []
        self.uniqueFileIdentifiers = []
    }
}
