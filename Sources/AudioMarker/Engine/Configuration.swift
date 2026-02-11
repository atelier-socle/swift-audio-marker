import Foundation

/// Configuration for ``AudioMarkerEngine``.
public struct Configuration: Sendable, Hashable {

    /// The default configuration.
    public static let `default` = Configuration()

    /// ID3v2 version to use when writing MP3 files.
    public var id3Version: ID3Version

    /// Whether to validate before writing.
    public var validateBeforeWriting: Bool

    /// Whether to preserve unknown frames/atoms during modify.
    public var preserveUnknownData: Bool

    /// Padding size for ID3v2 tags (bytes).
    public var id3PaddingSize: Int

    /// Creates a configuration.
    /// - Parameters:
    ///   - id3Version: ID3v2 version for MP3 writes. Defaults to v2.3.
    ///   - validateBeforeWriting: Whether to validate before writing. Defaults to `true`.
    ///   - preserveUnknownData: Whether to preserve unknown data during modify. Defaults to `true`.
    ///   - id3PaddingSize: ID3 tag padding in bytes. Defaults to 2048.
    public init(
        id3Version: ID3Version = .v2_3,
        validateBeforeWriting: Bool = true,
        preserveUnknownData: Bool = true,
        id3PaddingSize: Int = 2048
    ) {
        self.id3Version = id3Version
        self.validateBeforeWriting = validateBeforeWriting
        self.preserveUnknownData = preserveUnknownData
        self.id3PaddingSize = id3PaddingSize
    }
}
