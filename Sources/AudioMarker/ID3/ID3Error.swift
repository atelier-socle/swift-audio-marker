import Foundation

/// Errors that can occur during ID3v2 tag reading or writing.
public enum ID3Error: Error, Sendable, LocalizedError {

    /// The file does not contain an ID3v2 tag.
    case noTag

    /// The ID3v2 header is malformed.
    case invalidHeader(String)

    /// The tag version is not supported (only v2.3 and v2.4).
    case unsupportedVersion(major: UInt8, minor: UInt8)

    /// A frame is malformed.
    case invalidFrame(id: String, reason: String)

    /// Text encoding is invalid or unsupported.
    case invalidEncoding(UInt8)

    /// The tag data is truncated or corrupt.
    case truncatedData(expected: Int, available: Int)

    /// A syncsafe integer is malformed (has bit 7 set).
    case invalidSyncsafeInteger

    public var errorDescription: String? {
        switch self {
        case .noTag:
            return "The file does not contain an ID3v2 tag."
        case .invalidHeader(let reason):
            return "Invalid ID3v2 header: \(reason)."
        case .unsupportedVersion(let major, let minor):
            return "Unsupported ID3v2 version: v2.\(major).\(minor)."
        case .invalidFrame(let id, let reason):
            return "Invalid ID3v2 frame \"\(id)\": \(reason)."
        case .invalidEncoding(let byte):
            return "Invalid ID3v2 text encoding byte: 0x\(String(byte, radix: 16, uppercase: true))."
        case .truncatedData(let expected, let available):
            return "Truncated ID3v2 data: expected \(expected) bytes, \(available) available."
        case .invalidSyncsafeInteger:
            return "Malformed syncsafe integer (bit 7 set in one or more bytes)."
        }
    }
}
