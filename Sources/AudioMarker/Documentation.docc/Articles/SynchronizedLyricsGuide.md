# Synchronized Lyrics

Embed timestamped lyrics with karaoke timing, multi-language support, and speaker attribution.

## Overview

``SynchronizedLyrics`` represents a set of timestamped lyric lines for a single language. Each ``LyricLine`` carries a timestamp, text, optional speaker, and optional word-level ``LyricSegment`` entries for karaoke display.

### Creating Lyrics

```swift
let lyrics = SynchronizedLyrics(
    language: "eng",
    contentType: .lyrics,
    lines: [
        LyricLine(time: .zero, text: "Hello world"),
        LyricLine(time: .seconds(5), text: "Second line"),
        LyricLine(time: .seconds(10), text: "Final line")
    ]
)
```

### Karaoke Segments

For word-level highlighting, add ``LyricSegment`` entries to each line:

```swift
let karaokeLine = LyricLine(
    time: .zero,
    text: "Never gonna give",
    segments: [
        LyricSegment(
            startTime: .zero, endTime: .milliseconds(1500),
            text: "Never"),
        LyricSegment(
            startTime: .milliseconds(1500),
            endTime: .milliseconds(3000), text: "gonna"),
        LyricSegment(
            startTime: .milliseconds(3000),
            endTime: .milliseconds(5000), text: "give")
    ])

karaokeLine.isKaraoke    // true
karaokeLine.segments.count // 3
```

### Speaker Attribution

Assign speakers to lyric lines for dialogue or podcast transcripts:

```swift
let dialogueLines = [
    LyricLine(time: .zero, text: "Welcome!", speaker: "Host"),
    LyricLine(
        time: .seconds(3), text: "Thanks for having me.",
        speaker: "Guest"),
    LyricLine(
        time: .seconds(6), text: "Let's begin.", speaker: "Host")
]
```

Speakers are preserved through TTML storage and round-trip correctly through M4A files.

### Multi-Language Lyrics

Provide lyrics in multiple languages:

```swift
var info = AudioFileInfo()
info.metadata.synchronizedLyrics = [
    SynchronizedLyrics(
        language: "eng",
        lines: [LyricLine(time: .zero, text: "Hello")]),
    SynchronizedLyrics(
        language: "fra",
        lines: [LyricLine(time: .zero, text: "Bonjour")])
]
```

### Smart Storage

When writing to M4A files, AudioMarker automatically chooses the optimal storage format:

- **LRC** for mono-language lyrics without karaoke or speakers (compact, widely compatible)
- **TTML** for multi-language, karaoke, or speaker-attributed lyrics (full fidelity)

This is transparent — you always work with ``SynchronizedLyrics`` and ``LyricLine``, and the engine handles serialization.

### Writing Lyrics to Files

```swift
let engine = AudioMarkerEngine()

var info = AudioFileInfo()
info.metadata.synchronizedLyrics = [lyrics]
try engine.write(info, to: fileURL)

// Read back
let readBack = try engine.read(from: fileURL)
let lines = readBack.metadata.synchronizedLyrics[0].lines
```

### Content Types

``ContentType`` specifies what the synchronized text represents:

| Case | Description |
|------|-------------|
| `.lyrics` | Song lyrics (default) |
| `.textTranscription` | Spoken word transcription |
| `.movementOrPartName` | Musical movement or part names |
| `.events` | Event descriptions |
| `.chord` | Chord symbols |
| `.trivia` | Fun facts or liner notes |

## Next Steps

- <doc:LyricsFormats> — Parse and export LRC, TTML, WebVTT, and SRT
- <doc:ReadingAndWriting> — Full metadata workflows
- <doc:CLIReference> — Lyrics commands from the CLI
