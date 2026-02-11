import Foundation

/// A buffer-based binary data writer for constructing structured binary formats.
///
/// All multi-byte integer writes use big-endian byte order,
/// matching ID3v2 and MP4/ISOBMFF conventions.
public struct BinaryWriter: Sendable {

    /// The accumulated data.
    public private(set) var data: Data

    /// Creates an empty binary writer.
    public init() {
        self.data = Data()
    }

    /// Creates an empty binary writer with pre-allocated capacity.
    /// - Parameter capacity: The expected number of bytes.
    public init(capacity: Int) {
        self.data = Data()
        self.data.reserveCapacity(capacity)
    }

    /// The current size of the written data in bytes.
    public var count: Int { data.count }

    // MARK: - Integer Writing

    /// Writes a `UInt8`.
    public mutating func writeUInt8(_ value: UInt8) {
        data.append(value)
    }

    /// Writes a big-endian `UInt16`.
    public mutating func writeUInt16(_ value: UInt16) {
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    /// Writes a big-endian `UInt32`.
    public mutating func writeUInt32(_ value: UInt32) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    /// Writes a big-endian `UInt64`.
    public mutating func writeUInt64(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8((value >> shift) & 0xFF))
        }
    }

    /// Writes a syncsafe integer (4 bytes, ID3v2 format).
    ///
    /// Each byte uses only 7 bits (MSB is always 0), yielding 28 effective bits.
    public mutating func writeSyncsafeUInt32(_ value: UInt32) {
        data.append(UInt8((value >> 21) & 0x7F))
        data.append(UInt8((value >> 14) & 0x7F))
        data.append(UInt8((value >> 7) & 0x7F))
        data.append(UInt8(value & 0x7F))
    }

    // MARK: - Data Writing

    /// Appends raw data.
    /// - Parameter data: The data to append.
    public mutating func writeData(_ data: Data) {
        self.data.append(data)
    }

    /// Appends a single null byte (`0x00`).
    public mutating func writeNullByte() {
        data.append(0x00)
    }

    /// Appends a byte repeated the specified number of times.
    /// - Parameters:
    ///   - byte: The byte value to repeat.
    ///   - count: How many times to repeat.
    public mutating func writeRepeating(_ byte: UInt8, count: Int) {
        data.append(contentsOf: [UInt8](repeating: byte, count: count))
    }

    // MARK: - String Writing

    /// Writes a Latin-1 encoded string (no terminator).
    /// - Parameter string: The string to encode.
    public mutating func writeLatin1String(_ string: String) {
        if let encoded = string.data(using: .isoLatin1) {
            data.append(encoded)
        }
    }

    /// Writes a UTF-8 encoded string (no terminator).
    /// - Parameter string: The string to encode.
    public mutating func writeUTF8String(_ string: String) {
        data.append(contentsOf: string.utf8)
    }

    /// Writes a null-terminated Latin-1 string.
    /// - Parameter string: The string to encode.
    public mutating func writeNullTerminatedLatin1String(_ string: String) {
        writeLatin1String(string)
        writeNullByte()
    }

    /// Writes a null-terminated UTF-8 string.
    /// - Parameter string: The string to encode.
    public mutating func writeNullTerminatedUTF8String(_ string: String) {
        writeUTF8String(string)
        writeNullByte()
    }
}
