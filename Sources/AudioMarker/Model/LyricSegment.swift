/// A timed segment within a lyric line, enabling word-level (karaoke) timing.
///
/// Each segment represents a portion of text (typically a word or syllable)
/// with its own timing, allowing karaoke-style highlighting.
public struct LyricSegment: Sendable, Hashable {

    /// Start time of this segment.
    public let startTime: AudioTimestamp

    /// End time of this segment.
    public let endTime: AudioTimestamp

    /// The text content of this segment.
    public let text: String

    /// Optional style identifier (for TTML round-trip).
    public let styleID: String?

    /// Creates a timed lyric segment.
    /// - Parameters:
    ///   - startTime: Start time of this segment.
    ///   - endTime: End time of this segment.
    ///   - text: The text content.
    ///   - styleID: Optional style identifier. Defaults to `nil`.
    public init(
        startTime: AudioTimestamp,
        endTime: AudioTimestamp,
        text: String,
        styleID: String? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.styleID = styleID
    }
}
