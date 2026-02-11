import Foundation
import Testing

@testable import AudioMarker

@Suite("ID3 Writer")
struct ID3WriterTests {

    private let fakeAudio = Data(repeating: 0xFF, count: 256)

    // MARK: - Write

    @Test("Writes tag to file without existing tag")
    func writeToFileWithoutTag() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "New Title"
        info.metadata.artist = "New Artist"

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "New Title")
        #expect(result.metadata.artist == "New Artist")
    }

    @Test("Writes tag replacing existing tag")
    func writeReplacesExistingTag() throws {
        let existingTag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Old Title")])
        let url = try createTempFile(tagData: existingTag)
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "New Title"

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "New Title")
    }

    @Test("Audio data preserved after write")
    func audioDataPreservedAfterWrite() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "Test"

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let (header, _) = try reader.readRawFrames(from: url)
        let audioOffset = 10 + Int(header.tagSize)

        let fileData = try Data(contentsOf: url)
        let audioData = Data(fileData[audioOffset...])
        #expect(audioData == fakeAudio)
    }

    // MARK: - In-Place Optimization

    @Test("In-place write when new tag fits in existing space")
    func inPlaceWrite() throws {
        // Create a tag with 4096 bytes of padding to ensure plenty of space
        let existingTag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Old")])
        var paddedTag = existingTag
        paddedTag.append(Data(repeating: 0x00, count: 4096))

        // Manually rebuild with correct size
        let tagBuilder = ID3TagBuilder(version: .v2_3)
        var tempInfo = AudioFileInfo()
        tempInfo.metadata.title = "Old"
        let bigTag = tagBuilder.buildTag(from: tempInfo, padding: 4096)
        let url = try createTempFile(tagData: bigTag)
        defer { cleanup(url) }

        let originalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64

        var info = AudioFileInfo()
        info.metadata.title = "New"

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let newSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64
        // In-place write should keep same file size
        #expect(originalSize == newSize)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "New")
    }

    @Test("Temp file write when new tag is larger than existing space")
    func tempFileWrite() throws {
        // Create a minimal tag (small space)
        let tagBuilder = ID3TagBuilder(version: .v2_3)
        var tempInfo = AudioFileInfo()
        tempInfo.metadata.title = "X"
        let smallTag = tagBuilder.buildTag(from: tempInfo, padding: 0)
        let url = try createTempFile(tagData: smallTag)
        defer { cleanup(url) }

        // Write a much larger tag
        var info = AudioFileInfo()
        info.metadata.title = String(repeating: "A", count: 500)
        info.metadata.artist = String(repeating: "B", count: 500)

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == String(repeating: "A", count: 500))
        #expect(result.metadata.artist == String(repeating: "B", count: 500))
    }

    // MARK: - Modify

    @Test("Modify preserves unknown frames")
    func modifyPreservesUnknownFrames() throws {
        let unknownContent = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let existingTag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TIT2", text: "Old Title"),
                ID3TestHelper.buildRawFrame(id: "ZZZZ", content: unknownContent)
            ])
        let url = try createTempFile(tagData: existingTag)
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "New Title"

        let writer = ID3Writer()
        try writer.modify(info, in: url)

        let reader = ID3Reader()
        let (_, frames) = try reader.readRawFrames(from: url)
        let unknownFrames = frames.filter {
            if case .unknown = $0 { return true }
            return false
        }
        #expect(unknownFrames.count == 1)
        #expect(unknownFrames.first == .unknown(id: "ZZZZ", data: unknownContent))

        let result = try reader.read(from: url)
        #expect(result.metadata.title == "New Title")
    }

    @Test("Modify in-place when new tag fits in existing space")
    func modifyInPlace() throws {
        // Create a file with a large tag (lots of padding)
        let tagBuilder = ID3TagBuilder(version: .v2_3)
        var tempInfo = AudioFileInfo()
        tempInfo.metadata.title = "Old"
        let bigTag = tagBuilder.buildTag(from: tempInfo, padding: 4096)
        let url = try createTempFile(tagData: bigTag)
        defer { cleanup(url) }

        let originalSize =
            try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64

        var info = AudioFileInfo()
        info.metadata.title = "New"

        let writer = ID3Writer()
        try writer.modify(info, in: url)

        let newSize =
            try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64
        // In-place write keeps same file size
        #expect(originalSize == newSize)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "New")
    }

    @Test("Modify uses existing tag version when none specified")
    func modifyUsesExistingVersion() throws {
        let tagBuilder = ID3TagBuilder(version: .v2_4)
        var tempInfo = AudioFileInfo()
        tempInfo.metadata.title = "Old"
        let v24Tag = tagBuilder.buildTag(from: tempInfo, padding: 256)
        let url = try createTempFile(tagData: v24Tag)
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "Updated"

        let writer = ID3Writer()
        try writer.modify(info, in: url)

        let reader = ID3Reader()
        let (header, _) = try reader.readRawFrames(from: url)
        #expect(header.version == .v2_4)
    }

    @Test("Modify on file without tag behaves like write")
    func modifyWithoutExistingTag() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "Created"

        let writer = ID3Writer()
        try writer.modify(info, in: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "Created")
    }

    // MARK: - Strip Tag

    @Test("Strips tag from file with existing tag")
    func stripExistingTag() throws {
        let existingTag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Title")])
        let url = try createTempFile(tagData: existingTag)
        defer { cleanup(url) }

        let writer = ID3Writer()
        try writer.stripTag(from: url)

        let fileData = try Data(contentsOf: url)
        // File should only contain audio data
        #expect(fileData == fakeAudio)
    }

    @Test("Strip on file without tag is no-op")
    func stripNoTag() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        let originalData = try Data(contentsOf: url)

        let writer = ID3Writer()
        try writer.stripTag(from: url)

        let afterData = try Data(contentsOf: url)
        #expect(originalData == afterData)
    }

    // MARK: - Round-Trip

    @Test("Full round-trip: write then read matches AudioFileInfo")
    func fullRoundTrip() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.metadata.title = "Podcast Episode"
        info.metadata.artist = "Host"
        info.metadata.album = "Podcast Name"
        info.metadata.genre = "Podcast"
        info.metadata.year = 2024
        info.metadata.trackNumber = 42
        info.metadata.comment = "A great episode"
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "Intro",
                end: .milliseconds(60_000)),
            Chapter(
                start: .milliseconds(60_000), title: "Main",
                end: .milliseconds(300_000)),
            Chapter(
                start: .milliseconds(300_000), title: "Outro",
                end: .milliseconds(360_000))
        ])

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.metadata.title == "Podcast Episode")
        #expect(result.metadata.artist == "Host")
        #expect(result.metadata.album == "Podcast Name")
        #expect(result.metadata.genre == "Podcast")
        #expect(result.metadata.year == 2024)
        #expect(result.metadata.trackNumber == 42)
        #expect(result.metadata.comment == "A great episode")
        #expect(result.chapters.count == 3)
    }

    @Test("Round-trip preserves chapter details")
    func roundTripChapterDetails() throws {
        let url = try createTempFile(tagData: Data())
        defer { cleanup(url) }

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "Chapter 1",
                end: .milliseconds(30_000),
                url: URL(string: "https://example.com/ch1")),
            Chapter(
                start: .milliseconds(30_000), title: "Chapter 2",
                end: .milliseconds(60_000))
        ])

        let writer = ID3Writer()
        try writer.write(info, to: url)

        let reader = ID3Reader()
        let result = try reader.read(from: url)
        #expect(result.chapters.count == 2)
        #expect(result.chapters[0].title == "Chapter 1")
        #expect(result.chapters[1].title == "Chapter 2")
        #expect(result.chapters[0].url?.absoluteString == "https://example.com/ch1")
    }

    // MARK: - Helpers

    private func createTempFile(tagData: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        var fileData = tagData
        fileData.append(fakeAudio)
        try fileData.write(to: url)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
