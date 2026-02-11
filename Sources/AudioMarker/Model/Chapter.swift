import Foundation

/// A single chapter marker within an audio file.
public struct Chapter: Sendable, Hashable, Identifiable {

    /// Unique identifier for this chapter.
    public let id: UUID

    /// Chapter start time.
    public let start: AudioTimestamp

    /// Chapter end time (`nil` means calculated from next chapter or audio duration).
    public var end: AudioTimestamp?

    /// Chapter title.
    public let title: String

    /// Optional URL associated with this chapter.
    public let url: URL?

    /// Optional per-chapter artwork.
    public let artwork: Artwork?

    /// Creates a new chapter marker.
    /// - Parameters:
    ///   - start: The start time of the chapter.
    ///   - title: The chapter title (should not be empty).
    ///   - end: Optional end time. If `nil`, calculated from next chapter or audio duration.
    ///   - url: Optional URL associated with the chapter.
    ///   - artwork: Optional per-chapter artwork.
    public init(
        start: AudioTimestamp,
        title: String,
        end: AudioTimestamp? = nil,
        url: URL? = nil,
        artwork: Artwork? = nil
    ) {
        self.id = UUID()
        self.start = start
        self.title = title
        self.end = end
        self.url = url
        self.artwork = artwork
    }
}
