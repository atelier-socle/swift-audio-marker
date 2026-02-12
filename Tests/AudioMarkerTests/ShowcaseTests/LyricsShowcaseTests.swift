import Foundation
import Testing

@testable import AudioMarker

/// Demonstrates LRC parsing, LRC export, TTML export, and format conversion pipelines.
@Suite("Showcase: Lyrics Formats")
struct LyricsShowcaseTests {

    // MARK: - LRC Parse

    @Test("Parse LRC file into synchronized lyrics")
    func parseLRC() throws {
        // Full LRC string with metadata lines (ignored) and timestamped lines
        let lrc = """
            [ti:My Song]
            [ar:The Artist]
            [al:The Album]

            [00:00.00]Welcome to the show
            [00:05.50]This is the first verse
            [00:12.30]Building up to the chorus
            [01:00.00]Here comes the chorus
            [01:30.00]Back to the verse
            """

        let lyrics = try LRCParser.parse(lrc, language: "eng")

        // Metadata lines are ignored — only timestamped lines parsed
        #expect(lyrics.lines.count == 5)
        #expect(lyrics.language == "eng")

        // Lines are sorted by time
        #expect(lyrics.lines[0].text == "Welcome to the show")
        #expect(lyrics.lines[0].time == .zero)
        #expect(lyrics.lines[1].text == "This is the first verse")
        #expect(lyrics.lines[1].time == .milliseconds(5500))
        #expect(lyrics.lines[4].time == .milliseconds(90_000))
    }

    // MARK: - LRC Export

    @Test("Export synchronized lyrics to LRC format")
    func exportLRC() throws {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .zero, text: "First line"),
                LyricLine(time: .seconds(5.5), text: "Second line"),
                LyricLine(time: .seconds(90), text: "Last line")
            ])

        let output = LRCParser.export(lyrics)

        // Format: [MM:SS.xx]text
        #expect(output.contains("[00:00.00]First line"))
        #expect(output.contains("[00:05.50]Second line"))
        #expect(output.contains("[01:30.00]Last line"))

        // Round-trip: parse the exported output
        let reparsed = try LRCParser.parse(output)
        #expect(reparsed.lines.count == 3)
        #expect(reparsed.lines[0].text == "First line")
        #expect(reparsed.lines[2].text == "Last line")
    }

    // MARK: - TTML Export

    @Test("Export synchronized lyrics to TTML format")
    func exportTTML() throws {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .zero, text: "Hello world"),
                LyricLine(time: .seconds(3), text: "Second verse"),
                LyricLine(time: .seconds(6), text: "Third verse"),
                LyricLine(time: .seconds(9), text: "Fourth verse"),
                LyricLine(time: .seconds(12), text: "Final words")
            ])

        let ttml = TTMLExporter.export(
            lyrics,
            audioDuration: .seconds(15),
            title: "My Song"
        )

        // XML declaration and root element
        #expect(ttml.contains("<?xml version=\"1.0\""))
        #expect(ttml.contains("xml:lang=\"eng\""))
        #expect(ttml.contains("xmlns=\"http://www.w3.org/ns/ttml\""))

        // Title in head
        #expect(ttml.contains("<ttm:title>My Song</ttm:title>"))

        // Each <p> has begin and end
        #expect(ttml.contains("begin=\"00:00:00.000\""))
        #expect(ttml.contains("end=\"00:00:03.000\""))
        #expect(ttml.contains(">Hello world</p>"))

        // Last line's end time = audioDuration
        #expect(ttml.contains("end=\"00:00:15.000\""))
        #expect(ttml.contains(">Final words</p>"))
    }

    @Test("TTML without title omits head element")
    func ttmlNoTitle() {
        let lyrics = SynchronizedLyrics(
            language: "fra",
            lines: [LyricLine(time: .zero, text: "Bonjour")])

        let ttml = TTMLExporter.export(lyrics)

        #expect(ttml.contains("xml:lang=\"fra\""))
        #expect(!ttml.contains("<head>"))
        #expect(!ttml.contains("<ttm:title>"))
    }

    @Test("TTML escapes XML special characters")
    func ttmlEscaping() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [LyricLine(time: .zero, text: "Tom & Jerry <3")])

        let ttml = TTMLExporter.export(lyrics)
        #expect(ttml.contains("Tom &amp; Jerry &lt;3"))
    }

    // MARK: - Pipeline

    @Test("LRC to TTML pipeline — format conversion")
    func lrcToTTML() throws {
        // Start with LRC input
        let lrc = """
            [00:00.00]Welcome
            [00:10.00]Middle section
            [00:20.00]Goodbye
            """

        // Parse LRC → SynchronizedLyrics
        let lyrics = try LRCParser.parse(lrc, language: "eng")
        #expect(lyrics.lines.count == 3)

        // Convert to TTML
        let ttml = TTMLExporter.export(
            lyrics,
            audioDuration: .seconds(30),
            title: "Converted Song"
        )

        // Verify the full pipeline
        #expect(ttml.contains("xml:lang=\"eng\""))
        #expect(ttml.contains("<ttm:title>Converted Song</ttm:title>"))
        #expect(ttml.contains(">Welcome</p>"))
        #expect(ttml.contains(">Middle section</p>"))
        #expect(ttml.contains(">Goodbye</p>"))
        #expect(ttml.contains("end=\"00:00:30.000\""))
    }

    // MARK: - TTML Import

    @Test("Parse TTML into synchronized lyrics")
    func parseTTML() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
              <head>
                <metadata>
                  <ttm:title>My Song</ttm:title>
                </metadata>
              </head>
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:05.000">Welcome to the show</p>
                  <p begin="00:00:05.000" end="00:00:12.000">This is the first verse</p>
                  <p begin="00:00:12.000" end="00:00:20.000">Here comes the chorus</p>
                </div>
              </body>
            </tt>
            """

        let parser = TTMLParser()
        let lyrics = try parser.parseLyrics(from: ttml)

        #expect(lyrics.count == 1)
        #expect(lyrics[0].language == "eng")
        #expect(lyrics[0].lines.count == 3)
        #expect(lyrics[0].lines[0].text == "Welcome to the show")
        #expect(lyrics[0].lines[0].time == .zero)
        #expect(lyrics[0].lines[1].text == "This is the first verse")
        #expect(lyrics[0].lines[2].text == "Here comes the chorus")
    }

    @Test("TTML karaoke import preserves word-level timing")
    func ttmlKaraokeImport() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:05.000">
                    <span begin="00:00:00.000" end="00:00:01.500">Never</span>
                    <span begin="00:00:01.500" end="00:00:03.000">gonna</span>
                    <span begin="00:00:03.000" end="00:00:05.000">give</span>
                  </p>
                </div>
              </body>
            </tt>
            """

        let parser = TTMLParser()
        let lyrics = try parser.parseLyrics(from: ttml)

        let line = lyrics[0].lines[0]
        #expect(line.isKaraoke)
        #expect(line.segments.count == 3)
        #expect(line.segments[0].text == "Never")
        #expect(line.segments[0].startTime == .zero)
        #expect(line.segments[0].endTime == .milliseconds(1500))
        #expect(line.segments[1].text == "gonna")
        #expect(line.segments[2].text == "give")
    }

    @Test("TTML multi-language import")
    func ttmlMultiLanguage() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div xml:lang="en">
                  <p begin="00:00:00.000" end="00:00:05.000">Hello world</p>
                </div>
                <div xml:lang="ja">
                  <p begin="00:00:00.000" end="00:00:05.000">こんにちは世界</p>
                </div>
              </body>
            </tt>
            """

        let parser = TTMLParser()
        let lyrics = try parser.parseLyrics(from: ttml)

        #expect(lyrics.count == 2)
        #expect(lyrics[0].language == "eng")
        #expect(lyrics[0].lines[0].text == "Hello world")
        #expect(lyrics[1].language == "jpn")
        #expect(lyrics[1].lines[0].text == "こんにちは世界")
    }

    // MARK: - TTML Round-Trip

    @Test("TTML round-trip: parse → export → parse")
    func ttmlRoundTrip() throws {
        let original = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:03.000">First line</p>
                  <p begin="00:00:03.000" end="00:00:06.000">Second line</p>
                  <p begin="00:00:06.000" end="00:00:10.000">Third line</p>
                </div>
              </body>
            </tt>
            """

        let parser = TTMLParser()

        // Parse → SynchronizedLyrics
        let lyrics = try parser.parseLyrics(from: original)
        #expect(lyrics[0].lines.count == 3)

        // Export → TTML
        let exported = TTMLExporter.export(
            lyrics[0], audioDuration: .seconds(10))

        // Re-parse → SynchronizedLyrics
        let reparsed = try parser.parseLyrics(from: exported)
        #expect(reparsed[0].lines.count == 3)
        #expect(reparsed[0].lines[0].text == "First line")
        #expect(reparsed[0].lines[1].text == "Second line")
        #expect(reparsed[0].lines[2].text == "Third line")
    }

}
