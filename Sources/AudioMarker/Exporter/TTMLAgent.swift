/// A TTML metadata agent (narrator, character, etc.) for accessibility.
///
/// Captures `<ttm:agent>` elements from a TTML document.
public struct TTMLAgent: Sendable, Hashable {

    /// Agent identifier (`xml:id`).
    public let id: String

    /// Agent type (`"person"`, `"character"`, `"group"`, etc.).
    public let type: String?

    /// Agent name (from `<ttm:name>` child element).
    public let name: String?

    /// Creates a TTML agent.
    /// - Parameters:
    ///   - id: Agent identifier.
    ///   - type: Agent type. Defaults to `nil`.
    ///   - name: Agent name. Defaults to `nil`.
    public init(id: String, type: String? = nil, name: String? = nil) {
        self.id = id
        self.type = type
        self.name = name
    }
}
