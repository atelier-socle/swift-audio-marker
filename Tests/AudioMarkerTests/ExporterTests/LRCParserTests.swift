import Testing

@testable import AudioMarker

@Suite("LRC Parser")
struct LRCParserTests {

    // MARK: - Parse

    @Test("Parses basic LRC lines")
    func parseBasic() throws {
        let lrc = """
            [00:00.00]First line
            [00:05.50]Second line
            [01:30.00]Third line
            """
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines.count == 3)
        #expect(lyrics.lines[0].text == "First line")
        #expect(lyrics.lines[0].time == .zero)
        #expect(lyrics.lines[1].text == "Second line")
        #expect(lyrics.lines[1].time == .milliseconds(5500))
        #expect(lyrics.lines[2].text == "Third line")
        #expect(lyrics.lines[2].time == .seconds(90))
    }

    @Test("Parses 2-digit centiseconds")
    func parseCentiseconds() throws {
        let lrc = "[00:01.50]Half second offset"
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines[0].time == .milliseconds(1500))
    }

    @Test("Parses 3-digit milliseconds")
    func parseMilliseconds() throws {
        let lrc = "[00:01.500]Half second offset"
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines[0].time == .milliseconds(1500))
    }

    @Test("Skips metadata lines")
    func skipsMetadata() throws {
        let lrc = """
            [ti:My Song]
            [ar:My Artist]
            [al:My Album]
            [00:00.00]Actual lyric
            """
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines.count == 1)
        #expect(lyrics.lines[0].text == "Actual lyric")
    }

    @Test("Skips blank lines")
    func skipsBlankLines() throws {
        let lrc = """
            [00:00.00]First

            [00:05.00]Second
            """
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines.count == 2)
    }

    @Test("No valid lines throws invalidData")
    func noValidLinesThrows() {
        let lrc = """
            [ti:Title]
            [ar:Artist]
            just some text
            """
        #expect(throws: ExportError.self) {
            try LRCParser.parse(lrc)
        }
    }

    @Test("Sorts lines by timestamp")
    func sortsLines() throws {
        let lrc = """
            [01:00.00]Second
            [00:00.00]First
            [02:00.00]Third
            """
        let lyrics = try LRCParser.parse(lrc)
        #expect(lyrics.lines[0].text == "First")
        #expect(lyrics.lines[1].text == "Second")
        #expect(lyrics.lines[2].text == "Third")
    }

    @Test("Uses provided language")
    func usesLanguage() throws {
        let lyrics = try LRCParser.parse("[00:00.00]Hello", language: "eng")
        #expect(lyrics.language == "eng")
    }

    @Test("Default language is und")
    func defaultLanguage() throws {
        let lyrics = try LRCParser.parse("[00:00.00]Hello")
        #expect(lyrics.language == "und")
    }

    @Test("Minutes exceeding 59")
    func highMinutes() throws {
        let lrc = "[99:59.99]Near end"
        let lyrics = try LRCParser.parse(lrc)
        let expectedMs = 99 * 60_000 + 59 * 1000 + 990
        #expect(lyrics.lines[0].time == .milliseconds(expectedMs))
    }

    // MARK: - Export

    @Test("Exports synchronized lyrics to LRC format")
    func exportBasic() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .zero, text: "First line"),
                LyricLine(time: .milliseconds(5500), text: "Second line"),
                LyricLine(time: .seconds(90), text: "Third line")
            ]
        )
        let result = LRCParser.export(lyrics)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "[00:00.00]First line")
        #expect(lines[1] == "[00:05.50]Second line")
        #expect(lines[2] == "[01:30.00]Third line")
    }

    // MARK: - Round-Trip

    @Test("Round-trip parse then export preserves content")
    func roundTrip() throws {
        let original = """
            [00:00.00]First line
            [00:05.50]Second line
            [01:30.00]Third line
            """
        let lyrics = try LRCParser.parse(original)
        let exported = LRCParser.export(lyrics)
        let reimported = try LRCParser.parse(exported)

        #expect(reimported.lines.count == lyrics.lines.count)
        for (orig, reimp) in zip(lyrics.lines, reimported.lines) {
            #expect(orig.text == reimp.text)
            #expect(orig.time == reimp.time)
        }
    }
}
