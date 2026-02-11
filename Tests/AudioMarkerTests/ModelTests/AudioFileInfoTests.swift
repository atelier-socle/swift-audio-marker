import Testing

@testable import AudioMarker

@Suite("AudioFileInfo")
struct AudioFileInfoTests {

    // MARK: - Default init

    @Test("Default init has empty metadata and chapters")
    func defaultInit() {
        let info = AudioFileInfo()
        #expect(info.metadata.title == nil)
        #expect(info.chapters.isEmpty)
        #expect(info.duration == nil)
    }

    // MARK: - Populated init

    @Test("Init with populated data")
    func populatedInit() {
        let metadata = AudioMetadata(title: "Test", artist: "Artist")
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .seconds(60), title: "Main")
        ])
        let duration = AudioTimestamp.seconds(120)

        let info = AudioFileInfo(
            metadata: metadata,
            chapters: chapters,
            duration: duration
        )

        #expect(info.metadata.title == "Test")
        #expect(info.metadata.artist == "Artist")
        #expect(info.chapters.count == 2)
        #expect(info.duration == duration)
    }

    // MARK: - Mutability

    @Test("Fields are mutable")
    func mutability() {
        var info = AudioFileInfo()
        info.metadata.title = "Updated"
        info.duration = .seconds(300)

        #expect(info.metadata.title == "Updated")
        #expect(info.duration == .seconds(300))
    }
}
