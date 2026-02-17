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

/// Errors that can occur during MP4 file reading or writing.
public enum MP4Error: Error, Sendable, LocalizedError {

    /// The file is not a valid MP4/M4A/M4B file.
    case invalidFile(String)

    /// A required atom was not found.
    case atomNotFound(String)

    /// An atom has invalid or corrupt data.
    case invalidAtom(type: String, reason: String)

    /// The file type is not supported.
    case unsupportedFileType(String)

    /// The atom data is truncated or corrupt.
    case truncatedData(expected: Int, available: Int)

    /// A write operation failed.
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFile(let reason):
            return "Invalid MP4 file: \(reason)."
        case .atomNotFound(let type):
            return "Required MP4 atom not found: \"\(type)\"."
        case .invalidAtom(let type, let reason):
            return "Invalid MP4 atom \"\(type)\": \(reason)."
        case .unsupportedFileType(let fileType):
            return "Unsupported MP4 file type: \"\(fileType)\"."
        case .truncatedData(let expected, let available):
            return "Truncated MP4 data: expected \(expected) bytes, \(available) available."
        case .writeFailed(let reason):
            return "MP4 write failed: \(reason)."
        }
    }
}
