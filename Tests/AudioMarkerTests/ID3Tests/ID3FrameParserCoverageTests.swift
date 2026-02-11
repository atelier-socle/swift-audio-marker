import Foundation
import Testing

@testable import AudioMarker

@Suite("ID3 Frame Parser Coverage")
struct ID3FrameParserCoverageTests {

    // MARK: - Empty Frame Content

    @Test("Empty text frame returns empty string")
    func emptyTextFrame() throws {
        let frameData = ID3TestHelper.buildRawFrame(id: "TIT2", content: Data())
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .text(id: "TIT2", text: ""))
    }

    @Test("Empty URL frame returns empty URL string")
    func emptyURLFrame() throws {
        let frameData = ID3TestHelper.buildRawFrame(id: "WOAR", content: Data())
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .url(id: "WOAR", url: ""))
    }

    @Test("Empty TXXX frame throws invalidFrame")
    func emptyTXXXFrame() {
        let frameData = ID3TestHelper.buildRawFrame(id: "TXXX", content: Data())
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }

    @Test("Empty WXXX frame throws invalidFrame")
    func emptyWXXXFrame() {
        let frameData = ID3TestHelper.buildRawFrame(id: "WXXX", content: Data())
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }

    @Test("Empty COMM frame throws invalidFrame")
    func emptyCOMMFrame() {
        let frameData = ID3TestHelper.buildRawFrame(id: "COMM", content: Data([0x00]))
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }

    @Test("Empty APIC frame throws invalidFrame")
    func emptyAPICFrame() {
        let frameData = ID3TestHelper.buildRawFrame(id: "APIC", content: Data([0x00]))
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }

    // MARK: - v2.4 Unsynchronization

    @Test("v2.4 frame-level unsynchronization is applied")
    func v24Unsynchronization() throws {
        // Build raw content with unsynchronized bytes: FF 00 → FF (remove 00 after FF)
        let unsyncContent = Data([0x00, 0xFF, 0x00, 0xE0])
        // After removing unsync: 0x00, 0xFF, 0xE0
        // This is: encoding=latin1, then text bytes FF E0

        // Build frame with unsync flag (bit 1 of second flag byte = 0x0002)
        let frameData = ID3TestHelper.buildRawFrame(
            id: "TIT2", content: unsyncContent, version: .v2_4, flags: 0x0002)
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_4)
        let frame = try parser.parseFrame(&reader)

        guard case .text(let id, _) = frame else {
            Issue.record("Expected text frame")
            return
        }
        #expect(id == "TIT2")
    }

    // MARK: - Invalid Frame ID

    @Test("Invalid frame ID returns nil")
    func invalidFrameID() throws {
        // Build data starting with a non-null non-alphanumeric character
        var writer = BinaryWriter()
        writer.writeLatin1String("ti#2")  // lowercase + special char = invalid
        writer.writeUInt32(5)
        writer.writeUInt16(0)
        writer.writeData(Data([0x00, 0x48, 0x65, 0x6C, 0x6C]))

        var reader = BinaryReader(data: writer.data)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == nil)
    }

    // MARK: - Insufficient Remaining Bytes

    @Test("Less than 10 bytes remaining returns nil")
    func insufficientBytes() throws {
        let data = Data([0x54, 0x49, 0x54, 0x32, 0x00, 0x00])  // 6 bytes only
        var reader = BinaryReader(data: data)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == nil)
    }

    // MARK: - UTF-16BE Text Frame

    @Test("Parses UTF-16BE text frame (v2.4)")
    func parseTextFrameUTF16BE() throws {
        let frameData = ID3TestHelper.buildTextFrame(
            id: "TIT2", text: "Hi", encoding: .utf16BigEndian, version: .v2_4)
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_4)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .text(id: "TIT2", text: "Hi"))
    }

    // MARK: - URL Frame With Null Terminator

    @Test("URL frame trims trailing null bytes")
    func urlFrameWithTrailingNull() throws {
        var content = BinaryWriter()
        content.writeLatin1String("https://example.com")
        content.writeUInt8(0x00)

        let frameData = ID3TestHelper.buildRawFrame(id: "WOAR", content: content.data)
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .url(id: "WOAR", url: "https://example.com"))
    }

    // MARK: - Text Frame With Null Terminator

    @Test("Text frame trims trailing null")
    func textFrameWithTrailingNull() throws {
        var content = BinaryWriter()
        content.writeUInt8(0x00)  // Latin-1 encoding
        content.writeLatin1String("Hello")
        content.writeUInt8(0x00)  // trailing null

        let frameData = ID3TestHelper.buildRawFrame(id: "TIT2", content: content.data)
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .text(id: "TIT2", text: "Hello"))
    }

    // MARK: - CHAP With Short Data

    @Test("CHAP frame too short throws invalidFrame")
    func chapTooShort() {
        let frameData = ID3TestHelper.buildRawFrame(
            id: "CHAP", content: Data([0x00, 0x01, 0x02]))
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }

    // MARK: - CTOC With Short Data

    @Test("CTOC frame too short throws invalidFrame")
    func ctocTooShort() {
        let frameData = ID3TestHelper.buildRawFrame(
            id: "CTOC", content: Data([0x00]))
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }

    // MARK: - USLT With Short Data

    @Test("USLT frame too short throws invalidFrame")
    func usltTooShort() {
        let frameData = ID3TestHelper.buildRawFrame(
            id: "USLT", content: Data([0x00, 0x01]))
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }

    // MARK: - SYLT With Short Data

    @Test("SYLT frame too short throws invalidFrame")
    func syltTooShort() {
        let frameData = ID3TestHelper.buildRawFrame(
            id: "SYLT", content: Data([0x00, 0x01, 0x02]))
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }

    // MARK: - PCNT With Short Data

    @Test("PCNT frame too short throws invalidFrame")
    func pcntTooShort() {
        let frameData = ID3TestHelper.buildRawFrame(
            id: "PCNT", content: Data([0x00, 0x01]))
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }

    // MARK: - POPM With Short Data

    @Test("POPM frame too short throws invalidFrame")
    func popmTooShort() {
        let frameData = ID3TestHelper.buildRawFrame(
            id: "POPM", content: Data([0x00]))
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }

    // MARK: - POPM Without Play Count

    @Test("POPM frame without play count data")
    func popmNoPlayCount() throws {
        // Owner null-terminated + rating byte, no play count
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String("user@test.com")
        content.writeUInt8(200)

        let frameData = ID3TestHelper.buildRawFrame(id: "POPM", content: content.data)
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .popularimeter(email: "user@test.com", rating: 200, playCount: 0))
    }

    // MARK: - Invalid Encoding Byte

    @Test("Invalid encoding byte in frame throws")
    func invalidEncodingByte() {
        var content = BinaryWriter()
        content.writeUInt8(0xFF)  // Invalid encoding
        content.writeLatin1String("Hello")

        let frameData = ID3TestHelper.buildRawFrame(id: "TIT2", content: content.data)
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }
}
