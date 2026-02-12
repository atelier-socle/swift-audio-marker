import Testing

@testable import AudioMarker

@Suite("SRT Exporter")
struct SRTExporterTests {

    // MARK: - Parse

    @Test("Parses basic SRT cues")
    func parseBasic() throws {
        let srt = """
            1
            00:00:05,000 --> 00:00:08,500
            Welcome to the show

            2
            00:00:10,000 --> 00:00:14,000
            Feel the music
            """
        let lyrics = try SRTExporter.parse(srt)
        #expect(lyrics.lines.count == 2)
        #expect(lyrics.lines[0].text == "Welcome to the show")
        #expect(lyrics.lines[0].time == .milliseconds(5000))
        #expect(lyrics.lines[1].text == "Feel the music")
        #expect(lyrics.lines[1].time == .milliseconds(10_000))
    }

    @Test("Parses timestamps with hours")
    func parsesHours() throws {
        let srt = """
            1
            01:30:00,000 --> 01:30:05,000
            Long content
            """
        let lyrics = try SRTExporter.parse(srt)
        #expect(lyrics.lines[0].time == .milliseconds(5_400_000))
    }

    @Test("Strips HTML tags from text")
    func stripsHTMLTags() throws {
        let srt = """
            1
            00:00:00,000 --> 00:00:05,000
            <b>Bold</b> and <i>italic</i>
            """
        let lyrics = try SRTExporter.parse(srt)
        #expect(lyrics.lines[0].text == "Bold and italic")
    }

    @Test("Joins multi-line cue text with space")
    func joinsMultilineText() throws {
        let srt = """
            1
            00:00:00,000 --> 00:00:05,000
            First line
            Second line
            """
        let lyrics = try SRTExporter.parse(srt)
        #expect(lyrics.lines[0].text == "First line Second line")
    }

    @Test("Skips blank lines between cues")
    func skipsBlankLines() throws {
        let srt = """
            1
            00:00:00,000 --> 00:00:05,000
            First

            2
            00:00:05,000 --> 00:00:10,000
            Second
            """
        let lyrics = try SRTExporter.parse(srt)
        #expect(lyrics.lines.count == 2)
    }

    @Test("No valid cues throws invalidData")
    func noCuesThrows() {
        #expect(throws: ExportError.self) {
            try SRTExporter.parse("just some text\nwithout timestamps\n")
        }
    }

    @Test("Uses provided language")
    func usesLanguage() throws {
        let srt = "1\n00:00:00,000 --> 00:00:05,000\nHello\n"
        let lyrics = try SRTExporter.parse(srt, language: "eng")
        #expect(lyrics.language == "eng")
    }

    @Test("Default language is und")
    func defaultLanguage() throws {
        let srt = "1\n00:00:00,000 --> 00:00:05,000\nHello\n"
        let lyrics = try SRTExporter.parse(srt)
        #expect(lyrics.language == "und")
    }

    // MARK: - Export

    @Test("Exports basic lyrics to SRT")
    func exportBasic() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .milliseconds(5000), text: "Welcome"),
                LyricLine(time: .milliseconds(10_000), text: "Hello")
            ]
        )
        let result = SRTExporter.export([lyrics])
        #expect(result.contains("1\n"))
        #expect(result.contains("00:00:05,000 --> 00:00:10,000"))
        #expect(result.contains("Welcome"))
        #expect(result.contains("2\n"))
        #expect(result.contains("Hello"))
    }

    @Test("Export uses commas for milliseconds")
    func exportUsesCommas() {
        let lyrics = SynchronizedLyrics(
            language: "und",
            lines: [LyricLine(time: .milliseconds(1500), text: "Test")]
        )
        let result = SRTExporter.export([lyrics])
        #expect(result.contains("00:00:01,500"))
    }

    @Test("Export uses audioDuration for last cue end time")
    func exportUsesAudioDuration() {
        let lyrics = SynchronizedLyrics(
            language: "und",
            lines: [LyricLine(time: .milliseconds(5000), text: "Only line")]
        )
        let result = SRTExporter.export([lyrics], audioDuration: .seconds(120))
        #expect(result.contains("00:00:05,000 --> 00:02:00,000"))
    }

    @Test("Export defaults to 5-second duration for last cue without audioDuration")
    func exportDefaultsDuration() {
        let lyrics = SynchronizedLyrics(
            language: "und",
            lines: [LyricLine(time: .milliseconds(10_000), text: "Last line")]
        )
        let result = SRTExporter.export([lyrics])
        #expect(result.contains("00:00:10,000 --> 00:00:15,000"))
    }

    @Test("Export with empty lyrics produces empty string")
    func exportEmpty() {
        let lyrics = SynchronizedLyrics(language: "und", lines: [])
        let result = SRTExporter.export([lyrics])
        #expect(result == "")
    }

    @Test("Export merges and sorts multiple lyrics")
    func exportMergesMultiple() {
        let lyrics1 = SynchronizedLyrics(
            language: "eng",
            lines: [LyricLine(time: .milliseconds(10_000), text: "Second")]
        )
        let lyrics2 = SynchronizedLyrics(
            language: "eng",
            lines: [LyricLine(time: .milliseconds(5000), text: "First")]
        )
        let result = SRTExporter.export([lyrics1, lyrics2])
        guard let firstRange = result.range(of: "First"),
            let secondRange = result.range(of: "Second")
        else {
            Issue.record("Expected both 'First' and 'Second' in output")
            return
        }
        #expect(firstRange.lowerBound < secondRange.lowerBound)
    }

    // MARK: - Round-Trip

    @Test("Round-trip preserves content")
    func roundTrip() throws {
        let original = SynchronizedLyrics(
            language: "und",
            lines: [
                LyricLine(time: .zero, text: "First line"),
                LyricLine(time: .milliseconds(5000), text: "Second line"),
                LyricLine(time: .milliseconds(90_000), text: "Third line")
            ]
        )
        let exported = SRTExporter.export([original])
        let reimported = try SRTExporter.parse(exported)

        #expect(reimported.lines.count == original.lines.count)
        for (orig, reimp) in zip(original.lines, reimported.lines) {
            #expect(orig.text == reimp.text)
            #expect(orig.time == reimp.time)
        }
    }
}
