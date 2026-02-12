/// A single timestamped line of synchronized text.
public struct LyricLine: Sendable, Hashable {

    /// The time at which this line should be displayed.
    public let time: AudioTimestamp

    /// The text content.
    public let text: String

    /// Optional word-level timing segments for karaoke display.
    ///
    /// When present, ``text`` contains the full line and ``segments`` provides
    /// per-word timing. When empty, the line has no word-level timing.
    public let segments: [LyricSegment]

    /// Optional speaker or agent name for this line.
    ///
    /// Used to track who speaks a line (e.g., narrator, character).
    /// Preserved through TTML round-trips via `ttm:agent` metadata.
    public let speaker: String?

    /// Creates a timestamped lyric line.
    /// - Parameters:
    ///   - time: The display time for this line.
    ///   - text: The text content.
    ///   - segments: Word-level timing segments. Defaults to empty.
    ///   - speaker: Speaker or agent name. Defaults to `nil`.
    public init(
        time: AudioTimestamp,
        text: String,
        segments: [LyricSegment] = [],
        speaker: String? = nil
    ) {
        self.time = time
        self.text = text
        self.segments = segments
        self.speaker = speaker
    }

    /// Whether this line has word-level (karaoke) timing.
    public var isKaraoke: Bool {
        !segments.isEmpty
    }

    /// Whether this line has a speaker attribution.
    public var hasSpeaker: Bool {
        speaker != nil
    }
}
