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


/// Validates audio file data against a set of rules.
public struct AudioValidator: Sendable {

    /// The rules to apply during validation.
    public let rules: [any ValidationRule]

    /// Creates a validator with the default set of built-in rules.
    public init() {
        self.rules = Self.defaultRules
    }

    /// Creates a validator with custom rules.
    /// - Parameter rules: The validation rules to apply.
    public init(rules: [any ValidationRule]) {
        self.rules = rules
    }

    /// Validates the given audio file info against all rules.
    /// - Parameter info: The audio file data to validate.
    /// - Returns: A result containing all issues found.
    public func validate(_ info: AudioFileInfo) -> ValidationResult {
        let allIssues = rules.flatMap { $0.validate(info) }
        return ValidationResult(issues: allIssues)
    }

    /// The default set of built-in validation rules.
    public static var defaultRules: [any ValidationRule] {
        [
            ChapterOrderRule(),
            ChapterOverlapRule(),
            ChapterTitleRule(),
            ChapterBoundsRule(),
            ChapterNonNegativeRule(),
            MetadataTitleRule(),
            ArtworkFormatRule(),
            MetadataYearRule(),
            LanguageCodeRule(),
            RatingRangeRule()
        ]
    }
}
