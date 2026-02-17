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

/// Exports and imports chapters in Podlove Simple Chapters JSON format.
///
/// Output format:
/// ```json
/// {
///   "version": "1.2",
///   "chapters": [
///     { "start": "HH:MM:SS.mmm", "title": "..." }
///   ]
/// }
/// ```
public struct PodloveJSONExporter: Sendable {

    /// Creates a Podlove JSON exporter.
    public init() {}

    // MARK: - Export

    /// Exports chapters to Podlove Simple Chapters JSON.
    /// - Parameter chapters: The chapters to export.
    /// - Returns: A pretty-printed JSON string.
    /// - Throws: ``ExportError/invalidData(_:)`` if encoding fails.
    public func export(_ chapters: ChapterList) throws -> String {
        var chapterArray: [[String: Any]] = []
        for chapter in chapters {
            var dict: [String: Any] = [
                "start": chapter.start.description,
                "title": chapter.title
            ]
            if let url = chapter.url {
                dict["href"] = url.absoluteString
            }
            chapterArray.append(dict)
        }

        let root: [String: Any] = [
            "version": "1.2",
            "chapters": chapterArray
        ]

        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])

        guard let string = String(data: data, encoding: .utf8) else {
            throw ExportError.invalidData("Failed to encode JSON as UTF-8.")
        }
        return string
    }

    // MARK: - Import

    /// Imports chapters from Podlove Simple Chapters JSON.
    /// - Parameter string: The JSON string to parse.
    /// - Returns: A ``ChapterList`` with the parsed chapters.
    /// - Throws: ``ExportError`` if the JSON is malformed.
    public func importChapters(from string: String) throws -> ChapterList {
        guard let data = string.data(using: .utf8) else {
            throw ExportError.invalidData("Failed to decode string as UTF-8.")
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ExportError.invalidFormat("Invalid JSON: \(error.localizedDescription)")
        }

        guard let root = object as? [String: Any] else {
            throw ExportError.invalidFormat("Expected a JSON object at root level.")
        }
        guard let chaptersArray = root["chapters"] as? [[String: Any]] else {
            throw ExportError.invalidFormat("Missing or invalid 'chapters' array.")
        }

        var chapters = ChapterList()
        for dict in chaptersArray {
            guard let startString = dict["start"] as? String else {
                throw ExportError.invalidFormat("Missing 'start' in chapter entry.")
            }
            guard let title = dict["title"] as? String else {
                throw ExportError.invalidFormat("Missing 'title' in chapter entry.")
            }
            let start = try AudioTimestamp(string: startString)
            let url: URL? = (dict["href"] as? String).flatMap { URL(string: $0) }
            chapters.append(Chapter(start: start, title: title, url: url))
        }
        return chapters
    }
}
