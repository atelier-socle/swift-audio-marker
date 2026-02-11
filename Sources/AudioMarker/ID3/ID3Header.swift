import Foundation

// MARK: - ID3TagFlags

/// ID3v2 tag-level flags parsed from the header byte.
public struct ID3TagFlags: Sendable, Hashable {

    /// Whether unsynchronization is applied to the entire tag (v2.3) or as a flag (v2.4).
    public let unsynchronization: Bool

    /// Whether an extended header is present.
    public let extendedHeader: Bool

    /// Whether this is an experimental tag.
    public let experimental: Bool

    /// Whether a footer is present (v2.4 only).
    public let footer: Bool

    /// Parses tag flags from a raw byte.
    /// - Parameters:
    ///   - rawByte: The flags byte from the ID3v2 header.
    ///   - version: The tag version (affects which flags are valid).
    public init(rawByte: UInt8, version: ID3Version) {
        self.unsynchronization = (rawByte & 0x80) != 0
        self.extendedHeader = (rawByte & 0x40) != 0
        self.experimental = (rawByte & 0x20) != 0
        self.footer = version == .v2_4 ? (rawByte & 0x10) != 0 : false
    }
}

// MARK: - ID3Header

/// Parsed ID3v2 tag header (10 bytes at the start of the tag).
public struct ID3Header: Sendable, Hashable {

    /// The tag version.
    public let version: ID3Version

    /// Tag-level flags.
    public let flags: ID3TagFlags

    /// Total size of the tag data (excluding the 10-byte header).
    public let tagSize: UInt32

    /// Parses an ID3v2 header from raw data (must be at least 10 bytes).
    /// - Parameter data: Raw bytes starting with `"ID3"`.
    /// - Throws: ``ID3Error/invalidHeader(_:)``, ``ID3Error/unsupportedVersion(major:minor:)``
    public init(data: Data) throws {
        guard data.count >= 10 else {
            throw ID3Error.invalidHeader("Data too short: \(data.count) bytes, need 10.")
        }

        let s = data.startIndex

        // Bytes 0-2: "ID3" marker
        guard data[s] == 0x49, data[s + 1] == 0x44, data[s + 2] == 0x33 else {
            throw ID3Error.noTag
        }

        // Bytes 3-4: version (major, revision)
        let major = data[s + 3]
        let minor = data[s + 4]

        switch major {
        case 3:
            self.version = .v2_3
        case 4:
            self.version = .v2_4
        default:
            throw ID3Error.unsupportedVersion(major: major, minor: minor)
        }

        // Byte 5: flags
        self.flags = ID3TagFlags(rawByte: data[s + 5], version: version)

        // Bytes 6-9: tag size (syncsafe integer)
        let b0 = data[s + 6]
        let b1 = data[s + 7]
        let b2 = data[s + 8]
        let b3 = data[s + 9]

        // Validate syncsafe: bit 7 must be 0 in each byte
        guard b0 & 0x80 == 0, b1 & 0x80 == 0, b2 & 0x80 == 0, b3 & 0x80 == 0 else {
            throw ID3Error.invalidSyncsafeInteger
        }

        self.tagSize =
            UInt32(b0) << 21
            | UInt32(b1) << 14
            | UInt32(b2) << 7
            | UInt32(b3)
    }
}
