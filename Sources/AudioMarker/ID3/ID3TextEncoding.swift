import Foundation

/// Text encoding types used in ID3v2 frames.
public enum ID3TextEncoding: UInt8, Sendable, Hashable {

    /// ISO 8859-1 (Latin-1).
    case latin1 = 0

    /// UTF-16 with BOM (byte order mark).
    case utf16WithBOM = 1

    /// UTF-16BE without BOM (v2.4 only).
    case utf16BigEndian = 2

    /// UTF-8 (v2.4 only).
    case utf8 = 3

    // MARK: - Decoding

    /// Decodes raw bytes to a string using this encoding.
    /// - Parameter data: Raw bytes to decode.
    /// - Returns: The decoded string.
    /// - Throws: ``ID3Error/invalidEncoding(_:)``
    public func decode(_ data: Data) throws -> String {
        if data.isEmpty { return "" }

        switch self {
        case .latin1:
            guard let string = String(data: data, encoding: .isoLatin1) else {
                throw ID3Error.invalidEncoding(rawValue)
            }
            return string

        case .utf16WithBOM:
            guard let string = String(data: data, encoding: .utf16) else {
                throw ID3Error.invalidEncoding(rawValue)
            }
            return string

        case .utf16BigEndian:
            guard let string = String(data: data, encoding: .utf16BigEndian) else {
                throw ID3Error.invalidEncoding(rawValue)
            }
            return string

        case .utf8:
            guard let string = String(data: data, encoding: .utf8) else {
                throw ID3Error.invalidEncoding(rawValue)
            }
            return string
        }
    }

    // MARK: - Encoding

    /// Encodes a string using this encoding.
    /// - Parameter string: The string to encode.
    /// - Returns: The encoded bytes.
    public func encode(_ string: String) -> Data {
        switch self {
        case .latin1:
            return string.data(using: .isoLatin1) ?? Data()

        case .utf16WithBOM:
            return string.data(using: .utf16) ?? Data()

        case .utf16BigEndian:
            return string.data(using: .utf16BigEndian) ?? Data()

        case .utf8:
            return Data(string.utf8)
        }
    }

    // MARK: - Null Terminator

    /// The null terminator bytes for this encoding.
    ///
    /// Latin-1 and UTF-8 use a single `0x00` byte.
    /// UTF-16 variants use two `0x00` bytes.
    public var nullTerminator: Data {
        switch self {
        case .latin1, .utf8:
            return Data([0x00])
        case .utf16WithBOM, .utf16BigEndian:
            return Data([0x00, 0x00])
        }
    }

    /// The size of the null terminator in bytes.
    public var nullTerminatorSize: Int {
        switch self {
        case .latin1, .utf8: return 1
        case .utf16WithBOM, .utf16BigEndian: return 2
        }
    }
}
