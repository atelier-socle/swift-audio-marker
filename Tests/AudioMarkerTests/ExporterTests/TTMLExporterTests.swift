import Testing

@testable import AudioMarker

@Suite("TTML Exporter")
struct TTMLExporterTests {

    let sampleLyrics = SynchronizedLyrics(
        language: "eng",
        lines: [
            LyricLine(time: .zero, text: "First line"),
            LyricLine(time: .seconds(5), text: "Second line"),
            LyricLine(time: .seconds(10), text: "Third line")
        ]
    )

    // MARK: - Basic Export

    @Test("Exports valid TTML XML")
    func exportBasic() {
        let result = TTMLExporter.export(sampleLyrics)
        #expect(result.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(result.contains("<tt xml:lang=\"eng\""))
        #expect(result.contains("xmlns=\"http://www.w3.org/ns/ttml\""))
        #expect(result.contains("<p begin="))
        #expect(result.contains("First line"))
        #expect(result.contains("</tt>"))
    }

    @Test("Uses language from lyrics")
    func usesLanguage() {
        let lyrics = SynchronizedLyrics(
            language: "fra",
            lines: [LyricLine(time: .zero, text: "Bonjour")]
        )
        let result = TTMLExporter.export(lyrics)
        #expect(result.contains("xml:lang=\"fra\""))
    }

    // MARK: - Title

    @Test("Includes title in head when provided")
    func includesTitle() {
        let result = TTMLExporter.export(sampleLyrics, title: "My Song")
        #expect(result.contains("<head>"))
        #expect(result.contains("<ttm:title>My Song</ttm:title>"))
        #expect(result.contains("</head>"))
    }

    @Test("Omits head when no title")
    func omitsHead() {
        let result = TTMLExporter.export(sampleLyrics)
        #expect(!result.contains("<head>"))
    }

    // MARK: - End Times

    @Test("End time is next line's begin time")
    func endTimeFromNextLine() {
        let result = TTMLExporter.export(sampleLyrics)
        // First line: begin=00:00:00.000 end=00:00:05.000
        #expect(result.contains("begin=\"00:00:00.000\" end=\"00:00:05.000\""))
    }

    @Test("Last line end time uses audio duration when provided")
    func lastLineUsesAudioDuration() {
        let result = TTMLExporter.export(sampleLyrics, audioDuration: .seconds(15))
        #expect(result.contains("begin=\"00:00:10.000\" end=\"00:00:15.000\""))
    }

    @Test("Last line defaults to begin+5s without audio duration")
    func lastLineDefaultsToFiveSeconds() {
        let result = TTMLExporter.export(sampleLyrics)
        // Third line at 10s, default end = 15s
        #expect(result.contains("begin=\"00:00:10.000\" end=\"00:00:15.000\""))
    }

    // MARK: - XML Escaping

    @Test("Escapes special XML characters in text")
    func escapesSpecialCharacters() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [LyricLine(time: .zero, text: "Rock & Roll <loud> \"yeah\" it's great")]
        )
        let result = TTMLExporter.export(lyrics)
        #expect(result.contains("Rock &amp; Roll &lt;loud&gt; &quot;yeah&quot; it's great"))
    }

    @Test("Escapes special characters in title")
    func escapesTitle() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [LyricLine(time: .zero, text: "Hello")]
        )
        let result = TTMLExporter.export(lyrics, title: "Songs & More")
        #expect(result.contains("<ttm:title>Songs &amp; More</ttm:title>"))
    }

    // MARK: - Edge Cases

    @Test("Empty lyrics produces minimal TTML")
    func emptyLyrics() {
        let lyrics = SynchronizedLyrics(language: "eng", lines: [])
        let result = TTMLExporter.export(lyrics)
        #expect(result.contains("<div>"))
        #expect(result.contains("</div>"))
        #expect(!result.contains("<p "))
    }

    @Test("Single line with duration")
    func singleLineWithDuration() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [LyricLine(time: .seconds(2), text: "Only line")]
        )
        let result = TTMLExporter.export(lyrics, audioDuration: .seconds(30))
        #expect(result.contains("begin=\"00:00:02.000\" end=\"00:00:30.000\""))
    }

    @Test("Single line without duration defaults to begin+5s")
    func singleLineWithoutDuration() {
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [LyricLine(time: .seconds(2), text: "Only line")]
        )
        let result = TTMLExporter.export(lyrics)
        #expect(result.contains("begin=\"00:00:02.000\" end=\"00:00:07.000\""))
    }

    // MARK: - Karaoke Spans

    @Test("Exports karaoke line with span elements")
    func exportKaraokeSpans() {
        let segments = [
            LyricSegment(
                startTime: .zero, endTime: .seconds(2), text: "Hello"),
            LyricSegment(
                startTime: .seconds(2), endTime: .seconds(5), text: "world")
        ]
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(
                    time: .zero, text: "Hello world", segments: segments)
            ])
        let result = TTMLExporter.export(lyrics, audioDuration: .seconds(10))
        #expect(result.contains("<span begin=\"00:00:00.000\" end=\"00:00:02.000\">Hello</span>"))
        #expect(result.contains("<span begin=\"00:00:02.000\" end=\"00:00:05.000\">world</span>"))
    }

    @Test("Does not escape apostrophes in text content")
    func apostropheNotEscaped() {
        let lyrics = SynchronizedLyrics(
            language: "fra",
            lines: [LyricLine(time: .zero, text: "L'amour n'a pas d'âge")]
        )
        let result = TTMLExporter.export(lyrics)
        #expect(result.contains("L'amour n'a pas d'âge"))
        #expect(!result.contains("&apos;"))
    }

    @Test("Exports karaoke span with style")
    func exportKaraokeSpanWithStyle() {
        let segments = [
            LyricSegment(
                startTime: .zero, endTime: .seconds(1), text: "Word",
                styleID: "highlight")
        ]
        let lyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(
                    time: .zero, text: "Word", segments: segments)
            ])
        let result = TTMLExporter.export(lyrics, audioDuration: .seconds(5))
        #expect(result.contains("style=\"highlight\""))
    }

}
