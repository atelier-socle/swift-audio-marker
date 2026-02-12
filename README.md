# swift-audio-marker

A Swift library for reading, writing, and converting audio metadata and chapter markers in MP3 and M4A/M4B files.

[![CI](https://github.com/atelier-socle/swift-audio-marker/actions/workflows/ci.yml/badge.svg)](https://github.com/atelier-socle/swift-audio-marker/actions/workflows/ci.yml)
[![codecov](https://codecov.io/github/atelier-socle/swift-audio-marker/graph/badge.svg?token=WUBE7V9X2U)](https://codecov.io/github/atelier-socle/swift-audio-marker)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20visionOS-blue.svg)]()

![swift-audio-marker](./assets/banner.png)

## Overview

swift-audio-marker is a production-grade Swift library for enriching audio files with metadata, chapters, artwork, and synchronized lyrics. The core library is pure Swift with zero external dependencies — all ID3v2 (MP3) and ISOBMFF/iTunes (M4A/M4B) parsing and writing is done at the byte level, with streaming I/O that never loads audio data into memory. It supports 30 metadata fields, dual-format chapter writing (Nero + QuickTime), synchronized lyrics with karaoke word-level timing and speaker identification, 9 exchange formats (Podlove JSON/XML, MP4Chaps, FFMetadata, Podcast Namespace, Cue Sheet, Markdown, WebVTT, SRT), a validation engine with 10 built-in rules, batch processing with bounded concurrency, and a CLI tool with 17 commands.

Part of the [Atelier Socle](https://www.atelier-socle.com) ecosystem.

## Features

- **Pure Swift I/O** — byte-level reading and writing of ID3v2 tags and MP4 atoms with no AVFoundation dependency for metadata operations; audio data is streamed through and never loaded in memory
- **ID3v2.3 and v2.4** — full read/write support for 29 frame types including CHAP, CTOC, APIC, SYLT, USLT, TXXX, WXXX, PRIV, UFID, and all standard text/URL frames
- **MP4/M4A/M4B metadata** — read and write 17 iTunes metadata atoms plus Nero chapter lists and QuickTime chapter text tracks
- **Enhanced Podcasts** — chapter URLs and per-chapter artwork for rich podcast experiences
- **Synchronized lyrics** — LRC, TTML, WebVTT, and SRT import/export with full round-trip fidelity
- **Karaoke and speakers** — word-level timing via `LyricSegment` and speaker identification via TTML agents, with smart M4A storage that routes to TTML when needed
- **9 exchange formats** — Podlove JSON, Podlove XML, MP4Chaps, FFMetadata, Podcast Namespace, Cue Sheet, Markdown (export-only), WebVTT, SRT
- **Validation engine** — 10 built-in rules covering chapter ordering, overlap, bounds, titles, metadata completeness, language codes, artwork formats, and ratings; extensible via the `ValidationRule` protocol
- **Batch processing** — `BatchProcessor` with bounded `TaskGroup` concurrency for parallel read, write, strip, and chapter export operations
- **CLI tool** — `audio-marker` command-line interface with 17 commands for metadata, chapters, lyrics, artwork, validation, and batch operations
- **Strict concurrency** — all public types are `Sendable`, Swift 6.2 strict concurrency throughout

## Installation

### Requirements

- **Swift 6.2+** with strict concurrency
- **Platforms**: macOS 14+ · iOS 17+ · visionOS 1+ · Mac Catalyst 17+

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/atelier-socle/swift-audio-marker.git", from: "0.1.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["AudioMarker"]
)
```

## Quick Start

Read an audio file and access its metadata and chapters:

```swift
import AudioMarker

let engine = AudioMarkerEngine()
let info = try engine.read(from: URL(fileURLWithPath: "podcast.mp3"))

print(info.metadata.title ?? "Unknown")
print(info.metadata.artist ?? "Unknown")

for chapter in info.chapters {
    print("\(chapter.start) — \(chapter.title)")
}
```

## Key Concepts

### Reading Audio Files

`AudioMarkerEngine` is the unified entry point. It auto-detects the format from magic bytes and file extension, then dispatches to the appropriate reader:

```swift
let engine = AudioMarkerEngine()

// Full read: metadata + chapters + duration
let info = try engine.read(from: url)

// Chapters only
let chapters = try engine.readChapters(from: url)

// Format detection
let format = try engine.detectFormat(of: url)
// format == .mp3, .m4a, or .m4b
```

Format detection also works standalone:

```swift
// From file extension
AudioFormat.detect(fromExtension: "mp3")  // .mp3
AudioFormat.detect(fromExtension: "m4a")  // .m4a
AudioFormat.detect(fromExtension: "m4b")  // .m4b

// Format properties
AudioFormat.mp3.usesID3   // true
AudioFormat.m4a.usesMP4   // true
```

For low-level inspection, use the format-specific readers:

```swift
// Raw ID3v2 frames
let reader = ID3Reader()
let (header, frames) = try reader.readRawFrames(from: url)

// Raw MP4 atom tree
let mp4Reader = MP4Reader()
let atoms = try mp4Reader.readAtoms(from: url)
```

### Writing Metadata

Write a complete `AudioFileInfo` to a file, or modify specific fields while preserving the rest:

```swift
let engine = AudioMarkerEngine()

// Full write — replaces all metadata
var info = AudioFileInfo()
info.metadata.title = "Updated Song"
info.metadata.artist = "New Artist"
info.metadata.album = "New Album"
info.metadata.year = 2025
info.metadata.genre = "Indie"
try engine.write(info, to: url)

// Modify — preserves unknown frames (MP3)
try engine.modify(info, in: url)
```

AudioMetadata supports 30 fields across 7 categories:

| Category | Fields |
|----------|--------|
| Core | `title`, `artist`, `album`, `genre`, `year`, `trackNumber`, `discNumber` |
| Professional | `composer`, `albumArtist`, `publisher`, `copyright`, `encoder`, `comment`, `bpm`, `key`, `language`, `isrc` |
| Artwork | `artwork` (JPEG or PNG with auto-detection from magic bytes) |
| Lyrics | `unsynchronizedLyrics`, `synchronizedLyrics` |
| URLs | `artistURL`, `audioSourceURL`, `audioFileURL`, `publisherURL`, `commercialURL`, `customURLs` |
| Custom data | `customTextFields`, `privateData`, `uniqueFileIdentifiers` |
| Statistics | `playCount`, `rating` |

### Chapters

Create and write chapters with optional URLs and per-chapter artwork:

```swift
// Build a chapter timeline
var chapters = ChapterList([
    Chapter(start: .zero, title: "Intro"),
    Chapter(start: .seconds(30), title: "Hook"),
    Chapter(
        start: .seconds(90), title: "Verse 1",
        url: URL(string: "https://example.com/verse1")),
    Chapter(start: .seconds(180), title: "Chorus"),
    Chapter(
        start: .seconds(270), title: "Outro",
        artwork: Artwork(data: jpegData, format: .jpeg))
])

// Append and sort
chapters.append(Chapter(start: .seconds(350), title: "Bonus"))
chapters.sort()

// Fill in end times based on audio duration
let withEnds = chapters.withCalculatedEndTimes(
    audioDuration: .seconds(400))

// Write chapters to file
let engine = AudioMarkerEngine()
try engine.writeChapters(chapters, to: url)
```

MP4 files get chapters written in both Nero (`chpl`) and QuickTime text track formats for maximum player compatibility.

### Chapter Import/Export

Import and export chapters across 7 formats:

| Format | Extension | Export | Import |
|--------|-----------|--------|--------|
| Podlove JSON | `.json` | Yes | Yes |
| Podlove XML | `.xml` | Yes | Yes |
| MP4Chaps | `.txt` | Yes | Yes |
| FFMetadata | `.ini` | Yes | Yes |
| Podcast Namespace | `.json` | Yes | Yes |
| Cue Sheet | `.cue` | Yes | Yes |
| Markdown | `.md` | Yes | No |

Use `ChapterExporter` for direct format conversion:

```swift
let exporter = ChapterExporter()

// Export to Podlove JSON
let json = try exporter.export(chapters, format: .podloveJSON)

// Round-trip: import the exported JSON
let imported = try exporter.importChapters(from: json, format: .podloveJSON)
```

Or use the engine to import chapters directly into an audio file:

```swift
let engine = AudioMarkerEngine()
try engine.importChapters(from: json, format: .podloveJSON, to: url)

// Export chapters from a file
let exported = try engine.exportChapters(from: url, format: .podloveJSON)
```

### Synchronized Lyrics

Build timestamped lyrics with optional karaoke segments and speaker attribution:

```swift
// Simple synchronized lyrics
let lyrics = SynchronizedLyrics(
    language: "eng",
    lines: [
        LyricLine(time: .zero, text: "First line"),
        LyricLine(time: .seconds(5.5), text: "Second line"),
        LyricLine(time: .seconds(90), text: "Last line")
    ])

// Karaoke — word-level timing
let karaokeLines = [
    LyricLine(
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
]

// Speaker identification
let dialogue = SynchronizedLyrics(
    language: "eng",
    lines: [
        LyricLine(time: .zero, text: "Hello!", speaker: "Alice"),
        LyricLine(time: .seconds(3), text: "Hi there!", speaker: "Bob"),
        LyricLine(time: .seconds(6), text: "How are you?", speaker: "Alice")
    ])
```

When writing to M4A, the library uses smart storage routing:

- **Simple mono-language lyrics** (no karaoke, no speakers) are stored as LRC for maximum player compatibility
- **Multi-language, karaoke, or speaker-attributed lyrics** are stored as TTML for full fidelity

### Lyrics Import/Export

Export and import lyrics in 4 formats:

```swift
// LRC
let lrcOutput = LRCParser.export(lyrics)
let parsed = try LRCParser.parse(lrcOutput, language: "eng")

// TTML — with title and audio duration
let ttml = TTMLExporter.export(
    lyrics,
    audioDuration: .seconds(15),
    title: "My Song")
let ttmlParsed = try TTMLParser().parseLyrics(from: ttml)

// WebVTT
let vtt = WebVTTExporter.export([lyrics], audioDuration: .seconds(15))
let vttParsed = try WebVTTExporter.parse(vtt, language: "eng")

// SRT
let srt = SRTExporter.export([lyrics], audioDuration: .seconds(10))
let srtParsed = try SRTExporter.parse(srt, language: "eng")
```

TTML supports full document-level round-trips including speaker agents, styles, and regions:

```swift
// Convert lyrics with speakers to a TTML document
let doc = TTMLDocument.from([dialogue])
let ttml = TTMLExporter.exportDocument(doc)

// Re-parse — speakers survive the round-trip
let reparsedDoc = try TTMLParser().parseDocument(from: ttml)
let reparsedLyrics = reparsedDoc.toSynchronizedLyrics()
// reparsedLyrics[0].lines[0].speaker == "Alice"
```

### Timestamps

`AudioTimestamp` provides millisecond-precision timestamps with parsing and formatting:

```swift
// Factory methods
let zero = AudioTimestamp.zero
let fromSeconds = AudioTimestamp.seconds(90.5)
let fromMillis = AudioTimestamp.milliseconds(5250)

// Parse from strings
let parsed = try AudioTimestamp(string: "01:30:00")    // 5400s
let parsed2 = try AudioTimestamp(string: "05:30.250")  // 330.25s

// Formatting
fromSeconds.description       // "00:01:30.500"
AudioTimestamp.seconds(60).shortDescription  // "00:01:00"

// Comparable — timestamps sort naturally
let sorted = [fromSeconds, zero, fromMillis].sorted()
```

### Validation

`AudioValidator` checks an `AudioFileInfo` against a set of rules and returns all issues found:

```swift
let engine = AudioMarkerEngine()
let info = try engine.read(from: url)

let validator = AudioValidator()
let result = validator.validate(info)

if result.isValid {
    print("No errors found")
}
for error in result.errors {
    print("Error: \(error.message)")
}
for warning in result.warnings {
    print("Warning: \(warning.message)")
}
```

10 built-in rules:

| Rule | Category | What it checks |
|------|----------|----------------|
| `ChapterOrderRule` | Chapters | Start times in ascending order |
| `ChapterOverlapRule` | Chapters | No overlapping time ranges |
| `ChapterTitleRule` | Chapters | All chapters have non-empty titles |
| `ChapterBoundsRule` | Chapters | End time does not exceed audio duration |
| `ChapterNonNegativeRule` | Chapters | No negative timestamps |
| `MetadataTitleRule` | Metadata | Title present and non-empty |
| `ArtworkFormatRule` | Metadata | Artwork format is JPEG or PNG |
| `MetadataYearRule` | Metadata | Year is a reasonable value (> 0) |
| `LanguageCodeRule` | Metadata | Language is a valid 3-letter ISO 639-2 code |
| `RatingRangeRule` | Metadata | Rating is in 0-255 range |

Add custom rules via the `ValidationRule` protocol:

```swift
struct GenreRequiredRule: ValidationRule {
    let name = "Genre Required"
    func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
        if info.metadata.genre == nil || info.metadata.genre?.isEmpty == true {
            return [
                ValidationIssue(
                    severity: .warning,
                    message: "Genre is recommended for discoverability.")
            ]
        }
        return []
    }
}

let validator = AudioValidator(rules: [GenreRequiredRule()])
```

The engine can also auto-validate before writing:

```swift
let config = Configuration(validateBeforeWriting: true)
let engine = AudioMarkerEngine(configuration: config)

// Throws AudioMarkerError.validationFailed if validation fails
try engine.write(info, to: url)
```

### Batch Processing

`BatchProcessor` processes multiple files in parallel with bounded `TaskGroup` concurrency:

```swift
let items = urls.map { BatchItem(url: $0, operation: .read) }

let processor = BatchProcessor(maxConcurrency: 2)
let summary = await processor.process(items)

print("Total: \(summary.total)")
print("Succeeded: \(summary.succeeded)")
print("Failed: \(summary.failed)")
```

Track progress via `AsyncStream`:

```swift
let processor = BatchProcessor(maxConcurrency: 2)
for await progress in processor.processWithProgress(items) {
    print("\(progress.completed)/\(progress.total)")
    if progress.isFinished {
        print("Done!")
    }
}
```

Supported batch operations: `.read`, `.write(_:)`, `.strip`, `.exportChapters(format:outputURL:)`.

### Configuration

Customize engine behavior:

```swift
let config = Configuration(
    id3Version: .v2_4,
    validateBeforeWriting: false,
    preserveUnknownData: false,
    id3PaddingSize: 4096
)
let engine = AudioMarkerEngine(configuration: config)
```

| Option | Default | Description |
|--------|---------|-------------|
| `id3Version` | `.v2_3` | ID3v2 version for MP3 writes |
| `validateBeforeWriting` | `true` | Run validation before writing |
| `preserveUnknownData` | `true` | Keep unknown frames during modify |
| `id3PaddingSize` | `2048` | Padding bytes in ID3v2 tags |

## Architecture

```
Sources/
    AudioMarker/             # Core library (zero external dependencies)
        Model/               # AudioFileInfo, AudioMetadata, Chapter, Timestamp, Lyrics, Artwork
        ID3/                 # ID3v2 reader/writer (v2.3 and v2.4)
        MP4/                 # MP4/M4A atom reader/writer (ISOBMFF + iTunes)
        Streaming/           # FileReader, FileWriter, BinaryReader — chunk-based I/O
        Exporter/            # ChapterExporter, LRC, TTML, WebVTT, SRT, Cue Sheet, Podlove, ...
        Validator/           # AudioValidator, ValidationRule, 10 built-in rules
        Batch/               # BatchProcessor with TaskGroup concurrency
        Engine/              # AudioMarkerEngine facade
    AudioMarkerCommands/     # CLI implementations (depends on ArgumentParser)
    AudioMarkerCLI/          # Executable entry point (@main)
```

## CLI

`audio-marker` is a command-line tool for managing audio file metadata, chapters, lyrics, and artwork. It provides 17 commands across 9 subgroups.

### Install the CLI

Build from source:

```bash
swift build -c release
cp .build/release/audio-marker /usr/local/bin/
```

### read

Read all metadata and chapters from an audio file:

```bash
audio-marker read podcast.mp3
audio-marker read podcast.mp3 --format json
```

### write

Set metadata fields on an audio file:

```bash
audio-marker write podcast.mp3 \
    --title "Episode 42" \
    --artist "The Host" \
    --album "My Podcast" \
    --year 2025 \
    --genre "Podcast" \
    --track-number 42 \
    --composer "Producer" \
    --album-artist "Show Name" \
    --comment "Season 3" \
    --bpm 120 \
    --artwork cover.jpg
```

### chapters list

List all chapters with timestamps:

```bash
audio-marker chapters list podcast.mp3
```

### chapters add

Add a chapter at a given timestamp:

```bash
audio-marker chapters add podcast.mp3 --start 00:01:30 --title "Verse 1"
audio-marker chapters add podcast.mp3 --start 00:05:00 --title "Sponsor" \
    --url "https://example.com/sponsor"
audio-marker chapters add podcast.m4a --start 00:00:00 --title "Intro" \
    --artwork chapter-art.jpg
```

### chapters remove

Remove a chapter by index (1-based) or by title:

```bash
audio-marker chapters remove podcast.mp3 --index 3
audio-marker chapters remove podcast.mp3 --title "Sponsor"
```

### chapters import

Import chapters from a file:

```bash
audio-marker chapters import podcast.mp3 --from chapters.json --format podlove-json
audio-marker chapters import podcast.mp3 --from chapters.xml --format podlove-xml
audio-marker chapters import podcast.mp3 --from chapters.txt --format mp4chaps
audio-marker chapters import podcast.mp3 --from chapters.ini --format ffmetadata
```

### chapters export

Export chapters to a file or stdout:

```bash
audio-marker chapters export podcast.mp3 --format podlove-json
audio-marker chapters export podcast.mp3 --to chapters.json --format podlove-json
audio-marker chapters export podcast.mp3 --format mp4chaps
audio-marker chapters export podcast.mp3 --format markdown
```

### chapters clear

Remove all chapters:

```bash
audio-marker chapters clear podcast.mp3 --force
```

### lyrics export

Export synchronized lyrics:

```bash
audio-marker lyrics export song.mp3 --format lrc
audio-marker lyrics export song.mp3 --to lyrics.ttml --format ttml
audio-marker lyrics export song.mp3 --to lyrics.vtt --format webvtt
audio-marker lyrics export song.mp3 --to lyrics.srt --format srt
```

### lyrics import

Import synchronized lyrics from a file:

```bash
audio-marker lyrics import song.mp3 --from lyrics.lrc --format lrc
audio-marker lyrics import song.mp3 --from lyrics.ttml --format ttml
audio-marker lyrics import song.mp3 --from lyrics.vtt --format webvtt
audio-marker lyrics import song.mp3 --from lyrics.srt --format srt
```

### lyrics clear

Remove all lyrics:

```bash
audio-marker lyrics clear song.mp3 --force
```

### artwork extract

Extract embedded artwork to a file:

```bash
audio-marker artwork extract song.mp3 --output cover.jpg
```

### validate

Validate metadata and chapters against built-in rules:

```bash
audio-marker validate podcast.mp3
audio-marker validate podcast.mp3 --format json
```

### strip

Remove all metadata (preserves chapters):

```bash
audio-marker strip podcast.mp3 --force
```

### batch read

Read metadata from all audio files in a directory:

```bash
audio-marker batch read ./episodes/
audio-marker batch read ./episodes/ --recursive --concurrency 4
```

### batch strip

Strip metadata from all audio files in a directory:

```bash
audio-marker batch strip ./episodes/ --force
audio-marker batch strip ./episodes/ --recursive --force --concurrency 2
```

### info

Display technical information about an audio file:

```bash
audio-marker info podcast.mp3
```

## Roadmap

Planned for future releases:

- **New audio formats** — FLAC, WAV, AIFF, OGG Vorbis/Opus
- **Linux support** — cross-platform Foundation compatibility
- **Legacy ID3** — ID3v1 and ID3v2.2 read support
- **Additional artwork formats** — WebP, AVIF, HEIF

## Documentation

Full API documentation is available as a DocC catalog bundled with the package. Open the project in Xcode and select **Product → Build Documentation** to browse it locally.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute.

## License

MIT License. See [LICENSE](LICENSE) for details.

Copyright (c) 2026 Atelier Socle SAS.
