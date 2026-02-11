/// Progress update for a batch operation.
public struct BatchProgress: Sendable {

    /// Total number of items in the batch.
    public let total: Int

    /// Number of items completed so far.
    public let completed: Int

    /// The most recently completed item's result.
    public let latestResult: BatchResult?

    /// Progress as a fraction (0.0 to 1.0).
    public var fraction: Double {
        total == 0 ? 1.0 : Double(completed) / Double(total)
    }

    /// Whether all items have been processed.
    public var isFinished: Bool {
        completed >= total
    }
}
