/// A TTML display region defining where text appears on screen.
///
/// Captures `<region>` elements from a TTML document for round-trip preservation.
public struct TTMLRegion: Sendable, Hashable {

    /// Region identifier (`xml:id`).
    public let id: String

    /// Origin position (`tts:origin`, e.g., `"10% 80%"`).
    public let origin: String?

    /// Extent/size (`tts:extent`, e.g., `"80% 20%"`).
    public let extent: String?

    /// Display alignment (`tts:displayAlign`).
    public let displayAlign: String?

    /// Additional style properties.
    public let properties: [String: String]

    /// Creates a TTML region.
    /// - Parameters:
    ///   - id: Region identifier.
    ///   - origin: Origin position. Defaults to `nil`.
    ///   - extent: Extent/size. Defaults to `nil`.
    ///   - displayAlign: Display alignment. Defaults to `nil`.
    ///   - properties: Additional properties. Defaults to empty.
    public init(
        id: String,
        origin: String? = nil,
        extent: String? = nil,
        displayAlign: String? = nil,
        properties: [String: String] = [:]
    ) {
        self.id = id
        self.origin = origin
        self.extent = extent
        self.displayAlign = displayAlign
        self.properties = properties
    }
}
