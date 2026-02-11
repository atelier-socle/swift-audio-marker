import Foundation

/// Unique file identifier (ID3v2 UFID), used for podcast GUIDs and similar identifiers.
public struct UniqueFileIdentifier: Sendable, Hashable {

    /// Owner identifier (e.g., `"http://www.id3.org/dummy/ufid.html"`).
    public let owner: String

    /// Identifier bytes.
    public let identifier: Data

    /// Creates a unique file identifier.
    /// - Parameters:
    ///   - owner: Owner identifier string.
    ///   - identifier: Identifier bytes.
    public init(owner: String, identifier: Data) {
        self.owner = owner
        self.identifier = identifier
    }
}
