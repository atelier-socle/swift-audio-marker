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


/// A TTML style definition with visual properties.
///
/// Captures `<style>` elements from a TTML document for round-trip preservation.
/// Properties are stored as raw key-value pairs matching the TTML namespace
/// (e.g., `"tts:color"` → `"#FFFFFF"`).
public struct TTMLStyle: Sendable, Hashable {

    /// Style identifier (`xml:id`).
    public let id: String

    /// Visual properties as key-value pairs (e.g., `"tts:color"` → `"#FFFFFF"`).
    public let properties: [String: String]

    /// Creates a TTML style.
    /// - Parameters:
    ///   - id: Style identifier.
    ///   - properties: Visual properties. Defaults to empty.
    public init(id: String, properties: [String: String] = [:]) {
        self.id = id
        self.properties = properties
    }

    // MARK: - Convenience Accessors

    /// Text color (`tts:color`).
    public var color: String? { properties["tts:color"] }

    /// Background color (`tts:backgroundColor`).
    public var backgroundColor: String? { properties["tts:backgroundColor"] }

    /// Font family (`tts:fontFamily`).
    public var fontFamily: String? { properties["tts:fontFamily"] }

    /// Font size (`tts:fontSize`).
    public var fontSize: String? { properties["tts:fontSize"] }

    /// Font weight: `"normal"` or `"bold"` (`tts:fontWeight`).
    public var fontWeight: String? { properties["tts:fontWeight"] }

    /// Font style: `"normal"` or `"italic"` (`tts:fontStyle`).
    public var fontStyle: String? { properties["tts:fontStyle"] }

    /// Text alignment (`tts:textAlign`).
    public var textAlign: String? { properties["tts:textAlign"] }

    /// Text direction (`tts:direction`).
    public var direction: String? { properties["tts:direction"] }

    /// Writing mode (`tts:writingMode`).
    public var writingMode: String? { properties["tts:writingMode"] }

    /// Opacity (`tts:opacity`).
    public var opacity: String? { properties["tts:opacity"] }

    /// Text decoration (`tts:textDecoration`).
    public var textDecoration: String? { properties["tts:textDecoration"] }
}
