import Foundation
import Testing

@testable import AudioMarker

@Suite("ID3 Reader")
struct ID3ReaderTests {

    // MARK: - Helpers

    private func createTempFile(tagData: Data) throws -> URL {
        try ID3TestHelper.createTempFile(tagData: tagData)
    }

    // MARK: - v2.3 Complete Tag

    @Test("Reads complete v2.3 tag")
    func readV23Complete() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TIT2", text: "My Song"),
                ID3TestHelper.buildTextFrame(id: "TPE1", text: "The Artist"),
                ID3TestHelper.buildTextFrame(id: "TALB", text: "The Album"),
                ID3TestHelper.buildTextFrame(id: "TCON", text: "Rock"),
                ID3TestHelper.buildTextFrame(id: "TYER", text: "2024"),
                ID3TestHelper.buildTextFrame(id: "TRCK", text: "3/12")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.title == "My Song")
        #expect(info.metadata.artist == "The Artist")
        #expect(info.metadata.album == "The Album")
        #expect(info.metadata.genre == "Rock")
        #expect(info.metadata.year == 2024)
        #expect(info.metadata.trackNumber == 3)
    }

    // MARK: - v2.4 Complete Tag

    @Test("Reads complete v2.4 tag")
    func readV24Complete() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_4,
            frames: [
                ID3TestHelper.buildTextFrame(
                    id: "TIT2", text: "V4 Song", encoding: .utf8, version: .v2_4
                ),
                ID3TestHelper.buildTextFrame(
                    id: "TPE1", text: "V4 Artist", encoding: .utf8, version: .v2_4
                ),
                ID3TestHelper.buildTextFrame(
                    id: "TDRC", text: "2024-01-15", encoding: .utf8, version: .v2_4
                )
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.title == "V4 Song")
        #expect(info.metadata.artist == "V4 Artist")
        #expect(info.metadata.year == 2024)
    }

    // MARK: - Chapters

    @Test("Reads tag with chapters and CTOC")
    func readChapters() throws {
        let titleSub1 = ID3TestHelper.buildTextFrame(id: "TIT2", text: "Intro")
        let titleSub2 = ID3TestHelper.buildTextFrame(id: "TIT2", text: "Main")

        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildCTOCFrame(childElementIDs: ["chp1", "chp2"]),
                ID3TestHelper.buildCHAPFrame(
                    elementID: "chp1", startTime: 0,
                    endTime: 30_000, subframes: [titleSub1]
                ),
                ID3TestHelper.buildCHAPFrame(
                    elementID: "chp2", startTime: 30_000,
                    endTime: 60_000, subframes: [titleSub2]
                )
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.chapters.count == 2)
        #expect(info.chapters[0].title == "Intro")
        #expect(info.chapters[0].start == .milliseconds(0))
        #expect(info.chapters[0].end == .milliseconds(30_000))
        #expect(info.chapters[1].title == "Main")
    }

    // MARK: - Artwork

    @Test("Reads tag with artwork")
    func readArtwork() throws {
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 100)
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildAPICFrame(
                    mimeType: "image/jpeg", pictureType: 3,
                    description: "", imageData: jpegData
                )
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.artwork != nil)
        #expect(info.metadata.artwork?.format == .jpeg)
    }

    // MARK: - Synchronized Lyrics

    @Test("Reads tag with synchronized lyrics")
    func readSyncLyrics() throws {
        let events: [(text: String, timestamp: UInt32)] = [
            (text: "Hello", timestamp: 1000),
            (text: "World", timestamp: 2000)
        ]
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildSYLTFrame(
                    language: "eng", contentType: 1, events: events
                )
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.synchronizedLyrics.count == 1)

        let lyrics = info.metadata.synchronizedLyrics[0]
        #expect(lyrics.language == "eng")
        #expect(lyrics.contentType == .lyrics)
        #expect(lyrics.lines.count == 2)
        #expect(lyrics.lines[0].text == "Hello")
        #expect(lyrics.lines[1].text == "World")
    }

    // MARK: - TXXX Custom Fields

    @Test("Reads tag with TXXX custom fields")
    func readTXXX() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTXXXFrame(
                    description: "PODCAST_ID", value: "abc123"
                )
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.customTextFields["PODCAST_ID"] == "abc123")
    }

    // MARK: - PRIV and UFID

    @Test("Reads tag with PRIV and UFID")
    func readPRIVAndUFID() throws {
        let privData = Data([0x01, 0x02, 0x03])
        let ufidData = Data([0xAA, 0xBB])
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildPRIVFrame(
                    owner: "com.spotify.track", data: privData
                ),
                ID3TestHelper.buildUFIDFrame(
                    owner: "http://example.com", identifier: ufidData
                )
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.privateData.count == 1)
        #expect(info.metadata.privateData[0].owner == "com.spotify.track")
        #expect(info.metadata.uniqueFileIdentifiers.count == 1)
        #expect(info.metadata.uniqueFileIdentifiers[0].owner == "http://example.com")
    }

    // MARK: - Empty Tag

    @Test("Tag with no frames returns empty metadata")
    func emptyTag() throws {
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.title == nil)
        #expect(info.metadata.artist == nil)
        #expect(info.chapters.isEmpty)
    }

    // MARK: - Raw Frames API

    @Test("readRawFrames returns header and frames")
    func readRawFrames() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TIT2", text: "Title"),
                ID3TestHelper.buildTextFrame(id: "TPE1", text: "Artist")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let (header, frames) = try reader.readRawFrames(from: url)
        #expect(header.version == .v2_3)
        #expect(frames.count == 2)
    }
}
