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

/// High-level errors from AudioMarker operations.
public enum AudioMarkerError: Error, Sendable, Hashable, LocalizedError {
    /// The audio format could not be detected.
    case unknownFormat(String)
    /// The detected format is not supported for this operation.
    case unsupportedFormat(AudioFormat, operation: String)
    /// The file could not be read.
    case readFailed(String)
    /// The file could not be written.
    case writeFailed(String)
    /// Validation failed with blocking errors.
    case validationFailed([ValidationIssue])

    public var errorDescription: String? {
        switch self {
        case .unknownFormat(let path):
            "Unknown audio format for file: \(path)."
        case .unsupportedFormat(let format, let operation):
            "Format \(format.rawValue) is not supported for \(operation)."
        case .readFailed(let detail):
            "Read failed: \(detail)"
        case .writeFailed(let detail):
            "Write failed: \(detail)"
        case .validationFailed(let issues):
            "Validation failed with \(issues.count) error(s)."
        }
    }
}
