import Foundation

/// Extracts ``AudioMetadata`` from an MP4 atom tree.
///
/// Reads iTunes metadata from the `ilst` atom and duration/timescale
/// from the `mvhd` atom. Artwork is extracted from `covr` atoms.
public struct MP4MetadataParser: Sendable {

    /// Creates an MP4 metadata parser.
    public init() {}

    // MARK: - Public API

    /// Extracts metadata from the parsed atom tree and file data.
    /// - Parameters:
    ///   - atoms: Top-level atoms from ``MP4AtomParser``.
    ///   - reader: An open file reader for reading atom payloads.
    /// - Returns: Parsed audio metadata.
    /// - Throws: ``MP4Error`` if required atoms are missing or corrupt.
    public func parseMetadata(
        from atoms: [MP4Atom],
        reader: FileReader
    ) throws -> AudioMetadata {
        guard let moov = atoms.first(where: { $0.type == MP4AtomType.moov.rawValue }) else {
            throw MP4Error.atomNotFound("moov")
        }

        var metadata = AudioMetadata()

        if let ilst = moov.find(path: "udta.meta.ilst") {
            try parseITunesMetadata(ilst, reader: reader, metadata: &metadata)
        }

        return metadata
    }

    /// Extracts the audio duration from the `mvhd` atom.
    /// - Parameters:
    ///   - atoms: Top-level atoms from ``MP4AtomParser``.
    ///   - reader: An open file reader.
    /// - Returns: The duration as an ``AudioTimestamp``, or `nil` if not found.
    /// - Throws: ``MP4Error`` if `mvhd` data is corrupt.
    public func parseDuration(
        from atoms: [MP4Atom],
        reader: FileReader
    ) throws -> AudioTimestamp? {
        guard let moov = atoms.first(where: { $0.type == MP4AtomType.moov.rawValue }),
            let mvhd = moov.child(ofType: MP4AtomType.mvhd.rawValue)
        else {
            return nil
        }

        return try readDurationFromMVHD(mvhd, reader: reader)
    }

    // MARK: - MVHD Duration

    /// Reads duration and timescale from the `mvhd` atom.
    private func readDurationFromMVHD(
        _ mvhd: MP4Atom,
        reader: FileReader
    ) throws -> AudioTimestamp? {
        let dataSize = mvhd.dataSize
        guard dataSize >= 8 else { return nil }

        let readSize = min(dataSize, 32)
        let data = try reader.read(at: mvhd.dataOffset, count: Int(readSize))
        var binaryReader = BinaryReader(data: data)

        let version = try binaryReader.readUInt8()
        try binaryReader.skip(3)  // flags

        let timescale: UInt32
        let duration: UInt64

        if version == 1 {
            // Version 1: 8-byte creation/modification times, 4-byte timescale, 8-byte duration.
            guard dataSize >= 28 else { return nil }
            try binaryReader.skip(16)  // creation + modification time
            timescale = try binaryReader.readUInt32()
            duration = try binaryReader.readUInt64()
        } else {
            // Version 0: 4-byte creation/modification times, 4-byte timescale, 4-byte duration.
            guard dataSize >= 16 else { return nil }
            try binaryReader.skip(8)  // creation + modification time
            timescale = try binaryReader.readUInt32()
            duration = UInt64(try binaryReader.readUInt32())
        }

        guard timescale > 0 else { return nil }
        let seconds = Double(duration) / Double(timescale)
        return .seconds(seconds)
    }
}

// MARK: - iTunes Metadata (ilst)

extension MP4MetadataParser {

    /// Parses all ilst child atoms into metadata fields.
    private func parseITunesMetadata(
        _ ilst: MP4Atom,
        reader: FileReader,
        metadata: inout AudioMetadata
    ) throws {
        for child in ilst.children {
            try applyITunesAtom(child, reader: reader, metadata: &metadata)
        }
    }

    /// Dispatches a single ilst child atom to the appropriate handler.
    private func applyITunesAtom(
        _ atom: MP4Atom,
        reader: FileReader,
        metadata: inout AudioMetadata
    ) throws {
        switch atom.type {
        case "\u{00A9}nam": metadata.title = try readTextDataAtom(atom, reader: reader)
        case "\u{00A9}ART": metadata.artist = try readTextDataAtom(atom, reader: reader)
        case "\u{00A9}alb": metadata.album = try readTextDataAtom(atom, reader: reader)
        case "\u{00A9}gen": metadata.genre = try readTextDataAtom(atom, reader: reader)
        case "\u{00A9}day": metadata.year = parseYear(try readTextDataAtom(atom, reader: reader))
        case "\u{00A9}wrt": metadata.composer = try readTextDataAtom(atom, reader: reader)
        case "\u{00A9}cmt": metadata.comment = try readTextDataAtom(atom, reader: reader)
        case "\u{00A9}too": metadata.encoder = try readTextDataAtom(atom, reader: reader)
        case "\u{00A9}lyr":
            try applyLyricsAtom(atom, reader: reader, metadata: &metadata)
        default:
            try applyStructuredAtom(atom, reader: reader, metadata: &metadata)
        }
    }

    /// Handles the `©lyr` atom, storing both unsynchronized and synchronized lyrics.
    ///
    /// Detects whether the stored text is TTML (multi-language) or LRC (single-language)
    /// and parses accordingly. TTML is detected by an `<?xml` or `<tt` prefix.
    private func applyLyricsAtom(
        _ atom: MP4Atom,
        reader: FileReader,
        metadata: inout AudioMetadata
    ) throws {
        let lyricsText = try readTextDataAtom(atom, reader: reader)
        metadata.unsynchronizedLyrics = lyricsText
        guard let lyricsText else { return }
        let parsed = parseSynchronizedLyrics(lyricsText)
        if !parsed.isEmpty {
            metadata.synchronizedLyrics = parsed
        }
    }

    /// Attempts to parse lyrics text as TTML first, then falls back to LRC.
    private func parseSynchronizedLyrics(_ text: String) -> [SynchronizedLyrics] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<tt") {
            if let lyrics = try? TTMLParser().parseLyrics(from: text), !lyrics.isEmpty {
                return lyrics
            }
        }
        if let syncLyrics = try? LRCParser.parse(text), !syncLyrics.lines.isEmpty {
            return [syncLyrics]
        }
        return []
    }

    /// Handles non-text ilst atoms (trkn, disk, covr, aART, cprt, gnre, tmpo, ----).
    private func applyStructuredAtom(
        _ atom: MP4Atom,
        reader: FileReader,
        metadata: inout AudioMetadata
    ) throws {
        switch atom.type {
        case "trkn":
            metadata.trackNumber = try readIntegerPair(atom, reader: reader)
        case "disk":
            metadata.discNumber = try readIntegerPair(atom, reader: reader)
        case "covr":
            metadata.artwork = try readArtwork(atom, reader: reader)
        case "aART":
            metadata.albumArtist = try readTextDataAtom(atom, reader: reader)
        case "cprt":
            metadata.copyright = try readTextDataAtom(atom, reader: reader)
        case "gnre":
            metadata.genre = try readGenreAtom(atom, reader: reader, existing: metadata.genre)
        case "tmpo":
            metadata.bpm = try readUInt16DataAtom(atom, reader: reader)
        case "----":
            try applyReverseDNSAtom(atom, reader: reader, metadata: &metadata)
        default:
            break
        }
    }
}

// MARK: - Data Atom Reading

extension MP4MetadataParser {

    /// Data atom type indicators per Apple iTunes metadata spec.
    private enum DataType {
        static let utf8: UInt32 = 1
        static let utf16: UInt32 = 2
        static let jpeg: UInt32 = 13
        static let png: UInt32 = 14
        static let signedInteger: UInt32 = 21
    }

    /// Reads UTF-8 text from the data sub-atom of an ilst item.
    private func readTextDataAtom(_ atom: MP4Atom, reader: FileReader) throws -> String? {
        guard let dataAtom = atom.child(ofType: MP4AtomType.data.rawValue) else {
            return nil
        }

        let payloadSize = dataAtom.dataSize
        guard payloadSize > 8 else { return nil }

        let raw = try reader.read(at: dataAtom.dataOffset, count: Int(payloadSize))
        var binaryReader = BinaryReader(data: raw)

        let typeIndicator = try binaryReader.readUInt32()
        try binaryReader.skip(4)  // locale

        let textLength = Int(payloadSize) - 8
        guard textLength > 0 else { return nil }

        let textData = try binaryReader.readData(count: textLength)

        if typeIndicator == DataType.utf16 {
            return String(data: textData, encoding: .utf16BigEndian)
        }
        return String(data: textData, encoding: .utf8)
    }

    /// Reads a UInt16 value from the data sub-atom (e.g., tmpo/bpm).
    private func readUInt16DataAtom(_ atom: MP4Atom, reader: FileReader) throws -> Int? {
        guard let dataAtom = atom.child(ofType: MP4AtomType.data.rawValue) else {
            return nil
        }

        let payloadSize = dataAtom.dataSize
        guard payloadSize >= 10 else { return nil }

        let raw = try reader.read(at: dataAtom.dataOffset, count: Int(payloadSize))
        var binaryReader = BinaryReader(data: raw)
        try binaryReader.skip(8)  // type indicator + locale

        let value = try binaryReader.readUInt16()
        return Int(value)
    }

    /// Reads a pair of UInt16 values from a data atom (trkn, disk format).
    ///
    /// The binary format is: 2 bytes padding + 2 bytes value + 2 bytes total (+ optional padding).
    /// Only the value (second UInt16) is returned.
    private func readIntegerPair(_ atom: MP4Atom, reader: FileReader) throws -> Int? {
        guard let dataAtom = atom.child(ofType: MP4AtomType.data.rawValue) else {
            return nil
        }

        let payloadSize = dataAtom.dataSize
        guard payloadSize >= 14 else { return nil }

        let raw = try reader.read(at: dataAtom.dataOffset, count: Int(payloadSize))
        var binaryReader = BinaryReader(data: raw)
        try binaryReader.skip(8)  // type indicator + locale
        try binaryReader.skip(2)  // padding
        let value = try binaryReader.readUInt16()
        return value > 0 ? Int(value) : nil
    }

    /// Reads artwork data from a covr atom.
    private func readArtwork(_ atom: MP4Atom, reader: FileReader) throws -> Artwork? {
        guard let dataAtom = atom.child(ofType: MP4AtomType.data.rawValue) else {
            return nil
        }

        let payloadSize = dataAtom.dataSize
        guard payloadSize > 8 else { return nil }

        let raw = try reader.read(at: dataAtom.dataOffset, count: Int(payloadSize))
        var binaryReader = BinaryReader(data: raw)

        let typeIndicator = try binaryReader.readUInt32()
        try binaryReader.skip(4)  // locale

        let imageLength = Int(payloadSize) - 8
        guard imageLength > 0 else { return nil }

        let imageData = try binaryReader.readData(count: imageLength)

        let format: ArtworkFormat
        if typeIndicator == DataType.png {
            format = .png
        } else if typeIndicator == DataType.jpeg {
            format = .jpeg
        } else if let detected = ArtworkFormat.detect(from: imageData) {
            format = detected
        } else {
            return nil
        }

        return Artwork(data: imageData, format: format)
    }

    /// Reads genre from the binary gnre atom (ID3v1 genre index).
    ///
    /// If the genre was already set by ©gen, the existing value takes priority.
    private func readGenreAtom(
        _ atom: MP4Atom,
        reader: FileReader,
        existing: String?
    ) throws -> String? {
        if let existing { return existing }

        guard let dataAtom = atom.child(ofType: MP4AtomType.data.rawValue) else {
            return nil
        }

        let payloadSize = dataAtom.dataSize
        guard payloadSize >= 10 else { return nil }

        let raw = try reader.read(at: dataAtom.dataOffset, count: Int(payloadSize))
        var binaryReader = BinaryReader(data: raw)
        try binaryReader.skip(8)  // type indicator + locale

        let genreIndex = try binaryReader.readUInt16()
        return ID3v1Genre.name(forIndex: Int(genreIndex) - 1)
    }

    /// Reads a reverse DNS custom atom (----) into customTextFields.
    private func applyReverseDNSAtom(
        _ atom: MP4Atom,
        reader: FileReader,
        metadata: inout AudioMetadata
    ) throws {
        // ---- atoms have "mean" and "name" sub-atoms plus a "data" sub-atom.
        guard let meanAtom = atom.child(ofType: "mean"),
            let nameAtom = atom.child(ofType: "name")
        else {
            return
        }

        let meanText = try readReverseDNSText(meanAtom, reader: reader)
        let nameText = try readReverseDNSText(nameAtom, reader: reader)
        let value = try readTextDataAtom(atom, reader: reader)

        guard let meanText, let nameText, let value else { return }

        let key = "\(meanText):\(nameText)"
        metadata.customTextFields[key] = value
    }

    /// Reads text from a mean/name sub-atom (4-byte version/flags + text).
    private func readReverseDNSText(
        _ atom: MP4Atom,
        reader: FileReader
    ) throws -> String? {
        let payloadSize = atom.dataSize
        guard payloadSize > 4 else { return nil }

        let raw = try reader.read(at: atom.dataOffset, count: Int(payloadSize))
        var binaryReader = BinaryReader(data: raw)
        try binaryReader.skip(4)  // version + flags

        let textLength = Int(payloadSize) - 4
        guard textLength > 0 else { return nil }

        let textData = try binaryReader.readData(count: textLength)
        return String(data: textData, encoding: .utf8)
    }

    // MARK: - Helpers

    /// Parses a year from a date string (extracts first 4 digits).
    private func parseYear(_ text: String?) -> Int? {
        guard let text, text.count >= 4 else {
            return text.flatMap { Int($0) }
        }
        return Int(text.prefix(4))
    }
}

// MARK: - ID3v1 Genre Table

/// ID3v1 genre lookup table used by the gnre MP4 atom.
enum ID3v1Genre {

    /// Returns the genre name for an ID3v1 genre index, or `nil` if out of range.
    static func name(forIndex index: Int) -> String? {
        guard index >= 0, index < genres.count else { return nil }
        return genres[index]
    }

    private static let genres: [String] = [
        "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge",
        "Hip-Hop", "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R&B",
        "Rap", "Reggae", "Rock", "Techno", "Industrial", "Alternative", "Ska",
        "Death Metal", "Pranks", "Soundtrack", "Euro-Techno", "Ambient",
        "Trip-Hop", "Vocal", "Jazz+Funk", "Fusion", "Trance", "Classical",
        "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel", "Noise",
        "AlternRock", "Bass", "Soul", "Punk", "Space", "Meditative",
        "Instrumental Pop", "Instrumental Rock", "Ethnic", "Gothic", "Darkwave",
        "Techno-Industrial", "Electronic", "Pop-Folk", "Eurodance", "Dream",
        "Southern Rock", "Comedy", "Cult", "Gangsta", "Top 40", "Christian Rap",
        "Pop/Funk", "Jungle", "Native American", "Cabaret", "New Wave",
        "Psychadelic", "Rave", "Showtunes", "Trailer", "Lo-Fi", "Tribal",
        "Acid Punk", "Acid Jazz", "Polka", "Retro", "Musical", "Rock & Roll",
        "Hard Rock", "Folk", "Folk-Rock", "National Folk", "Swing", "Fast Fusion",
        "Bebop", "Latin", "Revival", "Celtic", "Bluegrass", "Avantgarde",
        "Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock",
        "Slow Rock", "Big Band", "Chorus", "Easy Listening", "Acoustic", "Humour",
        "Speech", "Chanson", "Opera", "Chamber Music", "Sonata", "Symphony",
        "Booty Bass", "Primus", "Porn Groove", "Satire", "Slow Jam", "Club",
        "Tango", "Samba", "Folklore", "Ballad", "Power Ballad", "Rhythmic Soul",
        "Freestyle", "Duet", "Punk Rock", "Drum Solo", "A cappella", "Euro-House",
        "Dance Hall", "Goa", "Drum & Bass", "Club-House", "Hardcore", "Terror",
        "Indie", "BritPop", "Negerpunk", "Polsk Punk", "Beat",
        "Christian Gangsta Rap", "Heavy Metal", "Black Metal", "Crossover",
        "Contemporary Christian", "Christian Rock", "Merengue", "Salsa",
        "Thrash Metal", "Anime", "JPop", "Synthpop", "Abstract", "Art Rock",
        "Baroque", "Bhangra", "Big Beat", "Breakbeat", "Chillout", "Downtempo",
        "Dub", "EBM", "Eclectic", "Electro", "Electroclash", "Emo",
        "Experimental", "Garage", "Global", "IDM", "Illbient", "Industro-Goth",
        "Jam Band", "Krautrock", "Leftfield", "Lounge", "Math Rock", "New Romantic",
        "Nu-Breakz", "Post-Punk", "Post-Rock", "Psytrance", "Shoegaze",
        "Space Rock", "Trop Rock", "World Music", "Neoclassical", "Audiobook",
        "Audio Theatre", "Neue Deutsche Welle", "Podcast", "Indie Rock",
        "G-Funk", "Dubstep", "Garage Rock", "Psybient"
    ]
}
