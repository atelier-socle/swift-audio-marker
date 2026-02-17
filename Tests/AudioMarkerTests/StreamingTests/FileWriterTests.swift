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

@Suite("File Writer")
struct FileWriterTests {

    // MARK: - Helpers

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    private func createTempFile(content: Data) throws -> URL {
        let url = tempURL()
        try content.write(to: url)
        return url
    }

    private func readFile(at url: URL) throws -> Data {
        let reader = try FileReader(url: url)
        defer { reader.close() }
        return try reader.readToEnd(from: 0)
    }

    // MARK: - File Creation

    @Test("Creates file when it does not exist")
    func createNewFile() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try FileWriter(url: url)
        try writer.write(Data([0x01, 0x02]))
        writer.close()

        #expect(FileManager.default.fileExists(atPath: url.path))
        let data = try readFile(at: url)
        #expect(data == Data([0x01, 0x02]))
    }

    // MARK: - Write (Append)

    @Test("Write appends data to end of file")
    func writeAppend() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try FileWriter(url: url)
        try writer.write(Data([0xAA, 0xBB]))
        try writer.write(Data([0xCC, 0xDD]))
        writer.close()

        let data = try readFile(at: url)
        #expect(data == Data([0xAA, 0xBB, 0xCC, 0xDD]))
    }

    // MARK: - Write at Offset

    @Test("Write at offset overwrites bytes")
    func writeAtOffset() throws {
        let url = try createTempFile(content: Data([0x01, 0x02, 0x03, 0x04]))
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try FileWriter(url: url)
        try writer.write(Data([0xFF, 0xFE]), at: 1)
        writer.close()

        let data = try readFile(at: url)
        #expect(data == Data([0x01, 0xFF, 0xFE, 0x04]))
    }

    // MARK: - Copy Chunked

    @Test("copyChunked copies data identically")
    func copyChunked() throws {
        let sourceContent = Data(repeating: 0xAB, count: 10_000)
        let sourceURL = try createTempFile(content: sourceContent)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let destURL = tempURL()
        defer { try? FileManager.default.removeItem(at: destURL) }

        let reader = try FileReader(url: sourceURL)
        defer { reader.close() }
        let writer = try FileWriter(url: destURL)
        defer { writer.close() }

        try writer.copyChunked(
            from: reader, offset: 0, count: reader.fileSize, bufferSize: 4_096
        )

        let result = try readFile(at: destURL)
        #expect(result == sourceContent)
    }

    @Test("copyChunked copies partial range")
    func copyChunkedPartial() throws {
        let sourceContent = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05])
        let sourceURL = try createTempFile(content: sourceContent)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let destURL = tempURL()
        defer { try? FileManager.default.removeItem(at: destURL) }

        let reader = try FileReader(url: sourceURL)
        defer { reader.close() }
        let writer = try FileWriter(url: destURL)
        defer { writer.close() }

        try writer.copyChunked(from: reader, offset: 2, count: 3)

        let result = try readFile(at: destURL)
        #expect(result == Data([0x02, 0x03, 0x04]))
    }

    // MARK: - Truncate

    @Test("Truncate reduces file size")
    func truncate() throws {
        let url = try createTempFile(content: Data(repeating: 0xFF, count: 1000))
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try FileWriter(url: url)
        try writer.truncate(to: 500)
        writer.close()

        let reader = try FileReader(url: url)
        defer { reader.close() }
        #expect(reader.fileSize == 500)
    }

    // MARK: - Round-trip

    @Test("Round-trip write then read produces identical data")
    func roundTrip() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let original = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F])  // "Hello"
        let writer = try FileWriter(url: url)
        try writer.write(original)
        writer.close()

        let data = try readFile(at: url)
        #expect(data == original)
    }
}
