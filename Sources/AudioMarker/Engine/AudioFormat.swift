import Foundation

/// Supported audio file formats.
public enum AudioFormat: String, Sendable, Hashable, CaseIterable {
    /// MPEG Audio Layer III (.mp3).
    case mp3
    /// MPEG-4 Audio (.m4a).
    case m4a
    /// MPEG-4 Audiobook (.m4b).
    case m4b

    /// The typical file extensions for this format.
    public var fileExtensions: [String] {
        switch self {
        case .mp3: ["mp3"]
        case .m4a: ["m4a"]
        case .m4b: ["m4b"]
        }
    }

    /// Whether this format uses ID3v2 tags.
    public var usesID3: Bool {
        self == .mp3
    }

    /// Whether this format uses MP4 atoms.
    public var usesMP4: Bool {
        self == .m4a || self == .m4b
    }

    // MARK: - Detection

    /// Detects the audio format from a file URL.
    ///
    /// Checks both magic bytes and file extension. Magic bytes take
    /// priority; the extension is used to refine MP4 subtypes (m4a vs m4b).
    /// - Parameter url: File URL to inspect.
    /// - Returns: The detected format, or `nil` if unrecognized.
    /// - Throws: ``StreamingError`` if the file cannot be read.
    public static func detect(from url: URL) throws -> AudioFormat? {
        let reader = try FileReader(url: url)
        defer { reader.close() }

        let bytesToRead = min(Int(reader.fileSize), 12)
        guard bytesToRead >= 2 else {
            return detect(fromExtension: url.pathExtension)
        }

        let data = try reader.read(at: 0, count: bytesToRead)

        if let format = detect(fromMagicBytes: data) {
            // For generic MP4 detection, refine with extension.
            if format.usesMP4,
                let extFormat = detect(fromExtension: url.pathExtension),
                extFormat.usesMP4
            {
                return extFormat
            }
            return format
        }

        return detect(fromExtension: url.pathExtension)
    }

    /// Detects the audio format from a file extension alone.
    /// - Parameter ext: File extension (with or without leading dot).
    /// - Returns: The detected format, or `nil` if unrecognized.
    public static func detect(fromExtension ext: String) -> AudioFormat? {
        let normalized = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        switch normalized {
        case "mp3": return .mp3
        case "m4a": return .m4a
        case "m4b": return .m4b
        default: return nil
        }
    }

    /// Detects the audio format from magic bytes.
    /// - Parameter data: First bytes of the file (at least 12 bytes recommended).
    /// - Returns: The detected format, or `nil` if unrecognized.
    public static func detect(fromMagicBytes data: Data) -> AudioFormat? {
        guard data.count >= 2 else { return nil }

        // MP3: ID3v2 tag header.
        if data.count >= 3, data[0] == 0x49, data[1] == 0x44, data[2] == 0x33 {
            return .mp3
        }

        // MP3: MPEG sync word (11 bits set = 0xFF + top 3 bits of next byte).
        if data[0] == 0xFF, (data[1] & 0xE0) == 0xE0 {
            return .mp3
        }

        // MP4: ftyp box at offset 4.
        if data.count >= 8 {
            let typeSlice = data[4..<8]
            if String(data: typeSlice, encoding: .ascii) == "ftyp" {
                // Check major brand for m4b.
                if data.count >= 12 {
                    let brand = String(data: data[8..<12], encoding: .ascii)
                    if brand == "M4B " {
                        return .m4b
                    }
                }
                return .m4a
            }
        }

        return nil
    }
}
