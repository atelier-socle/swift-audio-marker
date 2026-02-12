# Getting Started with AudioMarker

Add AudioMarker to your project and perform your first read/write cycle.

## Overview

AudioMarker is distributed as a Swift package. Add it to your project, import the module, and use ``AudioMarkerEngine`` as your single entry point for all audio metadata operations.

### Add the Dependency

Add AudioMarker to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/atelier-socle/swift-audio-marker.git", from: "0.1.0")
]
```

Then add it to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "AudioMarker", package: "swift-audio-marker")
    ]
)
```

### Read Metadata

Create an ``AudioMarkerEngine`` and read from any supported file:

```swift
import AudioMarker

let engine = AudioMarkerEngine()
let info = try engine.read(from: fileURL)

print(info.metadata.title ?? "Untitled")
print(info.metadata.artist ?? "Unknown")
print(info.chapters.count, "chapters")
```

The engine auto-detects the file format from magic bytes and file extension. It supports MP3 (ID3v2), M4A, and M4B (ISOBMFF/iTunes atoms).

### Write Metadata

Modify any field and write back without re-encoding the audio:

```swift
var info = try engine.read(from: fileURL)
info.metadata.title = "Updated Song"
info.metadata.artist = "New Artist"
info.metadata.album = "New Album"
info.metadata.year = 2025
info.metadata.genre = "Indie"
try engine.write(info, to: fileURL)
```

### Format Detection

Detect the format of an audio file before processing:

```swift
let format = try engine.detectFormat(of: fileURL)
// .mp3, .m4a, or .m4b

// Format properties
print(format.usesID3)   // true for MP3
print(format.usesMP4)   // true for M4A/M4B
```

### Configuration

Customize engine behavior with ``Configuration``:

```swift
let config = Configuration(
    id3Version: .v2_4,
    validateBeforeWriting: true,
    preserveUnknownData: true,
    id3PaddingSize: 4096
)
let engine = AudioMarkerEngine(configuration: config)
```

## Next Steps

- <doc:ReadingAndWriting> — Deep dive into metadata fields and round-trip workflows
- <doc:ChaptersGuide> — Add chapter markers to your audio files
- <doc:SynchronizedLyricsGuide> — Embed timestamped lyrics
- <doc:ValidationGuide> — Validate metadata before writing
