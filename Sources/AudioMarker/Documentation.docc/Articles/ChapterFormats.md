# Chapter Export and Import Formats

Convert chapters between 11 interchange formats.

## Overview

``ChapterExporter`` converts between ``ChapterList`` and text-based chapter formats. All formats that support import also support round-trip: export → import → compare.

### Supported Formats

| Format | Extension | Import | Export |
|--------|-----------|--------|--------|
| Podlove JSON | `.json` | Yes | Yes |
| Podlove XML | `.xml` | Yes | Yes |
| MP4Chaps | `.chapters.txt` | Yes | Yes |
| FFMetadata | `.ffmetadata` | Yes | Yes |
| Podcasting 2.0 | `.json` | Yes | Yes |
| Cue Sheet | `.cue` | Yes | Yes |
| LRC | `.lrc` | Yes | Yes |
| TTML | `.ttml` | Yes | Yes |
| WebVTT | `.vtt` | Yes | Yes |
| SRT | `.srt` | Yes | Yes |
| Markdown | `.md` | No | Yes |

### Export Chapters

```swift
let exporter = ChapterExporter()

let chapters = ChapterList([
    Chapter(
        start: .zero, title: "Introduction",
        url: URL(string: "https://example.com/intro")),
    Chapter(start: .seconds(60), title: "Main Discussion"),
    Chapter(start: .seconds(300), title: "Q&A Session")
])

// Export to any format
let json = try exporter.export(chapters, format: .podloveJSON)
let xml = try exporter.export(chapters, format: .podloveXML)
let mp4chaps = try exporter.export(chapters, format: .mp4chaps)
let ffmeta = try exporter.export(chapters, format: .ffmetadata)
let md = try exporter.export(chapters, format: .markdown)
```

### Import Chapters

```swift
// Import from any supported format
let imported = try exporter.importChapters(from: json, format: .podloveJSON)
// imported.count == 3
// imported[0].title == "Introduction"
```

### Engine Integration

Import chapters directly into an audio file:

```swift
let engine = AudioMarkerEngine()
let json = """
    {
      "version": "1.2",
      "chapters": [
        { "start": "00:00:00.000", "title": "Opening" },
        { "start": "00:01:00.000", "title": "Middle" },
        { "start": "00:05:00.000", "title": "End" }
      ]
    }
    """
try engine.importChapters(from: json, format: .podloveJSON, to: fileURL)

// Export from a file
let exported = try engine.exportChapters(from: fileURL, format: .podloveJSON)
```

### Format Details

**Podlove JSON** — Standard podcast chapter format:
```
{"version":"1.2","chapters":[{"start":"00:00:00.000","title":"Intro"}]}
```

**MP4Chaps** — One chapter per line:
```
00:00:00.000 Introduction
00:01:00.000 Main Discussion
```

**FFMetadata** — Compatible with FFmpeg:
```
;FFMETADATA1
[CHAPTER]
TIMEBASE=1/1000
START=0
title=Introduction
```

## Next Steps

- <doc:ChaptersGuide> — Creating and manipulating chapters
- <doc:SynchronizedLyricsGuide> — Timestamped lyrics formats
- <doc:CLIReference> — Export/import chapters from the command line
