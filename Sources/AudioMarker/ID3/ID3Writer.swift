import Foundation

/// Writes ID3v2 tags to MP3 files using streaming I/O.
///
/// Supports writing new tags, modifying existing tags (preserving unknown frames),
/// and stripping tags entirely. Audio data is never loaded into memory — only tag
/// data (typically < 1 MB) is held in memory while audio data is streamed via
/// ``FileReader`` and ``FileWriter``.
public struct ID3Writer: Sendable {

    /// Creates an ID3v2 writer.
    public init() {}

    // MARK: - Public API

    /// Writes a new ID3v2 tag to an MP3 file, replacing any existing tag.
    /// - Parameters:
    ///   - info: The metadata and chapters to write.
    ///   - url: The MP3 file URL.
    ///   - version: The ID3v2 version. Defaults to v2.3.
    /// - Throws: ``ID3Error``, ``StreamingError``
    public func write(
        _ info: AudioFileInfo,
        to url: URL,
        version: ID3Version = .v2_3
    ) throws {
        let tagBuilder = ID3TagBuilder(version: version)
        let (existingHeader, audioOffset) = try readExistingTagInfo(url)

        let existingSpace = existingHeader.map { Int(10 + $0.tagSize) } ?? 0
        let minTagData = tagBuilder.buildTag(from: info, padding: 0)
        let minTagSize = minTagData.count

        if existingSpace >= minTagSize {
            let padding = existingSpace - minTagSize
            let tagData = tagBuilder.buildTag(from: info, padding: padding)
            try writeInPlace(tagData: tagData, to: url)
        } else {
            let tagData = tagBuilder.buildTag(from: info)
            try writeWithTempFile(tagData: tagData, audioOffset: audioOffset, source: url)
        }
    }

    /// Modifies an existing ID3v2 tag, preserving unknown frames.
    ///
    /// If the file has no existing tag, behaves like ``write(_:to:version:)``.
    /// - Parameters:
    ///   - info: The new metadata and chapters.
    ///   - url: The MP3 file URL.
    ///   - version: The ID3v2 version. If `nil`, uses the existing tag's version or v2.3.
    /// - Throws: ``ID3Error``, ``StreamingError``
    public func modify(
        _ info: AudioFileInfo,
        in url: URL,
        version: ID3Version? = nil
    ) throws {
        let unknownFrames: [ID3Frame]
        let resolvedVersion: ID3Version

        do {
            let reader = ID3Reader()
            let (header, frames) = try reader.readRawFrames(from: url)
            resolvedVersion = version ?? header.version
            unknownFrames = frames.filter { frame in
                ID3FrameID(rawValue: frame.frameID) == nil
            }
        } catch is ID3Error {
            try write(info, to: url, version: version ?? .v2_3)
            return
        }

        let tagBuilder = ID3TagBuilder(version: resolvedVersion)
        let (existingHeader, audioOffset) = try readExistingTagInfo(url)

        let existingSpace = existingHeader.map { Int(10 + $0.tagSize) } ?? 0
        let minTagData = tagBuilder.buildTag(from: info, unknownFrames: unknownFrames, padding: 0)
        let minTagSize = minTagData.count

        if existingSpace >= minTagSize {
            let padding = existingSpace - minTagSize
            let tagData = tagBuilder.buildTag(
                from: info, unknownFrames: unknownFrames, padding: padding)
            try writeInPlace(tagData: tagData, to: url)
        } else {
            let tagData = tagBuilder.buildTag(from: info, unknownFrames: unknownFrames)
            try writeWithTempFile(tagData: tagData, audioOffset: audioOffset, source: url)
        }
    }

    /// Strips metadata from an MP3 file while preserving chapters.
    ///
    /// Removes the ID3v2 tag and rewrites it with only chapter frames
    /// if any exist. Chapters are structural data, not metadata — use
    /// ``AudioMarkerEngine/writeChapters(_:to:)`` with an empty
    /// ``ChapterList`` to remove them explicitly. If the file has no tag, this is a no-op.
    /// - Parameter url: The MP3 file URL.
    /// - Throws: ``ID3Error``, ``StreamingError``
    public func stripTag(from url: URL) throws {
        let (existingHeader, audioOffset) = try readExistingTagInfo(url)

        guard let header = existingHeader else { return }

        // Read existing chapters to preserve them.
        let reader = ID3Reader()
        let existingInfo: AudioFileInfo
        do {
            existingInfo = try reader.read(from: url)
        } catch {
            existingInfo = AudioFileInfo()
        }

        if existingInfo.chapters.isEmpty {
            try writeWithTempFile(tagData: Data(), audioOffset: audioOffset, source: url)
        } else {
            var chaptersOnly = AudioFileInfo()
            chaptersOnly.chapters = existingInfo.chapters
            let tagBuilder = ID3TagBuilder(version: header.version)
            let tagData = tagBuilder.buildTag(from: chaptersOnly)
            try writeWithTempFile(tagData: tagData, audioOffset: audioOffset, source: url)
        }
    }
}

// MARK: - Reading Existing Tag Info

extension ID3Writer {

    private func readExistingTagInfo(
        _ url: URL
    ) throws -> (header: ID3Header?, audioOffset: UInt64) {
        let fileReader = try FileReader(url: url)
        defer { fileReader.close() }

        guard fileReader.fileSize >= 10 else {
            return (nil, 0)
        }

        let headerData = try fileReader.read(at: 0, count: 10)

        do {
            let header = try ID3Header(data: headerData)
            let audioOffset = UInt64(10 + header.tagSize)
            return (header, audioOffset)
        } catch {
            return (nil, 0)
        }
    }
}

// MARK: - Write Strategies

extension ID3Writer {

    private func writeInPlace(tagData: Data, to url: URL) throws {
        let writer = try FileWriter(url: url)
        defer { writer.close() }
        try writer.write(tagData, at: 0)
        writer.synchronize()
    }

    private func writeWithTempFile(
        tagData: Data,
        audioOffset: UInt64,
        source url: URL
    ) throws {
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent("." + UUID().uuidString + ".tmp")

        do {
            let sourceReader = try FileReader(url: url)
            defer { sourceReader.close() }

            let tempWriter = try FileWriter(url: tempURL)
            defer { tempWriter.close() }

            // Write new tag data
            if !tagData.isEmpty {
                try tempWriter.write(tagData)
            }

            // Stream audio data from source
            let audioSize = sourceReader.fileSize - audioOffset
            if audioSize > 0 {
                try tempWriter.copyChunked(
                    from: sourceReader, offset: audioOffset, count: audioSize)
            }

            tempWriter.synchronize()
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }

        try atomicReplace(tempURL: tempURL, originalURL: url)
    }

    private func atomicReplace(tempURL: URL, originalURL: URL) throws {
        do {
            _ = try FileManager.default.replaceItemAt(originalURL, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw ID3Error.writeFailed(
                "Failed to replace \(originalURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }
}
