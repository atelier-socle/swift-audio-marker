# Reading and Writing Metadata

Work with the full range of audio metadata fields across MP3 and M4A formats.

## Overview

``AudioMarkerEngine`` reads and writes metadata through ``AudioFileInfo``, which contains ``AudioMetadata``, a ``ChapterList``, and an optional duration. All metadata operations are non-destructive — audio data is never re-encoded.

### The AudioFileInfo Model

``AudioFileInfo`` is the central data container:

```swift
let info = AudioFileInfo(
    metadata: AudioMetadata(title: "Title"),
    chapters: ChapterList([Chapter(start: .zero, title: "Ch1")]),
    duration: .seconds(300)
)
```

### Metadata Fields

``AudioMetadata`` supports 30+ fields across several categories:

```swift
var meta = AudioMetadata(title: "My Song", artist: "Artist", album: "Album")

// Core fields
meta.genre = "Rock"
meta.year = 2025
meta.trackNumber = 3
meta.discNumber = 1

// Professional fields
meta.composer = "Composer Name"
meta.albumArtist = "Various Artists"
meta.publisher = "Label Records"
meta.copyright = "2025 Label Records"
meta.encoder = "AudioMarker v0.1.0"
meta.comment = "Mastered at Studio X"
meta.bpm = 120
meta.key = "Am"
meta.language = "eng"
meta.isrc = "USRC17607839"

// URLs
meta.artistURL = URL(string: "https://example.com/artist")
meta.audioSourceURL = URL(string: "https://example.com/source")
meta.publisherURL = URL(string: "https://example.com/publisher")
meta.commercialURL = URL(string: "https://example.com/buy")

// Custom data
meta.customTextFields = ["MOOD": "Energetic"]
meta.privateData = [PrivateData(owner: "com.test", data: Data([0x01]))]
meta.playCount = 42
meta.rating = 200
```

### Artwork

Embed cover artwork as JPEG or PNG using ``Artwork``:

```swift
// Explicit format
let artwork = Artwork(data: jpegData, format: .jpeg)

// Auto-detection from magic bytes
let detected = try Artwork(data: imageData)

// Format detection
let format = ArtworkFormat.detect(from: imageData) // .jpeg or .png
print(format.mimeType) // "image/jpeg"
```

### Complete MP3 Workflow

A full read-modify-write cycle on an MP3 file:

```swift
let engine = AudioMarkerEngine()

// Read
var info = try engine.read(from: mp3URL)

// Modify
info.metadata.title = "Updated Song"
info.metadata.artist = "New Artist"
info.metadata.artwork = Artwork(data: jpegData, format: .jpeg)
info.chapters = ChapterList([
    Chapter(start: .zero, title: "Intro"),
    Chapter(start: .seconds(30), title: "Verse"),
    Chapter(start: .seconds(90), title: "Chorus")
])

// Write
try engine.write(info, to: mp3URL)

// Verify
let verified = try engine.read(from: mp3URL)
// verified.metadata.title == "Updated Song"
// verified.chapters.count == 3
```

### Stripping Metadata

Remove all metadata from a file:

```swift
try engine.strip(from: fileURL)
```

## Next Steps

- <doc:ChaptersGuide> — Chapter markers with per-chapter artwork and URLs
- <doc:SynchronizedLyricsGuide> — Timestamped lyrics with karaoke and speaker support
- <doc:ValidationGuide> — Validate metadata integrity before writing
