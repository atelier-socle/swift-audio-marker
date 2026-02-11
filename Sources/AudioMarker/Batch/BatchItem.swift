import Foundation

/// A single item in a batch operation.
public struct BatchItem: Sendable, Hashable {

    /// The file URL to process.
    public let url: URL

    /// The operation to perform.
    public let operation: BatchOperation

    /// Creates a batch item.
    /// - Parameters:
    ///   - url: The file URL to process.
    ///   - operation: The operation to perform on the file.
    public init(url: URL, operation: BatchOperation) {
        self.url = url
        self.operation = operation
    }
}
