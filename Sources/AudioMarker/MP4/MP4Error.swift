import Foundation

/// Errors that can occur during MP4 file reading or writing.
public enum MP4Error: Error, Sendable, LocalizedError {

    /// The file is not a valid MP4/M4A/M4B file.
    case invalidFile(String)

    /// A required atom was not found.
    case atomNotFound(String)

    /// An atom has invalid or corrupt data.
    case invalidAtom(type: String, reason: String)

    /// The file type is not supported.
    case unsupportedFileType(String)

    /// The atom data is truncated or corrupt.
    case truncatedData(expected: Int, available: Int)

    /// A write operation failed.
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFile(let reason):
            return "Invalid MP4 file: \(reason)."
        case .atomNotFound(let type):
            return "Required MP4 atom not found: \"\(type)\"."
        case .invalidAtom(let type, let reason):
            return "Invalid MP4 atom \"\(type)\": \(reason)."
        case .unsupportedFileType(let fileType):
            return "Unsupported MP4 file type: \"\(fileType)\"."
        case .truncatedData(let expected, let available):
            return "Truncated MP4 data: expected \(expected) bytes, \(available) available."
        case .writeFailed(let reason):
            return "MP4 write failed: \(reason)."
        }
    }
}
