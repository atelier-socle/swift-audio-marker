// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation

// MARK: - Internal FileHandle Wrapper

/// Internal wrapper that enables `FileHandle` to be held in `Sendable` types.
///
/// **Thread-safety justification**: `FileHandle` is a Foundation reference type
/// not marked `Sendable`. This minimal wrapper enables `FileReader` and
/// `FileWriter` to conform to `Sendable`. Concurrent access to the same
/// underlying file handle requires external synchronization by the caller.
internal struct SendableFileHandle: @unchecked Sendable {
    let fileHandle: FileHandle
}

// MARK: - FileReader

/// A file reader that supports offset-based and chunk-based reading
/// without loading the entire file into memory.
public struct FileReader: Sendable {

    /// The URL of the file being read.
    public let url: URL

    /// The total size of the file in bytes.
    public let fileSize: UInt64

    private let handle: SendableFileHandle

    /// Opens a file for reading.
    /// - Parameter url: File URL to read.
    /// - Throws: ``StreamingError/fileNotFound(_:)`` if the file doesn't exist,
    ///           ``StreamingError/cannotOpenFile(_:)`` if the file can't be opened.
    public init(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StreamingError.fileNotFound(url.path)
        }
        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forReadingFrom: url)
        } catch {
            throw StreamingError.cannotOpenFile(url.path)
        }
        self.url = url
        self.handle = SendableFileHandle(fileHandle: fileHandle)
        self.fileSize = fileHandle.seekToEndOfFile()
    }

    /// Reads a specific number of bytes starting at the given offset.
    /// - Parameters:
    ///   - offset: Byte offset from the start of the file.
    ///   - count: Number of bytes to read.
    /// - Returns: The read data.
    /// - Throws: ``StreamingError/outOfBounds(offset:fileSize:)``,
    ///           ``StreamingError/readFailed(_:)``
    public func read(at offset: UInt64, count: Int) throws -> Data {
        guard offset <= fileSize, UInt64(count) <= fileSize - offset else {
            throw StreamingError.outOfBounds(offset: offset, fileSize: fileSize)
        }
        handle.fileHandle.seek(toFileOffset: offset)
        let data = handle.fileHandle.readData(ofLength: count)
        guard data.count == count else {
            throw StreamingError.readFailed(
                "Expected \(count) bytes at offset \(offset), got \(data.count)."
            )
        }
        return data
    }

    /// Reads all data from offset to end of file.
    ///
    /// - Warning: Use only for metadata sections known to be small.
    ///   Never use for audio data.
    /// - Parameter offset: Byte offset from the start of the file.
    /// - Returns: The read data.
    /// - Throws: ``StreamingError/outOfBounds(offset:fileSize:)``
    public func readToEnd(from offset: UInt64) throws -> Data {
        guard offset <= fileSize else {
            throw StreamingError.outOfBounds(offset: offset, fileSize: fileSize)
        }
        handle.fileHandle.seek(toFileOffset: offset)
        return handle.fileHandle.readDataToEndOfFile()
    }

    /// Reads the file in chunks, calling the handler for each chunk.
    /// - Parameters:
    ///   - offset: Starting byte offset.
    ///   - count: Total number of bytes to read.
    ///   - bufferSize: Size of each chunk. Defaults to ``StreamingConstants/defaultBufferSize``.
    ///   - handler: Closure called for each chunk with (data, bytesReadSoFar, totalBytes).
    /// - Throws: ``StreamingError/outOfBounds(offset:fileSize:)``,
    ///           ``StreamingError/invalidBufferSize(_:)``,
    ///           ``StreamingError/readFailed(_:)``
    public func readChunked(
        from offset: UInt64,
        count: UInt64,
        bufferSize: Int = StreamingConstants.defaultBufferSize,
        handler: (Data, UInt64, UInt64) throws -> Void
    ) throws {
        guard bufferSize >= StreamingConstants.minimumBufferSize,
            bufferSize <= StreamingConstants.maximumBufferSize
        else {
            throw StreamingError.invalidBufferSize(bufferSize)
        }
        guard offset <= fileSize, count <= fileSize - offset else {
            throw StreamingError.outOfBounds(offset: offset, fileSize: fileSize)
        }

        handle.fileHandle.seek(toFileOffset: offset)
        var bytesRead: UInt64 = 0

        while bytesRead < count {
            let remaining = count - bytesRead
            let chunkSize = Int(min(UInt64(bufferSize), remaining))
            let data = handle.fileHandle.readData(ofLength: chunkSize)
            guard !data.isEmpty else {
                throw StreamingError.readFailed(
                    "Unexpected end of file at offset \(offset + bytesRead)."
                )
            }
            bytesRead += UInt64(data.count)
            try handler(data, bytesRead, count)
        }
    }

    /// Closes the file handle.
    public func close() {
        handle.fileHandle.closeFile()
    }
}
