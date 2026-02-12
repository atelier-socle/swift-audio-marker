# ``AudioMarker/ChapterExporter``

Converts chapters between 11 interchange formats.

## Overview

`ChapterExporter` handles bidirectional conversion between ``ChapterList`` and text-based chapter formats. Use it for standalone format conversion, or go through ``AudioMarkerEngine`` for file-level import/export.

```swift
let exporter = ChapterExporter()

let chapters = ChapterList([
    Chapter(start: .zero, title: "Introduction"),
    Chapter(start: .seconds(60), title: "Main Discussion"),
    Chapter(start: .seconds(300), title: "Q&A Session")
])

// Export
let json = try exporter.export(chapters, format: .podloveJSON)

// Import
let imported = try exporter.importChapters(from: json, format: .podloveJSON)
```

See ``ExportFormat`` for all supported formats and their import/export capabilities.

## Topics

### Creating

- ``init()``

### Export

- ``export(_:format:)``

### Import

- ``importChapters(from:format:)``
