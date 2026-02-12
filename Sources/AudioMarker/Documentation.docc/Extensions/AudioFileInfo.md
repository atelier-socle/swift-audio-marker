# ``AudioMarker/AudioFileInfo``

Complete representation of an audio file's metadata, chapters, and duration.

## Overview

`AudioFileInfo` is the primary data container passed to and returned from ``AudioMarkerEngine``. It bundles ``AudioMetadata``, a ``ChapterList``, and an optional duration timestamp.

```swift
let info = AudioFileInfo(
    metadata: AudioMetadata(title: "My Song", artist: "Artist"),
    chapters: ChapterList([
        Chapter(start: .zero, title: "Intro"),
        Chapter(start: .seconds(60), title: "Verse")
    ]),
    duration: .seconds(300)
)
```

## Topics

### Creating

- ``init(metadata:chapters:duration:)``

### Properties

- ``metadata``
- ``chapters``
- ``duration``
