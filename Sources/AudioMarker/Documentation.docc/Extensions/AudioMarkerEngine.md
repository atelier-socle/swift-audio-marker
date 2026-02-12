# ``AudioMarker/AudioMarkerEngine``

The main entry point for all AudioMarker operations.

## Overview

`AudioMarkerEngine` provides a unified API for reading, writing, and manipulating audio file metadata and chapters across MP3, M4A, and M4B formats. It auto-detects file formats and routes operations to the appropriate native parser.

```swift
let engine = AudioMarkerEngine()
let info = try engine.read(from: fileURL)
```

## Topics

### Creating an Engine

- ``init(configuration:)``
- ``configuration``

### Reading

- ``read(from:)``
- ``detectFormat(of:)``
- ``readChapters(from:)``

### Writing

- ``write(_:to:)``
- ``modify(_:in:)``
- ``writeChapters(_:to:)``

### Chapters

- ``exportChapters(from:format:)``
- ``importChapters(from:format:to:)``

### Stripping

- ``strip(from:)``

### Validation

- ``validate(_:)``
- ``validateOrThrow(_:)``
