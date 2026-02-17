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


/// Complete parsed information from an audio file.
public struct AudioFileInfo: Sendable, Hashable {

    /// Global metadata (title, artist, artwork, etc.).
    public var metadata: AudioMetadata

    /// Chapter markers.
    public var chapters: ChapterList

    /// Audio duration.
    public var duration: AudioTimestamp?

    /// Creates audio file info.
    /// - Parameters:
    ///   - metadata: Global metadata. Defaults to empty metadata.
    ///   - chapters: Chapter markers. Defaults to empty list.
    ///   - duration: Audio duration. Defaults to `nil`.
    public init(
        metadata: AudioMetadata = AudioMetadata(),
        chapters: ChapterList = ChapterList(),
        duration: AudioTimestamp? = nil
    ) {
        self.metadata = metadata
        self.chapters = chapters
        self.duration = duration
    }
}
