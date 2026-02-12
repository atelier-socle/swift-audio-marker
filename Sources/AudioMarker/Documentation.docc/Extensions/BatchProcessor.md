# ``AudioMarker/BatchProcessor``

Processes multiple audio files in parallel with bounded concurrency.

## Overview

`BatchProcessor` executes ``BatchOperation`` items concurrently using structured concurrency. It supports reading, writing, stripping, and chapter operations — all with progress reporting via `AsyncSequence`.

```swift
let processor = BatchProcessor(maxConcurrency: 4)
let items = urls.map { BatchItem(url: $0, operation: .read) }
let summary = await processor.process(items)
```

For real-time progress tracking:

```swift
for await progress in processor.processWithProgress(items) {
    print("\(progress.completed)/\(progress.total)")
}
```

## Topics

### Creating

- ``init(engine:maxConcurrency:)``

### Processing

- ``process(_:)``
- ``processWithProgress(_:)``

### Configuration

- ``engine``
- ``maxConcurrency``
