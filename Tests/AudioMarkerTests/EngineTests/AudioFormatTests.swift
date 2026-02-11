import Foundation
import Testing

@testable import AudioMarker

@Suite("Audio Format")
struct AudioFormatTests {

    // MARK: - Extension Detection

    @Test("Detects MP3 from .mp3 extension")
    func detectMP3Extension() {
        #expect(AudioFormat.detect(fromExtension: "mp3") == .mp3)
    }

    @Test("Detects M4A from .m4a extension")
    func detectM4AExtension() {
        #expect(AudioFormat.detect(fromExtension: "m4a") == .m4a)
    }

    @Test("Detects M4B from .m4b extension")
    func detectM4BExtension() {
        #expect(AudioFormat.detect(fromExtension: "m4b") == .m4b)
    }

    @Test("Detects MP3 from uppercase extension")
    func detectUppercaseExtension() {
        #expect(AudioFormat.detect(fromExtension: "MP3") == .mp3)
    }

    @Test("Detects format from extension with leading dot")
    func detectExtensionWithDot() {
        #expect(AudioFormat.detect(fromExtension: ".m4a") == .m4a)
    }

    @Test("Returns nil for unknown extension")
    func unknownExtension() {
        #expect(AudioFormat.detect(fromExtension: "wav") == nil)
    }

    // MARK: - Magic Bytes Detection

    @Test("Detects MP3 from ID3 header magic bytes")
    func detectMP3ID3Magic() {
        let data = Data([0x49, 0x44, 0x33, 0x03, 0x00])
        #expect(AudioFormat.detect(fromMagicBytes: data) == .mp3)
    }

    @Test("Detects MP3 from MPEG sync word")
    func detectMP3SyncWord() {
        let data = Data([0xFF, 0xFB, 0x90, 0x00])
        #expect(AudioFormat.detect(fromMagicBytes: data) == .mp3)
    }

    @Test("Detects MP4 from ftyp magic bytes")
    func detectMP4Ftyp() {
        var writer = BinaryWriter()
        writer.writeUInt32(20)  // box size
        writer.writeLatin1String("ftyp")
        writer.writeLatin1String("M4A ")
        #expect(AudioFormat.detect(fromMagicBytes: writer.data) == .m4a)
    }

    @Test("Detects M4B from ftyp major brand")
    func detectM4BFromBrand() {
        var writer = BinaryWriter()
        writer.writeUInt32(20)
        writer.writeLatin1String("ftyp")
        writer.writeLatin1String("M4B ")
        #expect(AudioFormat.detect(fromMagicBytes: writer.data) == .m4b)
    }

    @Test("Returns nil for unrecognized magic bytes")
    func unrecognizedMagic() {
        let data = Data([0x00, 0x01, 0x02, 0x03])
        #expect(AudioFormat.detect(fromMagicBytes: data) == nil)
    }

    @Test("Returns nil for data shorter than 2 bytes")
    func tooShortData() {
        #expect(AudioFormat.detect(fromMagicBytes: Data([0xFF])) == nil)
    }

    // MARK: - File Detection

    @Test("Detects MP3 from file")
    func detectMP3FromFile() throws {
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let format = try AudioFormat.detect(from: url)
        #expect(format == .mp3)
    }

    @Test("Detects M4A from file")
    func detectM4AFromFile() throws {
        let data = MP4TestHelper.buildMinimalMP4()
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let format = try AudioFormat.detect(from: url)
        #expect(format == .m4a)
    }

    // MARK: - Properties

    @Test("Has three cases")
    func caseCount() {
        #expect(AudioFormat.allCases.count == 3)
    }

    @Test("MP3 uses ID3")
    func mp3UsesID3() {
        #expect(AudioFormat.mp3.usesID3)
        #expect(!AudioFormat.mp3.usesMP4)
    }

    @Test("M4A uses MP4")
    func m4aUsesMP4() {
        #expect(!AudioFormat.m4a.usesID3)
        #expect(AudioFormat.m4a.usesMP4)
    }

    @Test("M4B uses MP4")
    func m4bUsesMP4() {
        #expect(!AudioFormat.m4b.usesID3)
        #expect(AudioFormat.m4b.usesMP4)
    }

    @Test("File extensions are correct")
    func fileExtensions() {
        #expect(AudioFormat.mp3.fileExtensions == ["mp3"])
        #expect(AudioFormat.m4a.fileExtensions == ["m4a"])
        #expect(AudioFormat.m4b.fileExtensions == ["m4b"])
    }
}
