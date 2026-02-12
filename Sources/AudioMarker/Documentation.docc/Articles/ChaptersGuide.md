# Working with Chapters

Create, manipulate, and embed chapter markers in audio files.

## Overview

Chapters are defined by ``Chapter`` values and organized in a ``ChapterList``. Each chapter has a start time, title, and optional end time, URL, and artwork.

### Creating Chapters

Build chapters using ``AudioTimestamp`` for precise timing:

```swift
let chapters = [
    Chapter(start: .zero, title: "Intro"),
    Chapter(start: .seconds(30), title: "Hook"),
    Chapter(
        start: .seconds(90), title: "Verse 1",
        url: URL(string: "https://example.com/verse1")),
    Chapter(start: .seconds(180), title: "Chorus"),
    Chapter(
        start: .seconds(270), title: "Outro",
        artwork: Artwork(data: jpegData, format: .jpeg))
]
```

### ChapterList Operations

``ChapterList`` conforms to `RandomAccessCollection` and provides mutation helpers:

```swift
// Create from array
var list = ChapterList(chapters)

// Collection operations
list.count       // 5
list[0].title    // "Intro"

// Append and insert
list.append(Chapter(start: .seconds(350), title: "Bonus"))
list.insert(Chapter(start: .seconds(15), title: "Pre-Hook"), at: 1)

// Sort by start time
list.sort()

// Calculate end times from the next chapter's start
let withEnds = list.withCalculatedEndTimes(audioDuration: .seconds(400))
// withEnds[0].end == withEnds[1].start
// withEnds.last.end == audioDuration
```

### AudioTimestamp

``AudioTimestamp`` supports multiple creation and parsing methods:

```swift
// Factory methods
let zero = AudioTimestamp.zero
let fromSeconds = AudioTimestamp.seconds(90.5)
let fromMillis = AudioTimestamp.milliseconds(5250)

// String parsing
let parsed = try AudioTimestamp(string: "01:30:00")  // 5400 seconds
let precise = try AudioTimestamp(string: "05:30.250") // 330.25 seconds

// Formatting
fromSeconds.description      // "00:01:30.500"
fromSeconds.shortDescription // "00:01:30.500"
AudioTimestamp.seconds(60).shortDescription // "00:01:00"

// Sorting
let sorted = timestamps.sorted() // Comparable
```

### Writing Chapters

Embed chapters directly through the engine:

```swift
let engine = AudioMarkerEngine()
let chapters = ChapterList([
    Chapter(start: .zero, title: "Opening"),
    Chapter(start: .seconds(60), title: "Middle"),
    Chapter(start: .seconds(300), title: "End")
])
try engine.writeChapters(chapters, to: fileURL)
```

Or as part of a full ``AudioFileInfo`` write:

```swift
var info = try engine.read(from: fileURL)
info.chapters = chapters
try engine.write(info, to: fileURL)
```

### Reading Chapters

```swift
let chapters = try engine.readChapters(from: fileURL)
for chapter in chapters {
    print("\(chapter.start.shortDescription) — \(chapter.title)")
}
```

## Next Steps

- <doc:ChapterFormats> — Export and import chapters in 11 formats
- <doc:ReadingAndWriting> — Full metadata read/write workflows
