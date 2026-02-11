import Foundation

/// Summary of a completed batch operation.
public struct BatchSummary: Sendable {

    /// All individual results.
    public let results: [BatchResult]

    /// Total number of items processed.
    public var total: Int { results.count }

    /// Number of successful items.
    public var succeeded: Int {
        results.filter(\.isSuccess).count
    }

    /// Number of failed items.
    public var failed: Int {
        results.filter { !$0.isSuccess }.count
    }

    /// All errors that occurred, paired with their source URLs.
    public var errors: [(url: URL, error: Error)] {
        results.compactMap { result in
            if case .failure(let error) = result.outcome {
                return (url: result.item.url, error: error)
            }
            return nil
        }
    }

    /// All successfully read `AudioFileInfo` results, paired with their source URLs.
    public var readResults: [(url: URL, info: AudioFileInfo)] {
        results.compactMap { result in
            if case .success(let info?) = result.outcome {
                return (url: result.item.url, info: info)
            }
            return nil
        }
    }

    /// Whether all items succeeded.
    public var allSucceeded: Bool {
        failed == 0
    }
}
