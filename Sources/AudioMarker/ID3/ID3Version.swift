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


// swift-format-ignore: AlwaysUseLowerCamelCase
/// Supported ID3v2 tag versions.
public enum ID3Version: Sendable, Hashable {

    /// ID3v2.3 (most widely used).
    case v2_3

    /// ID3v2.4 (latest revision).
    case v2_4

    /// The major version number (3 or 4).
    public var majorVersion: UInt8 {
        switch self {
        case .v2_3: return 3
        case .v2_4: return 4
        }
    }

    /// The full version string (e.g., `"ID3v2.3"`, `"ID3v2.4"`).
    public var displayName: String {
        switch self {
        case .v2_3: return "ID3v2.3"
        case .v2_4: return "ID3v2.4"
        }
    }
}
