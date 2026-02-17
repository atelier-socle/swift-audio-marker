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

/// A single chapter marker within an audio file.
public struct Chapter: Sendable, Hashable, Identifiable {

    /// Unique identifier for this chapter.
    public let id: UUID

    /// Chapter start time.
    public let start: AudioTimestamp

    /// Chapter end time (`nil` means calculated from next chapter or audio duration).
    public var end: AudioTimestamp?

    /// Chapter title.
    public let title: String

    /// Optional URL associated with this chapter.
    public let url: URL?

    /// Optional per-chapter artwork.
    public let artwork: Artwork?

    /// Creates a new chapter marker.
    /// - Parameters:
    ///   - start: The start time of the chapter.
    ///   - title: The chapter title (should not be empty).
    ///   - end: Optional end time. If `nil`, calculated from next chapter or audio duration.
    ///   - url: Optional URL associated with the chapter.
    ///   - artwork: Optional per-chapter artwork.
    public init(
        start: AudioTimestamp,
        title: String,
        end: AudioTimestamp? = nil,
        url: URL? = nil,
        artwork: Artwork? = nil
    ) {
        self.id = UUID()
        self.start = start
        self.title = title
        self.end = end
        self.url = url
        self.artwork = artwork
    }
}
