import Foundation

/// The result of processing a single batch item.
public struct BatchResult: Sendable {

    /// The original item.
    public let item: BatchItem

    /// The outcome: success with optional data, or failure.
    public let outcome: Outcome

    /// Possible outcomes for a batch item.
    public enum Outcome: Sendable {
        /// The operation succeeded with optional file info (present for reads).
        case success(AudioFileInfo?)
        /// The operation failed with an error.
        case failure(Error)
    }

    /// Whether the operation succeeded.
    public var isSuccess: Bool {
        if case .success = outcome { return true }
        return false
    }

    /// The `AudioFileInfo` if the operation was a successful read.
    public var info: AudioFileInfo? {
        if case .success(let fileInfo) = outcome { return fileInfo }
        return nil
    }

    /// The error if the operation failed.
    public var error: Error? {
        if case .failure(let error) = outcome { return error }
        return nil
    }
}
