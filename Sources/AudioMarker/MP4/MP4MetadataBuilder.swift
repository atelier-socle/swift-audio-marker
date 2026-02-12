import Foundation

/// Builds iTunes metadata atoms from ``AudioMetadata``.
///
/// Produces the `ilst` atom containing individual metadata items,
/// and the complete `udta → meta → ilst` hierarchy for embedding
/// in a `moov` atom.
public struct MP4MetadataBuilder: Sendable {

    private let atomBuilder = MP4AtomBuilder()

    /// Creates an MP4 metadata builder.
    public init() {}

    // MARK: - Public API

    /// Builds the complete `ilst` atom from metadata.
    /// - Parameter metadata: The audio metadata.
    /// - Returns: Complete ilst atom data.
    public func buildIlst(from metadata: AudioMetadata) -> Data {
        var items: [Data] = []
        buildTextItems(from: metadata, into: &items)
        buildStructuredItems(from: metadata, into: &items)
        buildCustomItems(from: metadata, into: &items)
        return atomBuilder.buildContainerAtom(type: "ilst", children: items)
    }

    /// Builds the complete `udta → meta → ilst` hierarchy.
    ///
    /// If chapters are provided, a `chpl` atom is also included in `udta`.
    /// - Parameters:
    ///   - metadata: The audio metadata.
    ///   - chapters: Optional chapter list for Nero chapters.
    /// - Returns: Complete udta atom data.
    public func buildUdta(from metadata: AudioMetadata, chapters: ChapterList?) -> Data {
        let ilst = buildIlst(from: metadata)
        let meta = atomBuilder.buildMetaAtom(children: [ilst])

        var udtaChildren: [Data] = [meta]

        if let chapters, !chapters.isEmpty {
            let chapterBuilder = MP4ChapterBuilder()
            if let chpl = chapterBuilder.buildChplAtom(from: chapters) {
                udtaChildren.append(chpl)
            }
        }

        return atomBuilder.buildContainerAtom(type: "udta", children: udtaChildren)
    }
}

// MARK: - Text Metadata Items

extension MP4MetadataBuilder {

    /// Builds text-type ilst items (©nam, ©ART, ©alb, etc.).
    private func buildTextItems(from metadata: AudioMetadata, into items: inout [Data]) {
        if let title = metadata.title {
            items.append(buildTextItem(type: "\u{00A9}nam", text: title))
        }
        if let artist = metadata.artist {
            items.append(buildTextItem(type: "\u{00A9}ART", text: artist))
        }
        if let album = metadata.album {
            items.append(buildTextItem(type: "\u{00A9}alb", text: album))
        }
        if let genre = metadata.genre {
            items.append(buildTextItem(type: "\u{00A9}gen", text: genre))
        }
        if let year = metadata.year {
            items.append(buildTextItem(type: "\u{00A9}day", text: String(year)))
        }
        if let composer = metadata.composer {
            items.append(buildTextItem(type: "\u{00A9}wrt", text: composer))
        }
        if let comment = metadata.comment {
            items.append(buildTextItem(type: "\u{00A9}cmt", text: comment))
        }
        if let encoder = metadata.encoder {
            items.append(buildTextItem(type: "\u{00A9}too", text: encoder))
        }
        if !metadata.synchronizedLyrics.isEmpty {
            let lyricsText = serializeSynchronizedLyrics(metadata.synchronizedLyrics)
            items.append(buildTextItem(type: "\u{00A9}lyr", text: lyricsText))
        } else if let lyrics = metadata.unsynchronizedLyrics {
            items.append(buildTextItem(type: "\u{00A9}lyr", text: lyrics))
        }
    }

    /// Serializes synchronized lyrics for storage in ©lyr.
    ///
    /// Rich content (multi-language, karaoke segments, or speaker attribution)
    /// is stored as TTML for full fidelity. Simple single-language lyrics
    /// without word-level timing or speakers are stored as LRC for maximum
    /// compatibility with third-party players.
    private func serializeSynchronizedLyrics(_ lyrics: [SynchronizedLyrics]) -> String {
        let hasKaraoke = lyrics.contains { syncLyrics in
            syncLyrics.lines.contains { $0.isKaraoke }
        }
        let hasSpeakers = lyrics.contains { syncLyrics in
            syncLyrics.lines.contains { $0.hasSpeaker }
        }
        if lyrics.count > 1 || hasKaraoke || hasSpeakers {
            let doc = TTMLDocument.from(lyrics)
            return TTMLExporter.exportDocument(doc)
        }
        return LRCParser.export(lyrics[0])
    }

    /// Builds a single UTF-8 text metadata item.
    private func buildTextItem(type: String, text: String) -> Data {
        atomBuilder.buildMetadataItem(
            type: type, typeIndicator: DataTypeIndicator.utf8, value: Data(text.utf8))
    }
}

// MARK: - Structured Metadata Items

extension MP4MetadataBuilder {

    /// Builds structured ilst items (albumArtist, copyright, trkn, disk, covr, tmpo).
    private func buildStructuredItems(from metadata: AudioMetadata, into items: inout [Data]) {
        if let albumArtist = metadata.albumArtist {
            items.append(buildTextItem(type: "aART", text: albumArtist))
        }
        if let copyright = metadata.copyright {
            items.append(buildTextItem(type: "cprt", text: copyright))
        }
        if let trackNumber = metadata.trackNumber {
            items.append(buildIntegerPairItem(type: "trkn", value: UInt16(trackNumber)))
        }
        if let discNumber = metadata.discNumber {
            items.append(buildIntegerPairItem(type: "disk", value: UInt16(discNumber)))
        }
        if let artwork = metadata.artwork {
            items.append(buildArtworkItem(artwork))
        }
        if let bpm = metadata.bpm {
            items.append(buildUInt16Item(type: "tmpo", value: UInt16(bpm)))
        }
    }

    /// Builds a trkn/disk integer pair item.
    ///
    /// Binary format: 2 bytes padding + UInt16 value + UInt16 total(0) + 2 bytes padding.
    private func buildIntegerPairItem(type: String, value: UInt16) -> Data {
        var writer = BinaryWriter(capacity: 8)
        writer.writeUInt16(0)  // padding
        writer.writeUInt16(value)
        writer.writeUInt16(0)  // total
        writer.writeUInt16(0)  // padding
        return atomBuilder.buildMetadataItem(
            type: type, typeIndicator: DataTypeIndicator.implicitZero, value: writer.data)
    }

    /// Builds an artwork (covr) item.
    private func buildArtworkItem(_ artwork: Artwork) -> Data {
        let typeIndicator: UInt32 =
            switch artwork.format {
            case .jpeg: DataTypeIndicator.jpeg
            case .png: DataTypeIndicator.png
            }
        return atomBuilder.buildMetadataItem(
            type: "covr", typeIndicator: typeIndicator, value: artwork.data)
    }

    /// Builds a UInt16 integer item (e.g., tmpo/bpm).
    private func buildUInt16Item(type: String, value: UInt16) -> Data {
        var writer = BinaryWriter(capacity: 2)
        writer.writeUInt16(value)
        return atomBuilder.buildMetadataItem(
            type: type, typeIndicator: DataTypeIndicator.signedInteger, value: writer.data)
    }
}

// MARK: - Custom Items (Reverse DNS)

extension MP4MetadataBuilder {

    /// Builds reverse DNS (----) items from customTextFields.
    private func buildCustomItems(from metadata: AudioMetadata, into items: inout [Data]) {
        for (key, value) in metadata.customTextFields.sorted(by: { $0.key < $1.key }) {
            let parts = key.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let mean = String(parts[0])
            let name = String(parts[1])
            items.append(buildReverseDNSItem(mean: mean, name: name, value: value))
        }
    }

    /// Builds a single reverse DNS (----) atom with mean, name, and data sub-atoms.
    private func buildReverseDNSItem(mean: String, name: String, value: String) -> Data {
        // mean atom: version(4) + text
        var meanPayload = BinaryWriter()
        meanPayload.writeUInt32(0)  // version + flags
        meanPayload.writeUTF8String(mean)
        let meanAtom = atomBuilder.buildAtom(type: "mean", data: meanPayload.data)

        // name atom: version(4) + text
        var namePayload = BinaryWriter()
        namePayload.writeUInt32(0)  // version + flags
        namePayload.writeUTF8String(name)
        let nameAtom = atomBuilder.buildAtom(type: "name", data: namePayload.data)

        // data atom
        let dataAtom = atomBuilder.buildDataAtom(
            typeIndicator: DataTypeIndicator.utf8, value: Data(value.utf8))

        return atomBuilder.buildContainerAtom(type: "----", children: [meanAtom, nameAtom, dataAtom])
    }
}

// MARK: - Data Type Constants

extension MP4MetadataBuilder {

    /// iTunes data atom type indicators.
    private enum DataTypeIndicator {
        static let implicitZero: UInt32 = 0
        static let utf8: UInt32 = 1
        static let jpeg: UInt32 = 13
        static let png: UInt32 = 14
        static let signedInteger: UInt32 = 21
    }
}
