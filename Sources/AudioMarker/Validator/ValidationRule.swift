/// A rule that validates audio file data.
public protocol ValidationRule: Sendable {

    /// Human-readable name of this rule.
    var name: String { get }

    /// Validates the given audio file info and returns any issues found.
    /// - Parameter info: The audio file data to validate.
    /// - Returns: An array of issues (empty if valid).
    func validate(_ info: AudioFileInfo) -> [ValidationIssue]
}
