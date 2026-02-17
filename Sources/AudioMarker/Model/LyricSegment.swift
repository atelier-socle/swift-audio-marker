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


/// A timed segment within a lyric line, enabling word-level (karaoke) timing.
///
/// Each segment represents a portion of text (typically a word or syllable)
/// with its own timing, allowing karaoke-style highlighting.
public struct LyricSegment: Sendable, Hashable {

    /// Start time of this segment.
    public let startTime: AudioTimestamp

    /// End time of this segment.
    public let endTime: AudioTimestamp

    /// The text content of this segment.
    public let text: String

    /// Optional style identifier (for TTML round-trip).
    public let styleID: String?

    /// Creates a timed lyric segment.
    /// - Parameters:
    ///   - startTime: Start time of this segment.
    ///   - endTime: End time of this segment.
    ///   - text: The text content.
    ///   - styleID: Optional style identifier. Defaults to `nil`.
    public init(
        startTime: AudioTimestamp,
        endTime: AudioTimestamp,
        text: String,
        styleID: String? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.styleID = styleID
    }
}
