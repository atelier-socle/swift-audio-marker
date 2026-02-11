import Foundation

/// Errors that can occur during chapter export or import.
public enum ExportError: Error, LocalizedError, Sendable, Hashable {
    /// The export format does not support importing.
    case importNotSupported(String)
    /// The input data is malformed or cannot be parsed.
    case invalidData(String)
    /// The input string is malformed or cannot be parsed.
    case invalidFormat(String)
    /// An I/O error occurred during file operations.
    case ioError(String)

    public var errorDescription: String? {
        switch self {
        case .importNotSupported(let format):
            "Import is not supported for \(format) format."
        case .invalidData(let detail):
            "Invalid data: \(detail)."
        case .invalidFormat(let detail):
            "Invalid format: \(detail)."
        case .ioError(let detail):
            "I/O error: \(detail)."
        }
    }
}
