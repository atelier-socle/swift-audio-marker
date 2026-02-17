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

/// Errors that can occur during chapter export or import.
public enum ExportError: Error, LocalizedError, Sendable, Hashable {
    /// The export format does not support importing.
    case importNotSupported(String)
    /// The input data is malformed or cannot be parsed.
    case invalidData(String)
    /// The input string is malformed or cannot be parsed.
    case invalidFormat(String)
    /// An I/O error occurred during file operations.
    case ioError(String)
    /// The operation is not supported for this format.
    case unsupportedFormat(String)

    public var errorDescription: String? {
        switch self {
        case .importNotSupported(let format):
            "Import is not supported for \(format) format."
        case .invalidData(let detail):
            "Invalid data: \(detail)."
        case .invalidFormat(let detail):
            "Invalid format: \(detail)."
        case .ioError(let detail):
            "I/O error: \(detail)."
        case .unsupportedFormat(let detail):
            "Unsupported format: \(detail)."
        }
    }
}
