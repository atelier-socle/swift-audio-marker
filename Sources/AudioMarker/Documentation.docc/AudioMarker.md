# ``AudioMarker``

@Metadata {
    @DisplayName("AudioMarker")
}

Production-grade Swift library for enriching audio files with chapters, metadata, artwork, and synchronized lyrics.

## Overview

**AudioMarker** provides a unified, type-safe API for reading and writing audio metadata across MP3, M4A, and M4B formats. It handles ID3v2 tags (MP3) and ISOBMFF atoms (M4A/M4B) natively in pure Swift — no FFmpeg, no third-party dependencies.

```swift
let engine = AudioMarkerEngine()

// Read metadata from any supported format
let info = try engine.read(from: fileURL)
print(info.metadata.title ?? "Untitled")

// Modify and write back — no re-encoding
var modified = info
modified.metadata.title = "New Title"
modified.chapters = ChapterList([
    Chapter(start: .zero, title: "Intro"),
    Chapter(start: .seconds(60), title: "Main Discussion"),
    Chapter(start: .seconds(300), title: "Q&A Session")
])
try engine.write(modified, to: fileURL)
```

### Key Features

- **Metadata** — Read and write 30+ fields: title, artist, album, artwork, BPM, ISRC, URLs, custom data, and more.
- **Chapters** — Inject, extract, and convert chapter markers with per-chapter artwork and URLs.
- **Synchronized lyrics** — LRC, TTML (karaoke, multi-language, speakers), WebVTT, SRT support.
- **Export/Import** — 11 chapter formats: Podlove JSON/XML, MP4Chaps, FFMetadata, Podcasting 2.0, Cue Sheet, Markdown, and more.
- **Validation** — Pluggable rules engine with built-in checks and custom rule support.
- **Batch processing** — Parallel operations on multiple files with progress tracking via `AsyncSequence`.
- **CLI** — Full-featured command-line tool with 9 command groups and 17 subcommands.

### How It Works

1. **Detect** the audio format automatically from magic bytes and file extension.
2. **Read** metadata and chapters using native ID3v2 or MP4 atom parsers — never loading the entire file into memory.
3. **Modify** the in-memory model (``AudioFileInfo``, ``AudioMetadata``, ``ChapterList``).
4. **Validate** changes against built-in or custom rules.
5. **Write** back to disk — metadata is injected without re-encoding the audio data.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ReadingAndWriting>

### Chapters

- <doc:ChaptersGuide>
- <doc:ChapterFormats>

### Lyrics

- <doc:SynchronizedLyricsGuide>
- <doc:LyricsFormats>

### Quality

- <doc:ValidationGuide>

### Performance

- <doc:BatchProcessing>

### CLI

- <doc:CLIReference>

### Engine

- ``AudioMarkerEngine``
- ``AudioFormat``
- ``Configuration``
- ``AudioMarkerError``

### Model Types

- ``AudioFileInfo``
- ``AudioMetadata``
- ``Chapter``
- ``ChapterList``
- ``AudioTimestamp``
- ``AudioTimestampError``
- ``Artwork``
- ``ArtworkFormat``
- ``ArtworkError``

### Lyrics Types

- ``SynchronizedLyrics``
- ``LyricLine``
- ``LyricSegment``
- ``ContentType``

### ID3

- ``ID3Reader``
- ``ID3Writer``
- ``ID3TagBuilder``
- ``ID3FrameParser``
- ``ID3FrameBuilder``
- ``ID3Frame``
- ``ID3FrameID``
- ``ID3Header``
- ``ID3TagFlags``
- ``ID3Version``
- ``ID3TextEncoding``
- ``ID3Error``
- ``SyncLyricEvent``

### MP4

- ``MP4Reader``
- ``MP4Writer``
- ``MP4Atom``
- ``MP4AtomType``
- ``MP4AtomParser``
- ``MP4AtomBuilder``
- ``MP4ChapterParser``
- ``MP4ChapterBuilder``
- ``MP4MetadataParser``
- ``MP4MetadataBuilder``
- ``MP4MoovBuilder``
- ``MP4TextTrackBuilder``
- ``MP4VideoTrackBuilder``
- ``MP4Error``

### Exporters

- ``ChapterExporter``
- ``ExportFormat``
- ``ExportError``
- ``LRCParser``
- ``TTMLExporter``
- ``TTMLParser``
- ``TTMLDocument``
- ``TTMLDivision``
- ``TTMLParagraph``
- ``TTMLSpan``
- ``TTMLStyle``
- ``TTMLRegion``
- ``TTMLAgent``
- ``TTMLTimeParser``
- ``TTMLParseError``
- ``WebVTTExporter``
- ``SRTExporter``

### Validation

- ``AudioValidator``
- ``ValidationRule``
- ``ValidationResult``
- ``ValidationIssue``
- ``ValidationSeverity``
- ``ChapterOrderRule``
- ``ChapterOverlapRule``
- ``ChapterTitleRule``
- ``ChapterBoundsRule``
- ``ChapterNonNegativeRule``
- ``MetadataTitleRule``
- ``MetadataYearRule``
- ``ArtworkFormatRule``
- ``LanguageCodeRule``
- ``RatingRangeRule``

### Batch

- ``BatchProcessor``
- ``BatchOperation``
- ``BatchItem``
- ``BatchResult``
- ``BatchProgress``
- ``BatchSummary``

### Streaming

- ``BinaryReader``
- ``BinaryWriter``
- ``FileReader``
- ``FileWriter``
- ``StreamingConstants``
- ``BinaryReaderError``
- ``StreamingError``

### Other

- ``PrivateData``
- ``UniqueFileIdentifier``
