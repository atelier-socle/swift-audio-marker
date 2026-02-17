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

/// Private data frame (ID3v2 PRIV), used by services like Spotify or Apple Music.
public struct PrivateData: Sendable, Hashable {

    /// Owner identifier (e.g., `"com.spotify.track"`).
    public let owner: String

    /// Raw private data bytes.
    public let data: Data

    /// Creates a private data entry.
    /// - Parameters:
    ///   - owner: Owner identifier string.
    ///   - data: Raw private data bytes.
    public init(owner: String, data: Data) {
        self.owner = owner
        self.data = data
    }
}
