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

    /// Creates a timestamped lyric line.
    /// - Parameters:
    ///   - time: The display time for this line.
    ///   - text: The text content.
    public init(time: AudioTimestamp, text: String) {
        self.time = time
        self.text = text
        self.segments = []
    }

    /// Creates a timestamped lyric line with karaoke segments.
    /// - Parameters:
    ///   - time: The display time for this line.
    ///   - text: The full text content.
    ///   - segments: Word-level timing segments.
    public init(time: AudioTimestamp, text: String, segments: [LyricSegment]) {
        self.time = time
        self.text = text
        self.segments = segments
    }

    /// Whether this line has word-level (karaoke) timing.
    public var isKaraoke: Bool {
        !segments.isEmpty
    }
}
