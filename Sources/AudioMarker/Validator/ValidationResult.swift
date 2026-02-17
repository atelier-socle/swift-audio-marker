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


/// The outcome of a validation pass.
public struct ValidationResult: Sendable {

    /// All issues found during validation.
    public let issues: [ValidationIssue]

    /// Whether validation passed (no errors; warnings are acceptable).
    public var isValid: Bool {
        issues.allSatisfy { $0.severity != .error }
    }

    /// Only the errors.
    public var errors: [ValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    /// Only the warnings.
    public var warnings: [ValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    /// Creates a validation result.
    /// - Parameter issues: The issues found during validation. Defaults to empty.
    public init(issues: [ValidationIssue] = []) {
        self.issues = issues
    }

    /// A result with no issues.
    public static let valid = ValidationResult()
}
