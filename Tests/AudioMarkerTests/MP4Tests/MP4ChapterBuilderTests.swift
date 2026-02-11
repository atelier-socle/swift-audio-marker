import Foundation
import Testing

@testable import AudioMarker

@Suite("MP4 Chapter Builder")
struct MP4ChapterBuilderTests {

    let chapterBuilder = MP4ChapterBuilder()
    let chapterParser = MP4ChapterParser()
    let atomParser = MP4AtomParser()

    // MARK: - Nero Chapters

    @Test("Builds Nero chapters with correct timestamps")
    func buildNeroChapters() throws {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .seconds(30.0), title: "Part 1"),
            Chapter(start: .seconds(60.0), title: "Part 2")
        ])

        let chplData = try #require(chapterBuilder.buildNeroChapters(from: chapters))
        let parsed = try parseChplChapters(chplData)

        #expect(parsed.count == 3)
        #expect(parsed[0].title == "Intro")
        #expect(parsed[0].start.timeInterval == 0.0)
        #expect(parsed[1].title == "Part 1")
        #expect(parsed[1].start.timeInterval == 30.0)
        #expect(parsed[2].title == "Part 2")
        #expect(parsed[2].start.timeInterval == 60.0)
    }

    @Test("Seconds to 100ns conversion is correct")
    func timestampConversion() throws {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Start"),
            Chapter(start: .seconds(1.0), title: "At 1s")
        ])

        let chplData = try #require(chapterBuilder.buildNeroChapters(from: chapters))

        // Skip atom header (8 bytes) + version (4) + reserved (4) + count (1).
        // First chapter: skip 8 bytes timestamp + 1 byte title len + title.
        // Second chapter timestamp starts after that.
        let parsed = try parseChplChapters(chplData)
        #expect(parsed[1].start.timeInterval == 1.0)
    }

    @Test("UTF-8 titles are preserved")
    func utf8Titles() throws {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Début"),
            Chapter(start: .seconds(10.0), title: "日本語チャプター")
        ])

        let chplData = try #require(chapterBuilder.buildNeroChapters(from: chapters))
        let parsed = try parseChplChapters(chplData)

        #expect(parsed[0].title == "Début")
        #expect(parsed[1].title == "日本語チャプター")
    }

    @Test("Empty chapter list returns nil")
    func emptyChapters() {
        let chapters = ChapterList()
        let result = chapterBuilder.buildNeroChapters(from: chapters)
        #expect(result == nil)
    }

    // MARK: - Round-Trip

    @Test("Round-trip: build then parse produces identical chapters")
    func roundTrip() throws {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Chapter 1"),
            Chapter(start: .seconds(120.5), title: "Chapter 2"),
            Chapter(start: .seconds(300.0), title: "Chapter 3")
        ])

        let chplData = try #require(chapterBuilder.buildNeroChapters(from: chapters))
        let parsed = try parseChplChapters(chplData)

        #expect(parsed.count == 3)
        #expect(parsed[0].title == "Chapter 1")
        #expect(parsed[1].title == "Chapter 2")
        #expect(parsed[2].title == "Chapter 3")
        #expect(parsed[0].start.timeInterval == 0.0)
        // Allow small floating-point tolerance for 120.5s.
        let diff = abs(parsed[1].start.timeInterval - 120.5)
        #expect(diff < 0.001)
        #expect(parsed[2].start.timeInterval == 300.0)
    }

    // MARK: - Test Helper

    /// Parses a chpl atom back into chapters via MP4ChapterParser.
    private func parseChplChapters(_ chplData: Data) throws -> ChapterList {
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [chplData])
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, udta])
        let ftyp = MP4TestHelper.buildFtyp()

        var file = Data()
        file.append(ftyp)
        file.append(moov)

        let url = try MP4TestHelper.createTempFile(data: file)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        return try chapterParser.parseChapters(from: atoms, reader: reader)
    }
}
