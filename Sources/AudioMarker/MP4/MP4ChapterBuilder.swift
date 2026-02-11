import Foundation

/// Builds Nero chapter atoms for MP4 files.
///
/// Produces `chpl` atoms from a ``ChapterList``, using the Nero chapter
/// format with timestamps in 100-nanosecond units.
public struct MP4ChapterBuilder: Sendable {

    private let atomBuilder = MP4AtomBuilder()

    /// Creates an MP4 chapter builder.
    public init() {}

    // MARK: - Public API

    /// Builds a Nero chapter list atom (`chpl`).
    ///
    /// Binary format:
    /// - 4 bytes: version (0x01000000)
    /// - 4 bytes: reserved (0x00000000)
    /// - 1 byte: chapter count
    /// - Per chapter: UInt64 start time (100ns units) + UInt8 title length + title (UTF-8)
    ///
    /// - Parameter chapters: The chapter list.
    /// - Returns: Complete `chpl` atom data, or `nil` if chapters is empty.
    public func buildNeroChapters(from chapters: ChapterList) -> Data? {
        guard !chapters.isEmpty else { return nil }

        let count = min(chapters.count, 255)
        var payload = BinaryWriter()
        payload.writeUInt32(0x0100_0000)  // version
        payload.writeUInt32(0)  // reserved
        payload.writeUInt8(UInt8(count))

        for index in 0..<count {
            let chapter = chapters[index]
            let timestamp100ns = UInt64(chapter.start.timeInterval * 10_000_000.0)
            payload.writeUInt64(timestamp100ns)

            let titleData = Data(chapter.title.utf8)
            let titleLength = min(titleData.count, 255)
            payload.writeUInt8(UInt8(titleLength))
            payload.writeData(titleData.prefix(titleLength))
        }

        return atomBuilder.buildAtom(type: "chpl", data: payload.data)
    }

    /// Builds a `chpl` atom from a chapter list.
    ///
    /// Convenience wrapper around ``buildNeroChapters(from:)``.
    /// - Parameter chapters: The chapter list.
    /// - Returns: Complete `chpl` atom data, or `nil` if chapters is empty.
    public func buildChplAtom(from chapters: ChapterList) -> Data? {
        buildNeroChapters(from: chapters)
    }
}
