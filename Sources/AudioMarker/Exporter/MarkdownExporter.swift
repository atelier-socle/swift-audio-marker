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

/// Exports chapters to Markdown format (export only).
///
/// Output format:
/// ```markdown
/// 1. **00:00:00** - Introduction
/// 2. **00:05:30** - Main Topic
/// ```
public struct MarkdownExporter: Sendable {

    /// Creates a Markdown exporter.
    public init() {}

    // MARK: - Export

    /// Exports chapters to a numbered Markdown list.
    /// - Parameter chapters: The chapters to export.
    /// - Returns: A Markdown string with bold timestamps and em-dash separators.
    public func export(_ chapters: ChapterList) -> String {
        var lines: [String] = []
        for (index, chapter) in chapters.enumerated() {
            let timestamp = chapter.start.shortDescription
            lines.append("\(index + 1). **\(timestamp)** \u{2014} \(chapter.title)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
