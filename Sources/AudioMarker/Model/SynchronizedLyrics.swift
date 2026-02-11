/// Synchronized (timestamped) lyrics or text, corresponding to ID3v2 SYLT frames.
public struct SynchronizedLyrics: Sendable, Hashable {

    /// ISO 639-2 language code (3 characters, e.g., `"eng"`, `"fra"`).
    public let language: String

    /// The type of synchronized content.
    public let contentType: ContentType

    /// Optional content descriptor.
    public let descriptor: String

    /// Timestamped lines, ordered by time.
    public var lines: [LyricLine]

    /// Creates synchronized lyrics.
    /// - Parameters:
    ///   - language: ISO 639-2 language code (3 characters).
    ///   - contentType: The type of content. Defaults to ``ContentType/lyrics``.
    ///   - descriptor: Optional content descriptor. Defaults to empty string.
    ///   - lines: Timestamped lines. Defaults to empty array.
    public init(
        language: String,
        contentType: ContentType = .lyrics,
        descriptor: String = "",
        lines: [LyricLine] = []
    ) {
        self.language = language
        self.contentType = contentType
        self.descriptor = descriptor
        self.lines = lines
    }

    /// Returns a copy with lines sorted by time in ascending order.
    /// - Returns: A new ``SynchronizedLyrics`` with sorted lines.
    public func sorted() -> SynchronizedLyrics {
        var copy = self
        copy.lines.sort { $0.time < $1.time }
        return copy
    }
}
