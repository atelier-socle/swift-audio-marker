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

/// Validates that a title is present in the metadata.
public struct MetadataTitleRule: ValidationRule {

    public let name = "Metadata Title"

    public init() {}

    public func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        let title = info.metadata.title
        if title == nil || title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            return [
                ValidationIssue(
                    severity: .warning,
                    message: "Audio file has no title.",
                    context: "metadata.title"
                )
            ]
        }
        return []
    }
}

/// Validates that artwork data is a recognized format (JPEG or PNG) if present.
public struct ArtworkFormatRule: ValidationRule {

    public let name = "Artwork Format"

    public init() {}

    public func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        guard let artwork = info.metadata.artwork else { return [] }
        let detected = ArtworkFormat.detect(from: artwork.data)
        if detected == nil {
            return [
                ValidationIssue(
                    severity: .error,
                    message: "Artwork data is not a recognized format (JPEG or PNG).",
                    context: "metadata.artwork"
                )
            ]
        }
        return []
    }
}

/// Validates that the year is reasonable (1900-2100) if present.
public struct MetadataYearRule: ValidationRule {

    public let name = "Metadata Year"

    public init() {}

    public func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        guard let year = info.metadata.year else { return [] }
        if year < 1900 || year > 2100 {
            return [
                ValidationIssue(
                    severity: .warning,
                    message: "Year \(year) is outside the expected range (1900-2100).",
                    context: "metadata.year"
                )
            ]
        }
        return []
    }
}

/// Validates that the language code is a valid ISO 639-2 3-letter code if present.
public struct LanguageCodeRule: ValidationRule {

    public let name = "Language Code"

    public init() {}

    public func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        guard let language = info.metadata.language else { return [] }
        let isValid = language.count == 3 && language.allSatisfy(\.isLetter)
        if !isValid {
            return [
                ValidationIssue(
                    severity: .error,
                    message: "Language code \"\(language)\" is not a valid ISO 639-2 3-letter code.",
                    context: "metadata.language"
                )
            ]
        }
        return []
    }
}

/// Validates the rating value if present.
///
/// In ID3v2 POPM, a rating of 0 means "unrated". This rule emits a warning
/// when rating is 0 to suggest using `nil` instead.
public struct RatingRangeRule: ValidationRule {

    public let name = "Rating Range"

    public init() {}

    public func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        guard let rating = info.metadata.rating else { return [] }
        if rating == 0 {
            return [
                ValidationIssue(
                    severity: .warning,
                    message: "Rating is 0 (unrated in ID3v2 POPM). Consider using nil for no rating.",
                    context: "metadata.rating"
                )
            ]
        }
        return []
    }
}
