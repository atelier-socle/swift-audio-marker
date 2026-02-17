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

// MARK: - ArtworkError

/// Errors that can occur when creating an ``Artwork`` instance.
public enum ArtworkError: Error, LocalizedError, Sendable, Hashable {
    /// The image data does not match any recognized format (JPEG or PNG).
    case unrecognizedFormat
    /// The file at the given URL could not be found or read.
    case fileNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .unrecognizedFormat:
            return "Unrecognized image format. Only JPEG and PNG are supported."
        case .fileNotFound(let path):
            return "File not found at path: \"\(path)\"."
        }
    }
}

// MARK: - Artwork

/// Embedded image data with format information.
public struct Artwork: Sendable, Hashable {

    /// Raw image bytes.
    public let data: Data

    /// Image format (JPEG or PNG).
    public let format: ArtworkFormat

    /// Creates artwork with explicit data and format.
    /// - Parameters:
    ///   - data: Raw image bytes.
    ///   - format: The image format.
    public init(data: Data, format: ArtworkFormat) {
        self.data = data
        self.format = format
    }

    /// Creates artwork from raw data, auto-detecting the format from magic bytes.
    /// - Parameter data: Raw image bytes.
    /// - Throws: ``ArtworkError/unrecognizedFormat`` if detection fails.
    public init(data: Data) throws {
        guard let detected = ArtworkFormat.detect(from: data) else {
            throw ArtworkError.unrecognizedFormat
        }
        self.data = data
        self.format = detected
    }

    /// Creates artwork by loading data from a file URL.
    /// - Parameter url: The file URL to read from.
    /// - Throws: ``ArtworkError/fileNotFound(_:)`` if the file cannot be read,
    ///           or ``ArtworkError/unrecognizedFormat`` if the format is not recognized.
    public init(contentsOf url: URL) throws {
        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            throw ArtworkError.fileNotFound(url.path)
        }
        guard let detected = ArtworkFormat.detect(from: fileData) else {
            throw ArtworkError.unrecognizedFormat
        }
        self.data = fileData
        self.format = detected
    }
}
