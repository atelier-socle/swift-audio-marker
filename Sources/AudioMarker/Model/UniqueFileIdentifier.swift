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

/// Unique file identifier (ID3v2 UFID), used for podcast GUIDs and similar identifiers.
public struct UniqueFileIdentifier: Sendable, Hashable {

    /// Owner identifier (e.g., `"http://www.id3.org/dummy/ufid.html"`).
    public let owner: String

    /// Identifier bytes.
    public let identifier: Data

    /// Creates a unique file identifier.
    /// - Parameters:
    ///   - owner: Owner identifier string.
    ///   - identifier: Identifier bytes.
    public init(owner: String, identifier: Data) {
        self.owner = owner
        self.identifier = identifier
    }
}
