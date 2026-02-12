# ``AudioMarker/Chapter``

A single chapter marker in an audio file.

## Overview

Each `Chapter` has a start time and title. Optionally, it can have an end time, a URL, and per-chapter artwork. Chapters are collected in a ``ChapterList``.

```swift
let chapter = Chapter(
    start: .seconds(90),
    title: "Verse 1",
    url: URL(string: "https://example.com/verse1"))
```

`Chapter` conforms to `Identifiable` (each instance has a unique UUID), `Hashable`, and `Sendable`.

## Topics

### Creating

- ``init(start:title:end:url:artwork:)``

### Properties

- ``id``
- ``start``
- ``end``
- ``title``
- ``url``
- ``artwork``
