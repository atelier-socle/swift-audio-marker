import Foundation

/// Reads and parses ID3v2 tags from MP3 files.
public struct ID3Reader: Sendable {

    /// Creates an ID3v2 reader.
    public init() {}

    // MARK: - Public API

    /// Reads all ID3v2 tag data from a file and converts it to the domain model.
    /// - Parameter url: URL of the MP3 file.
    /// - Returns: Parsed audio file info with metadata, chapters, and lyrics.
    /// - Throws: ``ID3Error``, ``StreamingError``
    public func read(from url: URL) throws -> AudioFileInfo {
        let (_, frames) = try readRawFrames(from: url)
        return convertToAudioFileInfo(frames)
    }

    /// Reads only the raw ID3v2 frames without converting to the model.
    ///
    /// Useful for inspection or debugging.
    /// - Parameter url: URL of the MP3 file.
    /// - Returns: The header and array of parsed frames.
    /// - Throws: ``ID3Error``, ``StreamingError``
    public func readRawFrames(from url: URL) throws -> (header: ID3Header, frames: [ID3Frame]) {
        let fileReader = try FileReader(url: url)
        defer { fileReader.close() }

        guard fileReader.fileSize >= 10 else {
            throw ID3Error.invalidHeader("File too small: \(fileReader.fileSize) bytes.")
        }
        let headerData = try fileReader.read(at: 0, count: 10)
        let header = try ID3Header(data: headerData)

        let tagDataSize = Int(header.tagSize)
        guard fileReader.fileSize >= UInt64(10 + tagDataSize) else {
            throw ID3Error.truncatedData(
                expected: 10 + tagDataSize, available: Int(fileReader.fileSize)
            )
        }
        let tagData = try fileReader.read(at: 10, count: tagDataSize)

        var reader = BinaryReader(data: tagData)

        if header.flags.extendedHeader {
            try skipExtendedHeader(&reader, version: header.version)
        }

        let parser = ID3FrameParser(version: header.version)
        var frames: [ID3Frame] = []

        while reader.hasRemaining {
            guard reader.remainingCount >= 10 else { break }
            guard let frame = try parser.parseFrame(&reader) else { break }
            frames.append(frame)
        }

        return (header, frames)
    }

    // MARK: - Extended Header

    private func skipExtendedHeader(
        _ reader: inout BinaryReader,
        version: ID3Version
    ) throws {
        if version == .v2_4 {
            let size = try reader.readSyncsafeUInt32()
            let skipBytes = Int(size) - 4
            if skipBytes > 0 {
                try reader.skip(skipBytes)
            }
        } else {
            let size = try reader.readUInt32()
            try reader.skip(Int(size))
        }
    }
}

// MARK: - Frame-to-Model Conversion

extension ID3Reader {

    private func convertToAudioFileInfo(_ frames: [ID3Frame]) -> AudioFileInfo {
        var metadata = AudioMetadata()
        var chapters: [Chapter] = []
        var chapterOrder: [String]?

        for frame in frames {
            applyFrame(frame, to: &metadata, chapters: &chapters, chapterOrder: &chapterOrder)
        }

        if let order = chapterOrder, chapters.count == order.count {
            chapters = reorderChapters(chapters, byOrder: order)
        }

        return AudioFileInfo(metadata: metadata, chapters: ChapterList(chapters))
    }

    private func applyFrame(
        _ frame: ID3Frame,
        to metadata: inout AudioMetadata,
        chapters: inout [Chapter],
        chapterOrder: inout [String]?
    ) {
        switch frame {
        case .text(let id, let text):
            applyTextFrame(id: id, text: text, to: &metadata)
        case .url(let id, let urlString):
            applyURLFrame(id: id, urlString: urlString, to: &metadata)
        case .chapter(let elementID, let startMs, let endMs, let subframes):
            chapters.append(
                buildChapter(
                    elementID: elementID, startMs: startMs, endMs: endMs, subframes: subframes
                ))
        case .tableOfContents(_, _, let isOrdered, let childElementIDs, _):
            if isOrdered { chapterOrder = childElementIDs }
        default:
            applySimpleFrame(frame, to: &metadata)
        }
    }

    private func applySimpleFrame(_ frame: ID3Frame, to metadata: inout AudioMetadata) {
        switch frame {
        case .userDefinedText(let description, let value):
            metadata.customTextFields[description] = value
        case .userDefinedURL(let description, let urlString):
            applyUserDefinedURL(description: description, urlString: urlString, to: &metadata)
        case .comment(_, _, let text):
            metadata.comment = text
        case .attachedPicture(let pictureType, _, _, let data):
            applyArtwork(pictureType: pictureType, data: data, to: &metadata)
        case .unsyncLyrics(_, _, let text):
            metadata.unsynchronizedLyrics = text
        case .syncLyrics(let language, let contentType, let description, let events):
            applySyncLyrics(
                language: language, contentType: contentType,
                description: description, events: events, to: &metadata)
        default:
            applyDataFrame(frame, to: &metadata)
        }
    }

    private func applyDataFrame(_ frame: ID3Frame, to metadata: inout AudioMetadata) {
        switch frame {
        case .privateData(let owner, let data):
            metadata.privateData.append(PrivateData(owner: owner, data: data))
        case .uniqueFileID(let owner, let identifier):
            metadata.uniqueFileIdentifiers.append(
                UniqueFileIdentifier(owner: owner, identifier: identifier)
            )
        case .playCounter(let count):
            metadata.playCount = Int(count)
        case .popularimeter(_, let rating, _):
            metadata.rating = rating
        default:
            break
        }
    }

    private func applyUserDefinedURL(
        description: String, urlString: String, to metadata: inout AudioMetadata
    ) {
        if let url = URL(string: urlString) {
            metadata.customURLs[description] = url
        }
    }

    private func applyArtwork(pictureType: UInt8, data: Data, to metadata: inout AudioMetadata) {
        if pictureType == 3 || metadata.artwork == nil {
            if let artwork = try? Artwork(data: data) {
                metadata.artwork = artwork
            }
        }
    }

    private func applySyncLyrics(
        language: String, contentType: UInt8, description: String,
        events: [SyncLyricEvent], to metadata: inout AudioMetadata
    ) {
        let lines = events.map { event in
            LyricLine(time: .milliseconds(Int(event.timestamp)), text: event.text)
        }
        let ct = ContentType(rawValue: contentType) ?? .lyrics
        metadata.synchronizedLyrics.append(
            SynchronizedLyrics(
                language: language, contentType: ct,
                descriptor: description, lines: lines)
        )
    }
}

// MARK: - Text & URL Frame Mapping

extension ID3Reader {

    private func applyTextFrame(id: String, text: String, to metadata: inout AudioMetadata) {
        applyTextCoreFields(id: id, text: text, to: &metadata)
        applyTextProfessionalFields(id: id, text: text, to: &metadata)
    }

    private func applyTextCoreFields(id: String, text: String, to metadata: inout AudioMetadata) {
        switch id {
        case ID3FrameID.title.rawValue: metadata.title = text
        case ID3FrameID.artist.rawValue: metadata.artist = text
        case ID3FrameID.album.rawValue: metadata.album = text
        case ID3FrameID.genre.rawValue: metadata.genre = text
        case ID3FrameID.trackNumber.rawValue: metadata.trackNumber = parseSlashNumber(text)
        case ID3FrameID.discNumber.rawValue: metadata.discNumber = parseSlashNumber(text)
        case ID3FrameID.yearV23.rawValue: metadata.year = Int(text)
        case ID3FrameID.recordingDate.rawValue: metadata.year = parseYear(from: text)
        default: break
        }
    }

    private func applyTextProfessionalFields(
        id: String, text: String, to metadata: inout AudioMetadata
    ) {
        switch id {
        case ID3FrameID.albumArtist.rawValue: metadata.albumArtist = text
        case ID3FrameID.composer.rawValue: metadata.composer = text
        case ID3FrameID.publisher.rawValue: metadata.publisher = text
        case ID3FrameID.copyright.rawValue: metadata.copyright = text
        case ID3FrameID.encodedBy.rawValue: metadata.encoder = text
        case ID3FrameID.bpm.rawValue: metadata.bpm = Int(text)
        case ID3FrameID.musicalKey.rawValue: metadata.key = text
        case ID3FrameID.language.rawValue: metadata.language = text
        case ID3FrameID.isrc.rawValue: metadata.isrc = text
        default: break
        }
    }

    private func applyURLFrame(id: String, urlString: String, to metadata: inout AudioMetadata) {
        guard let url = URL(string: urlString) else { return }

        switch id {
        case ID3FrameID.artistURL.rawValue: metadata.artistURL = url
        case ID3FrameID.audioSourceURL.rawValue: metadata.audioSourceURL = url
        case ID3FrameID.audioFileURL.rawValue: metadata.audioFileURL = url
        case ID3FrameID.publisherURL.rawValue: metadata.publisherURL = url
        case ID3FrameID.commercialURL.rawValue: metadata.commercialURL = url
        default: break
        }
    }
}

// MARK: - Chapter Building & Helpers

extension ID3Reader {

    private func buildChapter(
        elementID: String, startMs: UInt32, endMs: UInt32, subframes: [ID3Frame]
    ) -> Chapter {
        var title = elementID
        var url: URL?
        var artwork: Artwork?

        for subframe in subframes {
            switch subframe {
            case .text(let id, let text) where id == ID3FrameID.title.rawValue:
                title = text
            case .url(let id, let urlString) where id == ID3FrameID.artistURL.rawValue:
                url = URL(string: urlString)
            case .attachedPicture(_, _, _, let data):
                artwork = try? Artwork(data: data)
            default:
                break
            }
        }

        return Chapter(
            start: .milliseconds(Int(startMs)), title: title,
            end: .milliseconds(Int(endMs)), url: url, artwork: artwork
        )
    }

    private func parseSlashNumber(_ text: String) -> Int? {
        let parts = text.split(separator: "/")
        guard let first = parts.first else { return nil }
        return Int(first)
    }

    private func parseYear(from text: String) -> Int? {
        guard text.count >= 4 else { return Int(text) }
        return Int(text.prefix(4))
    }

    private func reorderChapters(_ chapters: [Chapter], byOrder order: [String]) -> [Chapter] {
        guard chapters.count == order.count else { return chapters }
        return chapters
    }
}
