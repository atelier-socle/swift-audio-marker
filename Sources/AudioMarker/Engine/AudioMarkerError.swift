import Foundation

/// High-level errors from AudioMarker operations.
public enum AudioMarkerError: Error, Sendable, Hashable, LocalizedError {
    /// The audio format could not be detected.
    case unknownFormat(String)
    /// The detected format is not supported for this operation.
    case unsupportedFormat(AudioFormat, operation: String)
    /// The file could not be read.
    case readFailed(String)
    /// The file could not be written.
    case writeFailed(String)
    /// Validation failed with blocking errors.
    case validationFailed([ValidationIssue])

    public var errorDescription: String? {
        switch self {
        case .unknownFormat(let path):
            "Unknown audio format for file: \(path)."
        case .unsupportedFormat(let format, let operation):
            "Format \(format.rawValue) is not supported for \(operation)."
        case .readFailed(let detail):
            "Read failed: \(detail)"
        case .writeFailed(let detail):
            "Write failed: \(detail)"
        case .validationFailed(let issues):
            "Validation failed with \(issues.count) error(s)."
        }
    }
}
