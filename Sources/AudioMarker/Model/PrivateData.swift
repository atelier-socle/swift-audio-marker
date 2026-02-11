import Foundation

/// Private data frame (ID3v2 PRIV), used by services like Spotify or Apple Music.
public struct PrivateData: Sendable, Hashable {

    /// Owner identifier (e.g., `"com.spotify.track"`).
    public let owner: String

    /// Raw private data bytes.
    public let data: Data

    /// Creates a private data entry.
    /// - Parameters:
    ///   - owner: Owner identifier string.
    ///   - data: Raw private data bytes.
    public init(owner: String, data: Data) {
        self.owner = owner
        self.data = data
    }
}
