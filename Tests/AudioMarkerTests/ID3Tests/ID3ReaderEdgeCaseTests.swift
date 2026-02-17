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

@Suite("ID3 Reader Edge Cases")
struct ID3ReaderEdgeCaseTests {

    // MARK: - Helpers

    private func createTempFile(tagData: Data) throws -> URL {
        try ID3TestHelper.createTempFile(tagData: tagData)
    }

    // MARK: - Track Number Parsing

    @Test("Track number without total")
    func trackNumberSimple() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TRCK", text: "7")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.trackNumber == 7)
    }

    @Test("Track number with total (3/12)")
    func trackNumberWithTotal() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TRCK", text: "3/12")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.trackNumber == 3)
    }

    // MARK: - Disc Number Parsing

    @Test("Disc number without total")
    func discNumberSimple() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TPOS", text: "1")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.discNumber == 1)
    }

    @Test("Disc number with total (1/2)")
    func discNumberWithTotal() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TPOS", text: "1/2")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.discNumber == 1)
    }

    // MARK: - Year Parsing

    @Test("TYER year parsing (v2.3)")
    func yearV23() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TYER", text: "2024")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.year == 2024)
    }

    @Test("TDRC year parsing (v2.4, full ISO 8601)")
    func yearV24ISO() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_4,
            frames: [
                ID3TestHelper.buildTextFrame(
                    id: "TDRC", text: "2024-01-15",
                    encoding: .utf8, version: .v2_4
                )
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.year == 2024)
    }

    // MARK: - No ID3 Tag

    @Test("File without ID3 tag throws noTag")
    func noTag() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        try Data(repeating: 0xFF, count: 256).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        #expect(throws: ID3Error.self) {
            _ = try reader.read(from: url)
        }
    }

    // MARK: - Unknown Frames

    @Test("Unknown frames preserved as .unknown")
    func unknownFrames() throws {
        let unknownContent = Data([0x01, 0x02, 0x03])
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildRawFrame(id: "ZZZZ", content: unknownContent)
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let (_, frames) = try reader.readRawFrames(from: url)
        #expect(frames.count == 1)
        #expect(frames[0] == .unknown(id: "ZZZZ", data: unknownContent))
    }

    // MARK: - Extended Header

    @Test("Extended header is skipped correctly (v2.3)")
    func extendedHeaderV23() throws {
        var extHeader = BinaryWriter()
        extHeader.writeUInt32(6)
        extHeader.writeRepeating(0x00, count: 6)

        let tag = ID3TestHelper.buildTagWithFlags(
            version: .v2_3, flags: 0x40,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TIT2", text: "After ExtHeader")
            ],
            extendedHeader: extHeader.data
        )
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.title == "After ExtHeader")
    }

    @Test("Extended header is skipped correctly (v2.4)")
    func extendedHeaderV24() throws {
        var extHeader = BinaryWriter()
        extHeader.writeSyncsafeUInt32(10)
        extHeader.writeUInt8(1)
        extHeader.writeUInt8(0x00)
        extHeader.writeRepeating(0x00, count: 4)

        let tag = ID3TestHelper.buildTagWithFlags(
            version: .v2_4, flags: 0x40,
            frames: [
                ID3TestHelper.buildTextFrame(
                    id: "TIT2", text: "V4 ExtHeader",
                    encoding: .utf8, version: .v2_4
                )
            ],
            extendedHeader: extHeader.data
        )
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.title == "V4 ExtHeader")
    }
}
