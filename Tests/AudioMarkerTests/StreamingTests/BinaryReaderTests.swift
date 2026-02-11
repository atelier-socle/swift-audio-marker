import Foundation
import Testing

@testable import AudioMarker

@Suite("Binary Reader")
struct BinaryReaderTests {

    // MARK: - Integer Reading

    @Test("Reads UInt8")
    func readUInt8() throws {
        var reader = BinaryReader(data: Data([0x42]))
        let value = try reader.readUInt8()
        #expect(value == 0x42)
        #expect(reader.offset == 1)
    }

    @Test("Reads big-endian UInt16")
    func readUInt16() throws {
        var reader = BinaryReader(data: Data([0x01, 0x00]))
        let value = try reader.readUInt16()
        #expect(value == 256)
    }

    @Test("Reads big-endian UInt32")
    func readUInt32() throws {
        var reader = BinaryReader(data: Data([0x00, 0x01, 0x00, 0x00]))
        let value = try reader.readUInt32()
        #expect(value == 65_536)
    }

    @Test("Reads big-endian UInt64")
    func readUInt64() throws {
        var reader = BinaryReader(
            data: Data([
                0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00
            ]))
        let value = try reader.readUInt64()
        #expect(value == 65_536)
    }

    @Test("Reads syncsafe UInt32 (128)")
    func readSyncsafe128() throws {
        // Syncsafe: each byte uses 7 bits. 0x00 0x00 0x01 0x00 = 128
        var reader = BinaryReader(data: Data([0x00, 0x00, 0x01, 0x00]))
        let value = try reader.readSyncsafeUInt32()
        #expect(value == 128)
    }

    @Test("Reads syncsafe UInt32 (257)")
    func readSyncsafe257() throws {
        // 257 = (0 << 21) | (0 << 14) | (2 << 7) | 1
        var reader = BinaryReader(data: Data([0x00, 0x00, 0x02, 0x01]))
        let value = try reader.readSyncsafeUInt32()
        #expect(value == 257)
    }

    // MARK: - Data Reading

    @Test("Reads data by count")
    func readData() throws {
        var reader = BinaryReader(data: Data([0x01, 0x02, 0x03, 0x04]))
        let chunk = try reader.readData(count: 2)
        #expect(chunk == Data([0x01, 0x02]))
        #expect(reader.offset == 2)
    }

    @Test("Reads null-terminated data")
    func readNullTerminated() throws {
        var reader = BinaryReader(data: Data([0x48, 0x69, 0x00, 0xFF]))
        let result = try reader.readNullTerminatedData()
        #expect(result == Data([0x48, 0x69]))
        #expect(reader.offset == 3)
    }

    @Test("Reads null-terminated data starting with null")
    func readNullTerminatedEmpty() throws {
        var reader = BinaryReader(data: Data([0x00, 0xFF]))
        let result = try reader.readNullTerminatedData()
        #expect(result.isEmpty)
        #expect(reader.offset == 1)
    }

    // MARK: - String Reading

    @Test("Reads Latin-1 string")
    func readLatin1() throws {
        let bytes: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F]  // "Hello"
        var reader = BinaryReader(data: Data(bytes))
        let string = try reader.readLatin1String(count: 5)
        #expect(string == "Hello")
    }

    @Test("Reads UTF-8 string")
    func readUTF8() throws {
        let bytes = Array("Café".utf8)
        var reader = BinaryReader(data: Data(bytes))
        let string = try reader.readUTF8String(count: bytes.count)
        #expect(string == "Café")
    }

    @Test("Reads null-terminated Latin-1 string")
    func readNullTerminatedLatin1() throws {
        let bytes: [UInt8] = [0x48, 0x69, 0x00]  // "Hi\0"
        var reader = BinaryReader(data: Data(bytes))
        let string = try reader.readNullTerminatedLatin1String()
        #expect(string == "Hi")
    }

    @Test("Reads null-terminated UTF-8 string")
    func readNullTerminatedUTF8() throws {
        var bytes = Array("OK".utf8)
        bytes.append(0x00)
        var reader = BinaryReader(data: Data(bytes))
        let string = try reader.readNullTerminatedUTF8String()
        #expect(string == "OK")
    }

    // MARK: - Navigation

    @Test("Skip advances offset")
    func skip() throws {
        var reader = BinaryReader(data: Data([0x01, 0x02, 0x03, 0x04]))
        try reader.skip(2)
        #expect(reader.offset == 2)
        let value = try reader.readUInt8()
        #expect(value == 0x03)
    }

    @Test("Seek moves to absolute offset")
    func seek() throws {
        var reader = BinaryReader(data: Data([0x01, 0x02, 0x03]))
        try reader.seek(to: 2)
        #expect(reader.offset == 2)
        let value = try reader.readUInt8()
        #expect(value == 0x03)
    }

    @Test("Seek to data.count is valid (end position)")
    func seekToEnd() throws {
        var reader = BinaryReader(data: Data([0x01, 0x02]))
        try reader.seek(to: 2)
        #expect(reader.offset == 2)
        #expect(!reader.hasRemaining)
    }

    // MARK: - Remaining Count

    @Test("remainingCount reflects bytes left")
    func remainingCount() throws {
        var reader = BinaryReader(data: Data([0x01, 0x02, 0x03]))
        #expect(reader.remainingCount == 3)
        _ = try reader.readUInt8()
        #expect(reader.remainingCount == 2)
    }

    @Test("hasRemaining is true when data remains")
    func hasRemaining() {
        let reader = BinaryReader(data: Data([0x01]))
        #expect(reader.hasRemaining)
    }

    @Test("hasRemaining is false for empty data")
    func hasRemainingEmpty() {
        let reader = BinaryReader(data: Data())
        #expect(!reader.hasRemaining)
    }

    // MARK: - Errors

    @Test("Read past end throws unexpectedEndOfData")
    func readPastEnd() {
        var reader = BinaryReader(data: Data([0x01]))
        #expect(throws: BinaryReaderError.self) {
            _ = try reader.readUInt16()
        }
    }

    @Test("Seek out of bounds throws seekOutOfBounds")
    func seekOutOfBounds() {
        var reader = BinaryReader(data: Data([0x01, 0x02]))
        #expect(throws: BinaryReaderError.self) {
            try reader.seek(to: 5)
        }
    }

    @Test("Seek to negative offset throws seekOutOfBounds")
    func seekNegative() {
        var reader = BinaryReader(data: Data([0x01]))
        #expect(throws: BinaryReaderError.self) {
            try reader.seek(to: -1)
        }
    }

    @Test("Null-terminated read without null throws")
    func nullTerminatedNoNull() {
        var reader = BinaryReader(data: Data([0x48, 0x69]))
        #expect(throws: BinaryReaderError.self) {
            _ = try reader.readNullTerminatedData()
        }
    }

    // MARK: - Sequential reads

    @Test("Sequential reads advance offset correctly")
    func sequentialReads() throws {
        var reader = BinaryReader(data: Data([0xAA, 0x00, 0x01, 0xBB]))
        let a = try reader.readUInt8()
        let b = try reader.readUInt16()
        let c = try reader.readUInt8()
        #expect(a == 0xAA)
        #expect(b == 1)
        #expect(c == 0xBB)
        #expect(reader.offset == 4)
        #expect(!reader.hasRemaining)
    }
}
