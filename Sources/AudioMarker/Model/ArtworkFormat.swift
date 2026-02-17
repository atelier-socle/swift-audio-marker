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

/// Supported image formats for embedded artwork.
public enum ArtworkFormat: String, Sendable, Hashable, CaseIterable {
    case jpeg
    case png

    /// The MIME type string (e.g., `"image/jpeg"`).
    public var mimeType: String {
        switch self {
        case .jpeg: return "image/jpeg"
        case .png: return "image/png"
        }
    }

    /// Detects format from raw image data by checking magic bytes.
    /// - Parameter data: Raw image bytes.
    /// - Returns: The detected format, or `nil` if unrecognized.
    public static func detect(from data: Data) -> ArtworkFormat? {
        guard data.count >= 4 else { return nil }

        // JPEG: starts with FF D8 FF
        if data.count >= 3,
            data[data.startIndex] == 0xFF,
            data[data.startIndex + 1] == 0xD8,
            data[data.startIndex + 2] == 0xFF
        {
            return .jpeg
        }

        // PNG: starts with 89 50 4E 47 (‰PNG)
        if data[data.startIndex] == 0x89,
            data[data.startIndex + 1] == 0x50,
            data[data.startIndex + 2] == 0x4E,
            data[data.startIndex + 3] == 0x47
        {
            return .png
        }

        return nil
    }
}
