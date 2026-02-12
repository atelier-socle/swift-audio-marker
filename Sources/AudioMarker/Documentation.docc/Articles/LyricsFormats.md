# Lyrics Formats

Parse and export synchronized lyrics in LRC, TTML, WebVTT, and SRT formats.

## Overview

AudioMarker supports four subtitle/lyrics interchange formats. Each can be parsed into ``SynchronizedLyrics`` and exported from it, enabling format conversion pipelines.

### LRC

``LRCParser`` handles the standard LRC format (`[mm:ss.xx] text`):

```swift
// Parse LRC
let lrc = """
    [00:00.00]Welcome to the show
    [00:05.50]This is the first verse
    [00:12.30]Building up to the chorus
    [01:00.00]Here comes the chorus
    [01:30.00]Back to the verse
    """

let lyrics = try LRCParser.parse(lrc, language: "eng")
// lyrics.lines.count == 5
// lyrics.lines[0].text == "Welcome to the show"

// Export to LRC
let output = LRCParser.export(lyrics)
// [00:00.00]Welcome to the show
// [00:05.50]This is the first verse
// ...
```

LRC metadata lines (`[ti:...]`, `[ar:...]`) are ignored during parsing.

### TTML

TTML (W3C Timed Text Markup Language) supports karaoke timing, multi-language, and speaker attribution.

**Parse TTML:**

```swift
let ttml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
      <body>
        <div>
          <p begin="00:00:00.000" end="00:00:05.000">Welcome</p>
          <p begin="00:00:05.000" end="00:00:12.000">First verse</p>
        </div>
      </body>
    </tt>
    """

let parser = TTMLParser()
let lyrics = try parser.parseLyrics(from: ttml)
// lyrics[0].language == "eng"
// lyrics[0].lines[0].text == "Welcome"
```

**Export TTML:**

```swift
let ttml = TTMLExporter.export(
    lyrics,
    audioDuration: .seconds(15),
    title: "My Song"
)
// Produces valid TTML XML with timing attributes
```

**Karaoke (word-level spans):**

```swift
let ttml = """
    <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
      <body><div>
        <p begin="00:00:00.000" end="00:00:05.000">
          <span begin="00:00:00.000" end="00:00:01.500">Never</span>
          <span begin="00:00:01.500" end="00:00:03.000">gonna</span>
          <span begin="00:00:03.000" end="00:00:05.000">give</span>
        </p>
      </div></body>
    </tt>
    """

let lyrics = try TTMLParser().parseLyrics(from: ttml)
let line = lyrics[0].lines[0]
// line.isKaraoke == true
// line.segments[0].text == "Never"
```

**Multi-language:**

```swift
// Multiple <div xml:lang="..."> elements
let lyrics = try TTMLParser().parseLyrics(from: multiLangTTML)
// lyrics[0].language == "eng"
// lyrics[1].language == "jpn"
```

### TTML Document

For full TTML fidelity (styles, regions, agents), use ``TTMLDocument``:

```swift
// Parse full document
let doc = try TTMLParser().parseDocument(from: ttml)
// doc.title, doc.styles, doc.agents, doc.divisions

// Convert to/from SynchronizedLyrics
let lyrics = doc.toSynchronizedLyrics()
let doc2 = TTMLDocument.from(lyricsArray, title: "My Song")

// Export preserving all structure
let xml = TTMLExporter.exportDocument(doc2)
```

### WebVTT

```swift
let lyrics = [
    SynchronizedLyrics(
        language: "eng",
        lines: [
            LyricLine(time: .zero, text: "First cue"),
            LyricLine(time: .seconds(5), text: "Second cue")
        ])
]

// Export
let vtt = WebVTTExporter.export(lyrics, audioDuration: .seconds(15))
// WEBVTT
//
// 00:00:00.000 --> 00:00:05.000
// First cue
// ...

// Parse
let parsed = try WebVTTExporter.parse(vtt, language: "eng")
// parsed.lines.count == 2
```

### SRT

```swift
let lyrics = [
    SynchronizedLyrics(
        language: "fra",
        lines: [
            LyricLine(time: .zero, text: "Bonjour"),
            LyricLine(time: .seconds(5), text: "Au revoir")
        ])
]

// Export (uses comma for milliseconds per SRT spec)
let srt = SRTExporter.export(lyrics, audioDuration: .seconds(10))

// Parse
let parsed = try SRTExporter.parse(srt, language: "fra")
// parsed.lines.count == 2
```

### Format Conversion Pipeline

Convert between any formats via ``SynchronizedLyrics``:

```swift
// LRC → SynchronizedLyrics → TTML
let lyrics = try LRCParser.parse(lrcString, language: "eng")
let ttml = TTMLExporter.export(
    lyrics,
    audioDuration: .seconds(30),
    title: "Converted Song"
)
```

## Next Steps

- <doc:SynchronizedLyricsGuide> — Karaoke, speakers, and smart storage
- <doc:ChapterFormats> — Chapter interchange formats
- <doc:CLIReference> — Lyrics export/import from the CLI
