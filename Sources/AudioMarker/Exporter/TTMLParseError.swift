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

/// Errors that can occur during TTML parsing.
public enum TTMLParseError: Error, Sendable, LocalizedError {

    /// The input is not valid XML.
    case invalidXML(String)

    /// The XML is not a valid TTML document (missing `<tt>` root).
    case notTTML

    /// A time expression could not be parsed.
    case invalidTimeExpression(String)

    /// A required attribute is missing.
    case missingAttribute(element: String, attribute: String)

    /// A `<p>` element has no begin time.
    case missingTiming(element: String)

    public var errorDescription: String? {
        switch self {
        case .invalidXML(let detail):
            return "Invalid XML: \(detail)."
        case .notTTML:
            return "Not a valid TTML document: missing <tt> root element."
        case .invalidTimeExpression(let expression):
            return "Invalid TTML time expression: \"\(expression)\"."
        case .missingAttribute(let element, let attribute):
            return "Missing required attribute \"\(attribute)\" on <\(element)>."
        case .missingTiming(let element):
            return "Missing timing (begin attribute) on <\(element)>."
        }
    }
}

// MARK: - Hashable

extension TTMLParseError: Hashable {

    public static func == (lhs: TTMLParseError, rhs: TTMLParseError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidXML(let a), .invalidXML(let b)): return a == b
        case (.notTTML, .notTTML): return true
        case (.invalidTimeExpression(let a), .invalidTimeExpression(let b)): return a == b
        case (.missingAttribute(let ae, let aa), .missingAttribute(let be, let ba)):
            return ae == be && aa == ba
        case (.missingTiming(let a), .missingTiming(let b)): return a == b
        default: return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .invalidXML(let detail):
            hasher.combine(0)
            hasher.combine(detail)
        case .notTTML:
            hasher.combine(1)
        case .invalidTimeExpression(let expr):
            hasher.combine(2)
            hasher.combine(expr)
        case .missingAttribute(let element, let attribute):
            hasher.combine(3)
            hasher.combine(element)
            hasher.combine(attribute)
        case .missingTiming(let element):
            hasher.combine(4)
            hasher.combine(element)
        }
    }
}
