import Testing

@testable import AudioMarker

@Suite("SynchronizedLyrics")
struct SynchronizedLyricsTests {

    // MARK: - Basic creation

    @Test("Creates with defaults")
    func defaultCreation() {
        let lyrics = SynchronizedLyrics(language: "eng")
        #expect(lyrics.language == "eng")
        #expect(lyrics.contentType == .lyrics)
        #expect(lyrics.descriptor == "")
        #expect(lyrics.lines.isEmpty)
    }

    @Test("Creates with all fields")
    func fullCreation() {
        let lines = [
            LyricLine(time: .seconds(0), text: "First line"),
            LyricLine(time: .seconds(5), text: "Second line")
        ]
        let lyrics = SynchronizedLyrics(
            language: "fra",
            contentType: .textTranscription,
            descriptor: "Subtitle",
            lines: lines
        )
        #expect(lyrics.language == "fra")
        #expect(lyrics.contentType == .textTranscription)
        #expect(lyrics.descriptor == "Subtitle")
        #expect(lyrics.lines.count == 2)
    }

    // MARK: - Sorting

    @Test("sorted returns lines ordered by time")
    func sortedLines() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .seconds(10), text: "Third"),
                LyricLine(time: .seconds(0), text: "First"),
                LyricLine(time: .seconds(5), text: "Second")
            ]
        )
        let sorted = lyrics.sorted()
        #expect(sorted.lines[0].text == "First")
        #expect(sorted.lines[1].text == "Second")
        #expect(sorted.lines[2].text == "Third")
    }

    @Test("sorted does not mutate original")
    func sortedDoesNotMutate() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .seconds(10), text: "B"),
                LyricLine(time: .seconds(0), text: "A")
            ]
        )
        _ = lyrics.sorted()
        #expect(lyrics.lines[0].text == "B")
    }

    // MARK: - ContentType values

    @Test(
        "ContentType raw values match ID3v2 SYLT spec",
        arguments: [
            (ContentType.other, UInt8(0)),
            (ContentType.lyrics, UInt8(1)),
            (ContentType.textTranscription, UInt8(2)),
            (ContentType.movementOrPartName, UInt8(3)),
            (ContentType.events, UInt8(4)),
            (ContentType.chord, UInt8(5)),
            (ContentType.trivia, UInt8(6)),
            (ContentType.webpageURLs, UInt8(7)),
            (ContentType.imageURLs, UInt8(8))
        ] as [(ContentType, UInt8)]
    )
    func contentTypeRawValues(type: ContentType, expected: UInt8) {
        #expect(type.rawValue == expected)
    }

    @Test("ContentType has all 9 cases")
    func contentTypeCaseCount() {
        #expect(ContentType.allCases.count == 9)
    }

    // MARK: - LyricLine

    @Test("LyricLine stores time and text")
    func lyricLineBasic() {
        let line = LyricLine(time: .milliseconds(2500), text: "Hello world")
        #expect(line.time == .milliseconds(2500))
        #expect(line.text == "Hello world")
    }

    @Test("LyricLine without segments has empty segments")
    func lyricLineEmptySegments() {
        let line = LyricLine(time: .zero, text: "No karaoke")
        #expect(line.segments.isEmpty)
        #expect(!line.isKaraoke)
    }

    @Test("LyricLine with segments is karaoke")
    func lyricLineWithSegments() {
        let segments = [
            LyricSegment(startTime: .zero, endTime: .seconds(1), text: "Hello"),
            LyricSegment(startTime: .seconds(1), endTime: .seconds(2), text: "world")
        ]
        let line = LyricLine(time: .zero, text: "Hello world", segments: segments)
        #expect(line.isKaraoke)
        #expect(line.segments.count == 2)
        #expect(line.segments[0].text == "Hello")
        #expect(line.segments[1].text == "world")
    }

    @Test("LyricLine with segments is Hashable")
    func lyricLineKaraokeHashable() {
        let segments = [
            LyricSegment(startTime: .zero, endTime: .seconds(1), text: "A")
        ]
        let line1 = LyricLine(time: .zero, text: "A", segments: segments)
        let line2 = LyricLine(time: .zero, text: "A", segments: segments)
        #expect(line1 == line2)
        #expect(line1.hashValue == line2.hashValue)
    }
}
