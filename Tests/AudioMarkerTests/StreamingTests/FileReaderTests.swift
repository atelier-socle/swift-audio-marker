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
import Testing

@testable import AudioMarker

@Suite("File Reader")
struct FileReaderTests {

    // MARK: - Helpers

    private func createTempFile(content: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try content.write(to: url)
        return url
    }

    // MARK: - File Size

    @Test("Reports correct file size")
    func fileSize() throws {
        let content = Data(repeating: 0xAB, count: 1024)
        let url = try createTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }
        #expect(reader.fileSize == 1024)
    }

    // MARK: - Read at Offset

    @Test("Reads bytes at offset")
    func readAtOffset() throws {
        let content = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05])
        let url = try createTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }
        let data = try reader.read(at: 2, count: 3)
        #expect(data == Data([0x02, 0x03, 0x04]))
    }

    @Test("Reads zero bytes at any valid offset")
    func readZeroBytes() throws {
        let url = try createTempFile(content: Data([0xFF]))
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }
        let data = try reader.read(at: 0, count: 0)
        #expect(data.isEmpty)
    }

    // MARK: - Read to End

    @Test("Reads from offset to end of file")
    func readToEnd() throws {
        let content = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        let url = try createTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }
        let data = try reader.readToEnd(from: 3)
        #expect(data == Data([0x03, 0x04]))
    }

    @Test("Read to end from file end returns empty data")
    func readToEndAtEnd() throws {
        let content = Data([0x01, 0x02])
        let url = try createTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }
        let data = try reader.readToEnd(from: 2)
        #expect(data.isEmpty)
    }

    // MARK: - Chunked Reading

    @Test("Chunked read delivers all data")
    func readChunkedAll() throws {
        let content = Data(repeating: 0xCD, count: 20_000)
        let url = try createTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        var combined = Data()
        try reader.readChunked(
            from: 0, count: 20_000, bufferSize: 4_096
        ) { chunk, _, _ in
            combined.append(chunk)
        }
        #expect(combined == content)
    }

    @Test("Chunked read reports correct progress")
    func readChunkedProgress() throws {
        let content = Data(repeating: 0xAA, count: 10_000)
        let url = try createTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        var lastBytesRead: UInt64 = 0
        try reader.readChunked(
            from: 0, count: 10_000, bufferSize: 4_096
        ) { _, bytesRead, total in
            #expect(total == 10_000)
            #expect(bytesRead > lastBytesRead)
            lastBytesRead = bytesRead
        }
        #expect(lastBytesRead == 10_000)
    }

    @Test("Chunked read with exact buffer size produces one chunk")
    func readChunkedSingle() throws {
        let content = Data(repeating: 0xBB, count: 4_096)
        let url = try createTempFile(content: content)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        var chunkCount = 0
        try reader.readChunked(
            from: 0, count: 4_096, bufferSize: 4_096
        ) { _, _, _ in
            chunkCount += 1
        }
        #expect(chunkCount == 1)
    }

    // MARK: - Errors

    @Test("Opening non-existent file throws fileNotFound")
    func fileNotFound() {
        let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")
        #expect(throws: StreamingError.self) {
            _ = try FileReader(url: url)
        }
    }

    @Test("Reading out of bounds throws outOfBounds")
    func outOfBounds() throws {
        let url = try createTempFile(content: Data([0x01, 0x02]))
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }
        #expect(throws: StreamingError.self) {
            _ = try reader.read(at: 0, count: 10)
        }
    }

    @Test("Chunked read with too small buffer throws invalidBufferSize")
    func bufferTooSmall() throws {
        let url = try createTempFile(content: Data(repeating: 0x00, count: 100))
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }
        #expect(throws: StreamingError.self) {
            try reader.readChunked(
                from: 0, count: 100, bufferSize: 1_000
            ) { _, _, _ in }
        }
    }

    @Test("Chunked read with too large buffer throws invalidBufferSize")
    func bufferTooLarge() throws {
        let url = try createTempFile(content: Data(repeating: 0x00, count: 100))
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }
        #expect(throws: StreamingError.self) {
            try reader.readChunked(
                from: 0, count: 100, bufferSize: 2_000_000
            ) { _, _, _ in }
        }
    }

    @Test("readToEnd past file size throws outOfBounds")
    func readToEndOutOfBounds() throws {
        let url = try createTempFile(content: Data([0x01]))
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }
        #expect(throws: StreamingError.self) {
            _ = try reader.readToEnd(from: 100)
        }
    }
}
