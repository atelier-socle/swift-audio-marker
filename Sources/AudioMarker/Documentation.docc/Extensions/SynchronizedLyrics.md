# ``AudioMarker/SynchronizedLyrics``

A set of timestamped lyric lines for a single language.

## Overview

`SynchronizedLyrics` holds an array of ``LyricLine`` values with a language code and optional content type. Multiple `SynchronizedLyrics` can be attached to ``AudioMetadata`` for multi-language support.

```swift
let lyrics = SynchronizedLyrics(
    language: "eng",
    contentType: .lyrics,
    lines: [
        LyricLine(time: .zero, text: "Hello world"),
        LyricLine(time: .seconds(5), text: "Second line")
    ]
)

let sorted = lyrics.sorted() // Lines ordered by time
```

## Topics

### Creating

- ``init(language:contentType:descriptor:lines:)``

### Properties

- ``language``
- ``contentType``
- ``descriptor``
- ``lines``

### Operations

- ``sorted()``
