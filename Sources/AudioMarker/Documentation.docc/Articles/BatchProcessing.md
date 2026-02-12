# Batch Processing

Process multiple audio files in parallel with progress tracking.

## Overview

``BatchProcessor`` executes operations on multiple files concurrently using structured concurrency. It supports reading, writing, stripping, and chapter export/import — all with bounded parallelism and real-time progress reporting via `AsyncSequence`.

### Basic Batch Read

```swift
let processor = BatchProcessor(maxConcurrency: 2)

let items = fileURLs.map { BatchItem(url: $0, operation: .read) }
let summary = await processor.process(items)

summary.total     // number of files
summary.succeeded // successful operations
summary.failed    // failed operations
summary.allSucceeded // true if zero failures
```

### Progress Tracking

Use ``BatchProcessor/processWithProgress(_:)`` to observe progress in real time:

```swift
let processor = BatchProcessor(maxConcurrency: 2)
let items = urls.map { BatchItem(url: $0, operation: .read) }

for await progress in processor.processWithProgress(items) {
    print("\(progress.completed)/\(progress.total)")
    print("Progress: \(progress.fraction * 100)%")

    if progress.isFinished {
        print("Done!")
    }
}
```

``BatchProgress`` provides:
- `total` — Total number of items
- `completed` — Number of items processed so far
- `fraction` — Completion fraction (0.0 to 1.0)
- `isFinished` — Whether all items have been processed
- `latestResult` — The most recent ``BatchResult``

### Mixed Operations

Combine different operations in a single batch:

```swift
var writeInfo = AudioFileInfo()
writeInfo.metadata.title = "Written Title"

let items: [BatchItem] = [
    BatchItem(url: readURL, operation: .read),
    BatchItem(url: writeURL, operation: .write(writeInfo)),
    BatchItem(url: stripURL, operation: .strip)
]

let summary = await BatchProcessor().process(items)
```

### Chapter Export

Export chapters from multiple files:

```swift
let items = [
    BatchItem(
        url: audioURL,
        operation: .exportChapters(
            format: .podloveJSON,
            outputURL: outputURL))
]

let summary = await BatchProcessor().process(items)
```

### Error Handling

Failed operations don't crash the batch — each file is processed independently:

```swift
let items = [
    BatchItem(url: validURL, operation: .read),
    BatchItem(url: invalidURL, operation: .read) // doesn't exist
]

let summary = await BatchProcessor().process(items)
summary.succeeded // 1
summary.failed    // 1
summary.errors    // [Error] for failed items
```

### BatchSummary

``BatchSummary`` provides aggregate results:
- `results` — All ``BatchResult`` values
- `total`, `succeeded`, `failed` — Counts
- `errors` — Collected errors from failures
- `readResults` — ``AudioFileInfo`` values from successful reads
- `allSucceeded` — Quick check for zero failures

## Next Steps

- <doc:ReadingAndWriting> — Single-file operations
- <doc:CLIReference> — Batch commands from the CLI
