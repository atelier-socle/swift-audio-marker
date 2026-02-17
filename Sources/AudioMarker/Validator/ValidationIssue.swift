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


/// Severity level for a validation finding.
public enum ValidationSeverity: Sendable, Hashable {
    /// A non-blocking finding that does not prevent writing.
    case warning
    /// A blocking finding that must be resolved before writing.
    case error
}

/// A single validation finding with context.
public struct ValidationIssue: Sendable, Hashable, CustomStringConvertible {

    /// Severity of this issue.
    public let severity: ValidationSeverity

    /// Human-readable description of the problem.
    public let message: String

    /// Optional context: which field, index, or element triggered the issue.
    public let context: String?

    /// Creates a validation issue.
    /// - Parameters:
    ///   - severity: The severity level.
    ///   - message: A human-readable description of the problem.
    ///   - context: Optional context about the source of the issue.
    public init(severity: ValidationSeverity, message: String, context: String? = nil) {
        self.severity = severity
        self.message = message
        self.context = context
    }

    public var description: String {
        let prefix = severity == .error ? "ERROR" : "WARNING"
        if let context {
            return "[\(prefix)] \(message) (\(context))"
        }
        return "[\(prefix)] \(message)"
    }
}
