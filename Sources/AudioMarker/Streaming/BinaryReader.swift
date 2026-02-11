import Foundation

// MARK: - BinaryReaderError

/// Errors that can occur when reading binary data with ``BinaryReader``.
public enum BinaryReaderError: Error, Sendable, Hashable, LocalizedError {

    /// Not enough bytes remaining for the requested read.
    case unexpectedEndOfData(offset: Int, requested: Int, available: Int)

    /// The data at the current offset is not valid for the requested string encoding.
    case invalidEncoding(offset: Int)

    /// The seek target is outside the data bounds.
    case seekOutOfBounds(offset: Int, dataSize: Int)

    public var errorDescription: String? {
        switch self {
        case .unexpectedEndOfData(let offset, let requested, let available):
            return
                "Unexpected end of data at offset \(offset): requested \(requested) bytes, \(available) available."
        case .invalidEncoding(let offset):
            return "Invalid string encoding at offset \(offset)."
        case .seekOutOfBounds(let offset, let dataSize):
            return "Seek offset \(offset) is out of bounds for data of size \(dataSize)."
        }
    }
}

// MARK: - BinaryReader

/// A cursor-based binary data reader for parsing structured binary formats.
///
/// All multi-byte integer reads use big-endian byte order,
/// matching ID3v2 and MP4/ISOBMFF conventions.
public struct BinaryReader: Sendable {

    /// The underlying data.
    public let data: Data

    /// Current read position.
    public private(set) var offset: Int

    /// Creates a binary reader starting at offset 0.
    /// - Parameter data: The data to read from.
    public init(data: Data) {
        self.data = data
        self.offset = 0
    }

    /// The number of bytes remaining from the current offset.
    public var remainingCount: Int {
        max(0, data.count - offset)
    }

    /// Whether there are bytes remaining to read.
    public var hasRemaining: Bool {
        offset < data.count
    }

    // MARK: - Integer Reading

    /// Reads a `UInt8` and advances the offset.
    public mutating func readUInt8() throws -> UInt8 {
        try ensureAvailable(1)
        let value = data[data.startIndex + offset]
        offset += 1
        return value
    }

    /// Reads a big-endian `UInt16` and advances the offset.
    public mutating func readUInt16() throws -> UInt16 {
        try ensureAvailable(2)
        let s = data.startIndex + offset
        let value = UInt16(data[s]) << 8 | UInt16(data[s + 1])
        offset += 2
        return value
    }

    /// Reads a big-endian `UInt32` and advances the offset.
    public mutating func readUInt32() throws -> UInt32 {
        try ensureAvailable(4)
        let s = data.startIndex + offset
        let value =
            UInt32(data[s]) << 24
            | UInt32(data[s + 1]) << 16
            | UInt32(data[s + 2]) << 8
            | UInt32(data[s + 3])
        offset += 4
        return value
    }

    /// Reads a big-endian `UInt64` and advances the offset.
    public mutating func readUInt64() throws -> UInt64 {
        try ensureAvailable(8)
        let s = data.startIndex + offset
        var value: UInt64 = 0
        for i in 0..<8 {
            value = (value << 8) | UInt64(data[s + i])
        }
        offset += 8
        return value
    }

    /// Reads a syncsafe integer (4 bytes, ID3v2 format) and advances the offset.
    ///
    /// Each byte uses only 7 bits (MSB is always 0), yielding 28 effective bits.
    public mutating func readSyncsafeUInt32() throws -> UInt32 {
        try ensureAvailable(4)
        let s = data.startIndex + offset
        let value =
            UInt32(data[s] & 0x7F) << 21
            | UInt32(data[s + 1] & 0x7F) << 14
            | UInt32(data[s + 2] & 0x7F) << 7
            | UInt32(data[s + 3] & 0x7F)
        offset += 4
        return value
    }

    // MARK: - Data Reading

    /// Reads the specified number of bytes and advances the offset.
    /// - Parameter count: Number of bytes to read.
    /// - Returns: The read data.
    public mutating func readData(count: Int) throws -> Data {
        try ensureAvailable(count)
        let start = data.startIndex + offset
        offset += count
        return Data(data[start..<(start + count)])
    }

    /// Reads bytes until a null terminator (`0x00`) is found.
    ///
    /// The null terminator is consumed but not included in the result.
    public mutating func readNullTerminatedData() throws -> Data {
        let start = data.startIndex + offset
        guard let nullIndex = data[start...].firstIndex(of: 0x00) else {
            throw BinaryReaderError.unexpectedEndOfData(
                offset: offset, requested: 1, available: remainingCount
            )
        }
        let result = Data(data[start..<nullIndex])
        offset = nullIndex - data.startIndex + 1
        return result
    }

    // MARK: - String Reading

    /// Reads a Latin-1 encoded string of the given byte length.
    /// - Parameter count: Number of bytes to read.
    /// - Returns: The decoded string.
    public mutating func readLatin1String(count: Int) throws -> String {
        let savedOffset = offset
        let bytes = try readData(count: count)
        guard let string = String(data: bytes, encoding: .isoLatin1) else {
            throw BinaryReaderError.invalidEncoding(offset: savedOffset)
        }
        return string
    }

    /// Reads a UTF-8 encoded string of the given byte length.
    /// - Parameter count: Number of bytes to read.
    /// - Returns: The decoded string.
    public mutating func readUTF8String(count: Int) throws -> String {
        let savedOffset = offset
        let bytes = try readData(count: count)
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw BinaryReaderError.invalidEncoding(offset: savedOffset)
        }
        return string
    }

    /// Reads a null-terminated Latin-1 string.
    public mutating func readNullTerminatedLatin1String() throws -> String {
        let savedOffset = offset
        let bytes = try readNullTerminatedData()
        guard let string = String(data: bytes, encoding: .isoLatin1) else {
            throw BinaryReaderError.invalidEncoding(offset: savedOffset)
        }
        return string
    }

    /// Reads a null-terminated UTF-8 string.
    public mutating func readNullTerminatedUTF8String() throws -> String {
        let savedOffset = offset
        let bytes = try readNullTerminatedData()
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw BinaryReaderError.invalidEncoding(offset: savedOffset)
        }
        return string
    }

    // MARK: - Navigation

    /// Skips the specified number of bytes.
    /// - Parameter count: Number of bytes to skip.
    public mutating func skip(_ count: Int) throws {
        try ensureAvailable(count)
        offset += count
    }

    /// Seeks to an absolute offset.
    /// - Parameter offset: The target offset (must be within `0...data.count`).
    public mutating func seek(to offset: Int) throws {
        guard offset >= 0, offset <= data.count else {
            throw BinaryReaderError.seekOutOfBounds(
                offset: offset, dataSize: data.count
            )
        }
        self.offset = offset
    }

    // MARK: - Private

    private func ensureAvailable(_ count: Int) throws {
        guard remainingCount >= count else {
            throw BinaryReaderError.unexpectedEndOfData(
                offset: offset, requested: count, available: remainingCount
            )
        }
    }
}
