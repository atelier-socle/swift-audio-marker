/// A single timestamped line of synchronized text.
public struct LyricLine: Sendable, Hashable {

    /// The time at which this line should be displayed.
    public let time: AudioTimestamp

    /// The text content.
    public let text: String

    /// Creates a timestamped lyric line.
    /// - Parameters:
    ///   - time: The display time for this line.
    ///   - text: The text content.
    public init(time: AudioTimestamp, text: String) {
        self.time = time
        self.text = text
    }
}
