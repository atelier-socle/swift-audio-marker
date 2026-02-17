// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation

/// Processes multiple audio files in parallel.
///
/// Uses a `TaskGroup` with bounded concurrency to avoid opening too many
/// file handles simultaneously.
///
/// ```swift
/// let processor = BatchProcessor()
/// let items = urls.map { BatchItem(url: $0, operation: .read) }
/// let summary = await processor.process(items)
/// print("Processed \(summary.succeeded)/\(summary.total)")
/// ```
public struct BatchProcessor: Sendable {

    /// The engine used for individual operations.
    public let engine: AudioMarkerEngine

    /// Maximum number of concurrent operations.
    public let maxConcurrency: Int

    /// Creates a batch processor.
    /// - Parameters:
    ///   - engine: The engine to use. Defaults to a default-configured engine.
    ///   - maxConcurrency: Maximum concurrent operations. Clamped to at least 1.
    public init(
        engine: AudioMarkerEngine = AudioMarkerEngine(),
        maxConcurrency: Int = 4
    ) {
        self.engine = engine
        self.maxConcurrency = max(maxConcurrency, 1)
    }

    // MARK: - Processing

    /// Processes all items and returns a summary.
    /// - Parameter items: The batch items to process.
    /// - Returns: Summary with all results.
    public func process(_ items: [BatchItem]) async -> BatchSummary {
        var results: [BatchResult] = []
        await withTaskGroup(of: BatchResult.self) { group in
            var pending = items.makeIterator()
            for _ in 0..<maxConcurrency {
                if let item = pending.next() {
                    group.addTask { processItem(item) }
                }
            }
            for await result in group {
                results.append(result)
                if let item = pending.next() {
                    group.addTask { processItem(item) }
                }
            }
        }
        return BatchSummary(results: results)
    }

    /// Processes all items with progress reporting via `AsyncStream`.
    /// - Parameter items: The batch items to process.
    /// - Returns: An `AsyncStream` of progress updates.
    public func processWithProgress(
        _ items: [BatchItem]
    ) -> AsyncStream<BatchProgress> {
        AsyncStream { continuation in
            let task = Task {
                continuation.yield(
                    BatchProgress(total: items.count, completed: 0, latestResult: nil)
                )
                var completedCount = 0
                await withTaskGroup(of: BatchResult.self) { group in
                    var pending = items.makeIterator()
                    for _ in 0..<maxConcurrency {
                        if let item = pending.next() {
                            group.addTask { processItem(item) }
                        }
                    }
                    for await result in group {
                        completedCount += 1
                        continuation.yield(
                            BatchProgress(
                                total: items.count,
                                completed: completedCount,
                                latestResult: result
                            )
                        )
                        if let item = pending.next() {
                            group.addTask { processItem(item) }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
