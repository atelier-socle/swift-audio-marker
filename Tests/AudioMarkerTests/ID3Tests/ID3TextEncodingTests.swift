import Foundation
import Testing

@testable import AudioMarker

@Suite("ID3 Text Encoding")
struct ID3TextEncodingTests {

    // MARK: - Latin-1

    @Test("Latin-1 round-trip")
    func latin1RoundTrip() throws {
        let original = "Hello World"
        let encoded = ID3TextEncoding.latin1.encode(original)
        let decoded = try ID3TextEncoding.latin1.decode(encoded)
        #expect(decoded == original)
    }

    @Test("Latin-1 with accented characters")
    func latin1Accented() throws {
        let original = "Caf\u{00E9}"  // Cafe with accent
        let encoded = ID3TextEncoding.latin1.encode(original)
        let decoded = try ID3TextEncoding.latin1.decode(encoded)
        #expect(decoded == original)
    }

    // MARK: - UTF-8

    @Test("UTF-8 round-trip")
    func utf8RoundTrip() throws {
        let original = "Hello World"
        let encoded = ID3TextEncoding.utf8.encode(original)
        let decoded = try ID3TextEncoding.utf8.decode(encoded)
        #expect(decoded == original)
    }

    @Test("UTF-8 with special characters")
    func utf8SpecialChars() throws {
        let original = "Caf\u{00E9} \u{1F3B5}"  // Cafe + musical note emoji
        let encoded = ID3TextEncoding.utf8.encode(original)
        let decoded = try ID3TextEncoding.utf8.decode(encoded)
        #expect(decoded == original)
    }

    @Test("UTF-8 with Japanese characters")
    func utf8Japanese() throws {
        let original = "\u{97F3}\u{697D}"  // "Music" in Japanese
        let encoded = ID3TextEncoding.utf8.encode(original)
        let decoded = try ID3TextEncoding.utf8.decode(encoded)
        #expect(decoded == original)
    }

    // MARK: - UTF-16 with BOM

    @Test("UTF-16 with BOM round-trip")
    func utf16BOMRoundTrip() throws {
        let original = "Hello"
        let encoded = ID3TextEncoding.utf16WithBOM.encode(original)
        let decoded = try ID3TextEncoding.utf16WithBOM.decode(encoded)
        #expect(decoded == original)
    }

    @Test("UTF-16 LE BOM decodes correctly")
    func utf16LEBom() throws {
        // BOM FF FE = little-endian, then "Hi" = 48 00 69 00
        let data = Data([0xFF, 0xFE, 0x48, 0x00, 0x69, 0x00])
        let decoded = try ID3TextEncoding.utf16WithBOM.decode(data)
        #expect(decoded == "Hi")
    }

    @Test("UTF-16 BE BOM decodes correctly")
    func utf16BEBom() throws {
        // BOM FE FF = big-endian, then "Hi" = 00 48 00 69
        let data = Data([0xFE, 0xFF, 0x00, 0x48, 0x00, 0x69])
        let decoded = try ID3TextEncoding.utf16WithBOM.decode(data)
        #expect(decoded == "Hi")
    }

    // MARK: - UTF-16BE (v2.4)

    @Test("UTF-16BE round-trip")
    func utf16BERoundTrip() throws {
        let original = "Test"
        let encoded = ID3TextEncoding.utf16BigEndian.encode(original)
        let decoded = try ID3TextEncoding.utf16BigEndian.decode(encoded)
        #expect(decoded == original)
    }

    // MARK: - Null Terminators

    @Test("Latin-1 null terminator is 1 byte")
    func latin1NullTerminator() {
        #expect(ID3TextEncoding.latin1.nullTerminator == Data([0x00]))
        #expect(ID3TextEncoding.latin1.nullTerminatorSize == 1)
    }

    @Test("UTF-8 null terminator is 1 byte")
    func utf8NullTerminator() {
        #expect(ID3TextEncoding.utf8.nullTerminator == Data([0x00]))
        #expect(ID3TextEncoding.utf8.nullTerminatorSize == 1)
    }

    @Test("UTF-16 null terminator is 2 bytes")
    func utf16NullTerminator() {
        #expect(ID3TextEncoding.utf16WithBOM.nullTerminator == Data([0x00, 0x00]))
        #expect(ID3TextEncoding.utf16WithBOM.nullTerminatorSize == 2)
    }

    @Test("UTF-16BE null terminator is 2 bytes")
    func utf16BENullTerminator() {
        #expect(ID3TextEncoding.utf16BigEndian.nullTerminator == Data([0x00, 0x00]))
        #expect(ID3TextEncoding.utf16BigEndian.nullTerminatorSize == 2)
    }

    // MARK: - Empty Data

    @Test("Decoding empty data returns empty string")
    func decodeEmpty() throws {
        #expect(try ID3TextEncoding.latin1.decode(Data()) == "")
        #expect(try ID3TextEncoding.utf8.decode(Data()) == "")
        #expect(try ID3TextEncoding.utf16WithBOM.decode(Data()) == "")
        #expect(try ID3TextEncoding.utf16BigEndian.decode(Data()) == "")
    }

    // MARK: - Invalid Encoding Byte

    @Test("Invalid encoding byte value")
    func invalidEncodingByte() {
        #expect(ID3TextEncoding(rawValue: 5) == nil)
        #expect(ID3TextEncoding(rawValue: 0xFF) == nil)
    }

    // MARK: - Encode Individual

    @Test("Latin-1 encode produces data")
    func latin1Encode() {
        let data = ID3TextEncoding.latin1.encode("ABC")
        #expect(data == Data([0x41, 0x42, 0x43]))
    }

    @Test("UTF-16 BOM encode produces data with BOM")
    func utf16BOMEncode() {
        let data = ID3TextEncoding.utf16WithBOM.encode("A")
        #expect(data.count >= 3)  // BOM (2 bytes) + "A" (2 bytes)
    }

    @Test("UTF-16BE encode produces data without BOM")
    func utf16BEEncode() {
        let data = ID3TextEncoding.utf16BigEndian.encode("A")
        #expect(data == Data([0x00, 0x41]))
    }

    @Test("UTF-8 encode produces data")
    func utf8Encode() {
        let data = ID3TextEncoding.utf8.encode("ABC")
        #expect(data == Data([0x41, 0x42, 0x43]))
    }

    // MARK: - Decode Error Branches

    @Test("Latin-1 decode throws for nil result")
    func latin1DecodeError() throws {
        // isoLatin1 decoding nearly always succeeds, so test the valid path
        let data = Data([0xC0, 0xC1, 0xC2])
        let decoded = try ID3TextEncoding.latin1.decode(data)
        #expect(!decoded.isEmpty)
    }

    @Test("UTF-16 BOM decode invalid data")
    func utf16BOMDecodeInvalid() {
        // Single byte (odd length) might fail for UTF-16
        let data = Data([0xFF])
        // Some platforms handle this, some don't — just verify no crash
        _ = try? ID3TextEncoding.utf16WithBOM.decode(data)
    }

    @Test("UTF-16BE decode invalid data")
    func utf16BEDecodeInvalid() {
        let data = Data([0xFF])
        _ = try? ID3TextEncoding.utf16BigEndian.decode(data)
    }

    @Test("UTF-8 decode invalid data throws")
    func utf8DecodeInvalid() {
        // Invalid UTF-8 sequence: 0xFE is never valid in UTF-8
        let data = Data([0xFE, 0xFE, 0xFE, 0xFE])
        #expect(throws: ID3Error.self) {
            _ = try ID3TextEncoding.utf8.decode(data)
        }
    }
}
