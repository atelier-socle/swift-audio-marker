# ``AudioMarker/ChapterList``

An ordered, mutable collection of chapters.

## Overview

`ChapterList` conforms to `RandomAccessCollection` and provides mutation methods for building chapter timelines. It is the primary container for chapters in ``AudioFileInfo``.

```swift
var list = ChapterList([
    Chapter(start: .zero, title: "Intro"),
    Chapter(start: .seconds(60), title: "Verse")
])
list.append(Chapter(start: .seconds(120), title: "Chorus"))
list.sort()

let withEnds = list.withCalculatedEndTimes(audioDuration: .seconds(180))
```

## Topics

### Creating

- ``init(_:)``

### Collection

- ``startIndex``
- ``endIndex``
- ``count``
- ``isEmpty``

### Mutation

- ``append(_:)``
- ``insert(_:at:)``
- ``remove(at:)``
- ``sort()``
- ``clearEndTimes()``

### End Time Calculation

- ``withCalculatedEndTimes(audioDuration:)``
