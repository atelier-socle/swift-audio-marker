import Foundation

/// A file writer that supports offset-based and streaming writes.
public struct FileWriter: Sendable {

    /// The URL of the file being written.
    public let url: URL

    private let handle: SendableFileHandle

    /// Creates or opens a file for writing.
    /// - Parameter url: File URL to write to. Created if it doesn't exist.
    /// - Throws: ``StreamingError/cannotOpenFile(_:)``
    public init(url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forWritingTo: url)
        } catch {
            throw StreamingError.cannotOpenFile(url.path)
        }
        self.url = url
        self.handle = SendableFileHandle(fileHandle: fileHandle)
    }

    /// Writes data at the current end of file (append).
    /// - Parameter data: The data to write.
    /// - Throws: ``StreamingError/writeFailed(_:)``
    public func write(_ data: Data) throws {
        _ = handle.fileHandle.seekToEndOfFile()
        handle.fileHandle.write(data)
    }

    /// Writes data at a specific offset.
    /// - Parameters:
    ///   - data: The data to write.
    ///   - offset: Byte offset from the start of the file.
    /// - Throws: ``StreamingError/writeFailed(_:)``
    public func write(_ data: Data, at offset: UInt64) throws {
        handle.fileHandle.seek(toFileOffset: offset)
        handle.fileHandle.write(data)
    }

    /// Copies a range of bytes from a source ``FileReader`` to this writer.
    ///
    /// Streams the data in chunks to avoid loading it all in memory.
    /// - Parameters:
    ///   - source: The source file reader.
    ///   - offset: Starting byte offset in the source.
    ///   - count: Number of bytes to copy.
    ///   - bufferSize: Chunk size for streaming. Defaults to ``StreamingConstants/defaultBufferSize``.
    /// - Throws: ``StreamingError/readFailed(_:)``, ``StreamingError/writeFailed(_:)``
    public func copyChunked(
        from source: FileReader,
        offset: UInt64,
        count: UInt64,
        bufferSize: Int = StreamingConstants.defaultBufferSize
    ) throws {
        try source.readChunked(
            from: offset, count: count, bufferSize: bufferSize
        ) { chunk, _, _ in
            self.handle.fileHandle.write(chunk)
        }
    }

    /// Truncates the file to the specified size.
    /// - Parameter size: New file size in bytes.
    /// - Throws: ``StreamingError/writeFailed(_:)``
    public func truncate(to size: UInt64) throws {
        handle.fileHandle.truncateFile(atOffset: size)
    }

    /// Flushes any buffered data to disk.
    public func synchronize() {
        handle.fileHandle.synchronizeFile()
    }

    /// Closes the file handle.
    public func close() {
        handle.fileHandle.closeFile()
    }
}
