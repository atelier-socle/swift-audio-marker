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


/// Validates that chapter start times are strictly increasing.
public struct ChapterOrderRule: ValidationRule {

    public let name = "Chapter Order"

    public init() {}

    public func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        let chapters = Array(info.chapters)
        guard chapters.count > 1 else { return [] }

        var issues: [ValidationIssue] = []
        for index in 1..<chapters.count {
            let previous = chapters[index - 1]
            let current = chapters[index]
            if current.start <= previous.start {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        message:
                            "Chapter \"\(current.title)\" start (\(current.start)) is not after previous chapter \"\(previous.title)\" start (\(previous.start)).",
                        context: "chapter[\(index)]"
                    )
                )
            }
        }
        return issues
    }
}

/// Validates that no chapters overlap (start of N+1 > end of N when ends are set).
public struct ChapterOverlapRule: ValidationRule {

    public let name = "Chapter Overlap"

    public init() {}

    public func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        let chapters = Array(info.chapters)
        guard chapters.count > 1 else { return [] }

        var issues: [ValidationIssue] = []
        for index in 0..<(chapters.count - 1) {
            let current = chapters[index]
            let next = chapters[index + 1]
            guard let end = current.end else { continue }
            if next.start < end {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        message:
                            "Chapter \"\(current.title)\" end (\(end)) overlaps with next chapter \"\(next.title)\" start (\(next.start)).",
                        context: "chapter[\(index)]"
                    )
                )
            }
        }
        return issues
    }
}

/// Validates that all chapter titles are non-empty.
public struct ChapterTitleRule: ValidationRule {

    public let name = "Chapter Title"

    public init() {}

    public func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for (index, chapter) in info.chapters.enumerated() {
            let trimmed = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                issues.append(
                    ValidationIssue(
                        severity: .error,
                        message: "Chapter title is empty or whitespace-only.",
                        context: "chapter[\(index)]"
                    )
                )
            }
        }
        return issues
    }
}

/// Validates that all chapter timestamps are within the audio duration (if known).
public struct ChapterBoundsRule: ValidationRule {

    public let name = "Chapter Bounds"

    public init() {}

    public func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        guard let duration = info.duration else { return [] }

        var issues: [ValidationIssue] = []
        for (index, chapter) in info.chapters.enumerated() where chapter.start > duration {
            issues.append(
                ValidationIssue(
                    severity: .error,
                    message:
                        "Chapter \"\(chapter.title)\" start (\(chapter.start)) exceeds audio duration (\(duration)).",
                    context: "chapter[\(index)]"
                )
            )
        }
        return issues
    }
}

/// Validates that chapter start times are not negative.
public struct ChapterNonNegativeRule: ValidationRule {

    public let name = "Chapter Non-Negative"

    public init() {}

    public func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for (index, chapter) in info.chapters.enumerated() where chapter.start.timeInterval < 0 {
            issues.append(
                ValidationIssue(
                    severity: .error,
                    message: "Chapter \"\(chapter.title)\" has a negative start time (\(chapter.start)).",
                    context: "chapter[\(index)]"
                )
            )
        }
        return issues
    }
}
