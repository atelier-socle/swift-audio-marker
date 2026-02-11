import Foundation

/// Errors that can occur during streaming I/O operations.
public enum StreamingError: Error, Sendable, Hashable, LocalizedError {

    /// The file was not found at the given URL.
    case fileNotFound(String)

    /// The file could not be opened for reading or writing.
    case cannotOpenFile(String)

    /// An error occurred while reading from the file.
    case readFailed(String)

    /// An error occurred while writing to the file.
    case writeFailed(String)

    /// The requested byte range is outside the file bounds.
    case outOfBounds(offset: UInt64, fileSize: UInt64)

    /// The buffer size is outside the allowed range.
    case invalidBufferSize(Int)

    /// The file is too small to contain valid data.
    case fileTooSmall(expected: Int, actual: UInt64)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found at path: \"\(path)\"."
        case .cannotOpenFile(let path):
            return "Cannot open file at path: \"\(path)\"."
        case .readFailed(let detail):
            return "Read failed: \(detail)"
        case .writeFailed(let detail):
            return "Write failed: \(detail)"
        case .outOfBounds(let offset, let fileSize):
            return "Offset \(offset) is out of bounds for file of size \(fileSize)."
        case .invalidBufferSize(let size):
            let min = StreamingConstants.minimumBufferSize
            let max = StreamingConstants.maximumBufferSize
            return "Buffer size \(size) is invalid. Allowed range: \(min)–\(max)."
        case .fileTooSmall(let expected, let actual):
            return "File too small: expected at least \(expected) bytes, got \(actual)."
        }
    }
}
