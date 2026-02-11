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
