# ``AudioMarker/AudioTimestamp``

A precise time position within an audio file.

## Overview

`AudioTimestamp` represents a point in time with millisecond precision. It supports multiple creation methods, string parsing, formatting, and comparison. All chapter start/end times and lyric timestamps use this type.

```swift
let zero = AudioTimestamp.zero
let ts = AudioTimestamp.seconds(90.5)
let ms = AudioTimestamp.milliseconds(5250)
let parsed = try AudioTimestamp(string: "01:30:00")

ts.description      // "00:01:30.500"
ts.shortDescription // "00:01:30.500"
```

`AudioTimestamp` conforms to `Comparable`, so timestamps can be sorted directly.

## Topics

### Creating

- ``zero``
- ``seconds(_:)``
- ``milliseconds(_:)``
- ``init(timeInterval:)``
- ``init(string:)``

### Properties

- ``timeInterval``

### Formatting

- ``description``
- ``shortDescription``
