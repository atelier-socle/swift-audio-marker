/// Complete parsed information from an audio file.
public struct AudioFileInfo: Sendable {

    /// Global metadata (title, artist, artwork, etc.).
    public var metadata: AudioMetadata

    /// Chapter markers.
    public var chapters: ChapterList

    /// Audio duration.
    public var duration: AudioTimestamp?

    /// Creates audio file info.
    /// - Parameters:
    ///   - metadata: Global metadata. Defaults to empty metadata.
    ///   - chapters: Chapter markers. Defaults to empty list.
    ///   - duration: Audio duration. Defaults to `nil`.
    public init(
        metadata: AudioMetadata = AudioMetadata(),
        chapters: ChapterList = ChapterList(),
        duration: AudioTimestamp? = nil
    ) {
        self.metadata = metadata
        self.chapters = chapters
        self.duration = duration
    }
}
