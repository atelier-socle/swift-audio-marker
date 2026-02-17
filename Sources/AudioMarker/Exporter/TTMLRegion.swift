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


/// A TTML display region defining where text appears on screen.
///
/// Captures `<region>` elements from a TTML document for round-trip preservation.
public struct TTMLRegion: Sendable, Hashable {

    /// Region identifier (`xml:id`).
    public let id: String

    /// Origin position (`tts:origin`, e.g., `"10% 80%"`).
    public let origin: String?

    /// Extent/size (`tts:extent`, e.g., `"80% 20%"`).
    public let extent: String?

    /// Display alignment (`tts:displayAlign`).
    public let displayAlign: String?

    /// Additional style properties.
    public let properties: [String: String]

    /// Creates a TTML region.
    /// - Parameters:
    ///   - id: Region identifier.
    ///   - origin: Origin position. Defaults to `nil`.
    ///   - extent: Extent/size. Defaults to `nil`.
    ///   - displayAlign: Display alignment. Defaults to `nil`.
    ///   - properties: Additional properties. Defaults to empty.
    public init(
        id: String,
        origin: String? = nil,
        extent: String? = nil,
        displayAlign: String? = nil,
        properties: [String: String] = [:]
    ) {
        self.id = id
        self.origin = origin
        self.extent = extent
        self.displayAlign = displayAlign
        self.properties = properties
    }
}
