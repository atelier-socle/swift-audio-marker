import Foundation
import Testing

@testable import AudioMarker

@Suite("ID3 Frame Builder")
struct ID3FrameBuilderTests {

    // MARK: - Text Frames

    @Test("Builds Latin-1 text frame for v2.3")
    func textFrameLatin1V23() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let data = builder.buildFrame(.text(id: "TIT2", text: "Hello World"))
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == .text(id: "TIT2", text: "Hello World"))
    }

    @Test("Builds UTF-8 text frame for v2.4")
    func textFrameUTF8V24() throws {
        let builder = ID3FrameBuilder(version: .v2_4)
        let data = builder.buildFrame(.text(id: "TIT2", text: "Caf\u{00E9}"))
        let frame = try parseBack(data, version: .v2_4)
        #expect(frame == .text(id: "TIT2", text: "Caf\u{00E9}"))
    }

    @Test("Falls back to UTF-16 for non-Latin-1 text in v2.3")
    func textFrameUTF16FallbackV23() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let data = builder.buildFrame(.text(id: "TIT2", text: "\u{1F3B5} Music"))
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == .text(id: "TIT2", text: "\u{1F3B5} Music"))
    }

    @Test("Builds all standard text frame IDs")
    func allTextFrameIDs() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let ids = ["TIT2", "TPE1", "TALB", "TCON", "TRCK", "TYER", "TPE2", "TCOM", "TPUB"]
        for id in ids {
            let data = builder.buildFrame(.text(id: id, text: "value"))
            let frame = try parseBack(data, version: .v2_3)
            #expect(frame == .text(id: id, text: "value"))
        }
    }

    // MARK: - User-Defined Text Frame

    @Test("Builds TXXX frame round-trip")
    func userDefinedTextFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let original = ID3Frame.userDefinedText(description: "REPLAYGAIN", value: "-6.5 dB")
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    // MARK: - URL Frames

    @Test("Builds URL frame round-trip")
    func urlFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let original = ID3Frame.url(id: "WOAR", url: "https://example.com/artist")
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    @Test("Builds WXXX frame round-trip")
    func userDefinedURLFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let original = ID3Frame.userDefinedURL(
            description: "podcast", url: "https://example.com/feed")
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    // MARK: - Comment Frame

    @Test("Builds COMM frame round-trip")
    func commentFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let original = ID3Frame.comment(
            language: "eng", description: "", text: "A great track")
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    // MARK: - Attached Picture Frame

    @Test("Builds APIC frame round-trip")
    func attachedPictureFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        let original = ID3Frame.attachedPicture(
            pictureType: 3, mimeType: "image/jpeg",
            description: "Cover", data: jpegData)
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    // MARK: - Chapter Frame

    @Test("Builds CHAP frame with subframes round-trip")
    func chapterFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let original = ID3Frame.chapter(
            elementID: "chp1", startTime: 0, endTime: 60_000,
            subframes: [.text(id: "TIT2", text: "Chapter 1")])
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)

        guard case .chapter(let elementID, let start, let end, let subs) = frame else {
            Issue.record("Expected chapter frame")
            return
        }
        #expect(elementID == "chp1")
        #expect(start == 0)
        #expect(end == 60_000)
        #expect(subs.count == 1)
        #expect(subs.first == .text(id: "TIT2", text: "Chapter 1"))
    }

    // MARK: - Table of Contents Frame

    @Test("Builds CTOC frame round-trip")
    func tableOfContentsFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let original = ID3Frame.tableOfContents(
            elementID: "toc1", isTopLevel: true, isOrdered: true,
            childElementIDs: ["chp1", "chp2"], subframes: [])
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)

        guard
            case .tableOfContents(
                let elementID, let isTopLevel, let isOrdered, let childIDs, _
            ) = frame
        else {
            Issue.record("Expected CTOC frame")
            return
        }
        #expect(elementID == "toc1")
        #expect(isTopLevel)
        #expect(isOrdered)
        #expect(childIDs == ["chp1", "chp2"])
    }

    // MARK: - Lyrics Frames

    @Test("Builds USLT frame round-trip")
    func unsyncLyricsFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let original = ID3Frame.unsyncLyrics(
            language: "eng", description: "", text: "These are lyrics.")
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    @Test("Builds SYLT frame round-trip")
    func syncLyricsFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let events = [
            SyncLyricEvent(text: "Line one", timestamp: 0),
            SyncLyricEvent(text: "Line two", timestamp: 5000)
        ]
        let original = ID3Frame.syncLyrics(
            language: "eng", contentType: 1, description: "", events: events)
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)

        guard case .syncLyrics(let lang, let ct, _, let parsedEvents) = frame else {
            Issue.record("Expected SYLT frame")
            return
        }
        #expect(lang == "eng")
        #expect(ct == 1)
        #expect(parsedEvents.count == 2)
        #expect(parsedEvents[0].text == "Line one")
        #expect(parsedEvents[0].timestamp == 0)
        #expect(parsedEvents[1].text == "Line two")
        #expect(parsedEvents[1].timestamp == 5000)
    }

    // MARK: - Data Frames

    @Test("Builds PRIV frame round-trip")
    func privateDataFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let privateBytes = Data([0x01, 0x02, 0x03])
        let original = ID3Frame.privateData(owner: "com.example.test", data: privateBytes)
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    @Test("Builds UFID frame round-trip")
    func uniqueFileIDFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let identifier = Data([0xAA, 0xBB, 0xCC])
        let original = ID3Frame.uniqueFileID(owner: "http://id3.org/dummy", identifier: identifier)
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    @Test("Builds PCNT frame round-trip")
    func playCounterFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let original = ID3Frame.playCounter(count: 42)
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    @Test("Builds POPM frame round-trip")
    func popularimeterFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let original = ID3Frame.popularimeter(
            email: "user@example.com", rating: 196, playCount: 100)
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    // MARK: - Unknown Frame

    @Test("Builds unknown frame as passthrough")
    func unknownFrame() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let content = Data([0x01, 0x02, 0x03])
        let original = ID3Frame.unknown(id: "ZZZZ", data: content)
        let data = builder.buildFrame(original)
        let frame = try parseBack(data, version: .v2_3)
        #expect(frame == original)
    }

    // MARK: - Frame Size Encoding

    @Test("v2.3 frame uses regular UInt32 size")
    func frameSizeV23() {
        let builder = ID3FrameBuilder(version: .v2_3)
        let data = builder.buildFrame(.text(id: "TIT2", text: "Test"))
        // Frame header: 4 (ID) + 4 (size) + 2 (flags) = 10 bytes
        // Content: 1 (encoding) + 4 (text) = 5 bytes
        var reader = BinaryReader(data: data)
        _ = try? reader.readData(count: 4)  // Skip ID
        let size = try? reader.readUInt32()
        #expect(size == 5)
    }

    @Test("v2.4 frame uses syncsafe UInt32 size")
    func frameSizeV24() {
        let builder = ID3FrameBuilder(version: .v2_4)
        let data = builder.buildFrame(.text(id: "TIT2", text: "Test"))
        var reader = BinaryReader(data: data)
        _ = try? reader.readData(count: 4)  // Skip ID
        let size = try? reader.readSyncsafeUInt32()
        #expect(size == 5)
    }

    // MARK: - Encoding Strategy

    @Test("v2.3 uses Latin-1 for ASCII text")
    func encodingStrategyLatin1() {
        let builder = ID3FrameBuilder(version: .v2_3)
        let data = builder.buildFrame(.text(id: "TIT2", text: "Hello"))
        // Byte at offset 10 is the encoding byte
        #expect(data[10] == 0x00)  // Latin-1
    }

    @Test("v2.4 always uses UTF-8")
    func encodingStrategyUTF8() {
        let builder = ID3FrameBuilder(version: .v2_4)
        let data = builder.buildFrame(.text(id: "TIT2", text: "Hello"))
        #expect(data[10] == 0x03)  // UTF-8
    }

    @Test("v2.3 uses UTF-16 for non-Latin-1 text")
    func encodingStrategyUTF16() {
        let builder = ID3FrameBuilder(version: .v2_3)
        let data = builder.buildFrame(.text(id: "TIT2", text: "\u{1F3B5}"))
        #expect(data[10] == 0x01)  // UTF-16 with BOM
    }

    // MARK: - Language Sanitization

    @Test("Short language code is padded to 3 characters")
    func shortLanguagePadded() throws {
        let builder = ID3FrameBuilder(version: .v2_3)
        let data = builder.buildFrame(
            .comment(language: "en", description: "", text: "test"))
        let frame = try parseBack(data, version: .v2_3)
        guard case .comment(let lang, _, _) = frame else {
            Issue.record("Expected comment frame")
            return
        }
        #expect(lang.count == 3)
    }

    // MARK: - Helpers

    private func parseBack(_ data: Data, version: ID3Version) throws -> ID3Frame {
        var reader = BinaryReader(data: data)
        let parser = ID3FrameParser(version: version)
        let frame = try parser.parseFrame(&reader)
        return try #require(frame)
    }
}
