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


/// Synchronized (timestamped) lyrics or text, corresponding to ID3v2 SYLT frames.
public struct SynchronizedLyrics: Sendable, Hashable {

    /// ISO 639-2 language code (3 characters, e.g., `"eng"`, `"fra"`).
    public let language: String

    /// The type of synchronized content.
    public let contentType: ContentType

    /// Optional content descriptor.
    public let descriptor: String

    /// Timestamped lines, ordered by time.
    public var lines: [LyricLine]

    /// Creates synchronized lyrics.
    /// - Parameters:
    ///   - language: ISO 639-2 language code (3 characters).
    ///   - contentType: The type of content. Defaults to ``ContentType/lyrics``.
    ///   - descriptor: Optional content descriptor. Defaults to empty string.
    ///   - lines: Timestamped lines. Defaults to empty array.
    public init(
        language: String,
        contentType: ContentType = .lyrics,
        descriptor: String = "",
        lines: [LyricLine] = []
    ) {
        self.language = language
        self.contentType = contentType
        self.descriptor = descriptor
        self.lines = lines
    }

    /// Returns a copy with lines sorted by time in ascending order.
    /// - Returns: A new ``SynchronizedLyrics`` with sorted lines.
    public func sorted() -> SynchronizedLyrics {
        var copy = self
        copy.lines.sort { $0.time < $1.time }
        return copy
    }
}
