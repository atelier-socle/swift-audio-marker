import Foundation
import Testing

@testable import AudioMarker

@Suite("Binary Writer")
struct BinaryWriterTests {

    // MARK: - Integer Writing

    @Test("Writes UInt8")
    func writeUInt8() {
        var writer = BinaryWriter()
        writer.writeUInt8(0x42)
        #expect(writer.data == Data([0x42]))
    }

    @Test("Writes big-endian UInt16")
    func writeUInt16() {
        var writer = BinaryWriter()
        writer.writeUInt16(256)
        #expect(writer.data == Data([0x01, 0x00]))
    }

    @Test("Writes big-endian UInt32")
    func writeUInt32() {
        var writer = BinaryWriter()
        writer.writeUInt32(65_536)
        #expect(writer.data == Data([0x00, 0x01, 0x00, 0x00]))
    }

    @Test("Writes big-endian UInt64")
    func writeUInt64() {
        var writer = BinaryWriter()
        writer.writeUInt64(65_536)
        #expect(
            writer.data == Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00])
        )
    }

    @Test("Writes syncsafe UInt32")
    func writeSyncsafe() {
        var writer = BinaryWriter()
        writer.writeSyncsafeUInt32(128)
        // 128 = (0 << 21) | (0 << 14) | (1 << 7) | 0
        #expect(writer.data == Data([0x00, 0x00, 0x01, 0x00]))
    }

    // MARK: - Data Writing

    @Test("Writes raw data")
    func writeData() {
        var writer = BinaryWriter()
        writer.writeData(Data([0xAA, 0xBB]))
        #expect(writer.data == Data([0xAA, 0xBB]))
    }

    @Test("Writes null byte")
    func writeNull() {
        var writer = BinaryWriter()
        writer.writeNullByte()
        #expect(writer.data == Data([0x00]))
    }

    @Test("Writes repeating bytes")
    func writeRepeating() {
        var writer = BinaryWriter()
        writer.writeRepeating(0xFF, count: 4)
        #expect(writer.data == Data([0xFF, 0xFF, 0xFF, 0xFF]))
    }

    // MARK: - String Writing

    @Test("Writes Latin-1 string")
    func writeLatin1() {
        var writer = BinaryWriter()
        writer.writeLatin1String("Hi")
        #expect(writer.data == Data([0x48, 0x69]))
    }

    @Test("Writes UTF-8 string")
    func writeUTF8() {
        var writer = BinaryWriter()
        writer.writeUTF8String("OK")
        #expect(writer.data == Data([0x4F, 0x4B]))
    }

    @Test("Writes null-terminated Latin-1 string")
    func writeNullTerminatedLatin1() {
        var writer = BinaryWriter()
        writer.writeNullTerminatedLatin1String("Hi")
        #expect(writer.data == Data([0x48, 0x69, 0x00]))
    }

    @Test("Writes null-terminated UTF-8 string")
    func writeNullTerminatedUTF8() {
        var writer = BinaryWriter()
        writer.writeNullTerminatedUTF8String("OK")
        #expect(writer.data == Data([0x4F, 0x4B, 0x00]))
    }

    // MARK: - Properties

    @Test("Count reflects written bytes")
    func count() {
        var writer = BinaryWriter()
        #expect(writer.count == 0)
        writer.writeUInt16(0)
        #expect(writer.count == 2)
    }

    @Test("Init with capacity does not affect initial count")
    func initWithCapacity() {
        let writer = BinaryWriter(capacity: 1024)
        #expect(writer.count == 0)
    }

    // MARK: - Round-trips

    @Test("UInt32 round-trip through writer and reader")
    func roundTripUInt32() throws {
        var writer = BinaryWriter()
        writer.writeUInt32(305_419_896)  // 0x12345678

        var reader = BinaryReader(data: writer.data)
        let value = try reader.readUInt32()
        #expect(value == 305_419_896)
    }

    @Test("Syncsafe UInt32 round-trip")
    func roundTripSyncsafe() throws {
        let original: UInt32 = 128
        var writer = BinaryWriter()
        writer.writeSyncsafeUInt32(original)

        var reader = BinaryReader(data: writer.data)
        let value = try reader.readSyncsafeUInt32()
        #expect(value == original)
    }

    @Test("Null-terminated UTF-8 string round-trip")
    func roundTripString() throws {
        var writer = BinaryWriter()
        writer.writeNullTerminatedUTF8String("Hello")

        var reader = BinaryReader(data: writer.data)
        let value = try reader.readNullTerminatedUTF8String()
        #expect(value == "Hello")
    }

    @Test("Mixed types round-trip")
    func roundTripMixed() throws {
        var writer = BinaryWriter()
        writer.writeUInt8(0x01)
        writer.writeUInt16(1000)
        writer.writeNullTerminatedUTF8String("ID3")
        writer.writeUInt32(42)

        var reader = BinaryReader(data: writer.data)
        #expect(try reader.readUInt8() == 0x01)
        #expect(try reader.readUInt16() == 1000)
        #expect(try reader.readNullTerminatedUTF8String() == "ID3")
        #expect(try reader.readUInt32() == 42)
        #expect(!reader.hasRemaining)
    }
}
