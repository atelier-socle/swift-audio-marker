import Foundation

/// An operation to perform on a single audio file.
public enum BatchOperation: Sendable, Hashable {
    /// Read metadata and chapters from the file.
    case read
    /// Write the given metadata and chapters to the file.
    case write(AudioFileInfo)
    /// Strip all metadata and chapters.
    case strip
    /// Export chapters to a text format, saving to the given URL.
    case exportChapters(format: ExportFormat, outputURL: URL)
    /// Import chapters from a text string and write to the file.
    case importChapters(String, format: ExportFormat)
}
