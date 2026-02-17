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

@Suite("MP4Reader")
struct MP4ReaderTests {

    let mp4Reader = MP4Reader()

    // MARK: - Full Read

    @Test("Reads complete AudioFileInfo from MP4 file")
    func readFullInfo() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [
                MP4TestHelper.buildILSTTextItem(type: "\u{00A9}nam", text: "Test Song"),
                MP4TestHelper.buildILSTTextItem(type: "\u{00A9}ART", text: "Test Artist"),
                MP4TestHelper.buildILSTTextItem(type: "\u{00A9}alb", text: "Test Album")
            ]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try mp4Reader.read(from: url)
        #expect(info.metadata.title == "Test Song")
        #expect(info.metadata.artist == "Test Artist")
        #expect(info.metadata.album == "Test Album")
        let duration = try #require(info.duration)
        #expect(duration.timeInterval == 10.0)
    }

    @Test("Reads metadata and chapters together")
    func readMetadataAndChapters() throws {
        // Build file with both metadata and chapters.
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let titleItem = MP4TestHelper.buildILSTTextItem(type: "\u{00A9}nam", text: "Podcast")
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: [titleItem])
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let chpl = MP4TestHelper.buildChplAtom(
            chapters: [
                (startTime100ns: 0, title: "Intro"),
                (startTime100ns: 300_000_000, title: "Main")
            ]
        )
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta, chpl])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, udta])

        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moov)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try mp4Reader.read(from: url)
        #expect(info.metadata.title == "Podcast")
        #expect(info.chapters.count == 2)
        #expect(info.chapters[0].title == "Intro")
        #expect(info.chapters[1].title == "Main")
    }

    // MARK: - readAtoms

    @Test("readAtoms returns raw atom tree")
    func readAtoms() throws {
        let data = MP4TestHelper.buildMinimalMP4()
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let atoms = try mp4Reader.readAtoms(from: url)
        #expect(atoms.count == 2)  // ftyp + moov
        #expect(atoms[0].type == "ftyp")
        #expect(atoms[1].type == "moov")
    }

    // MARK: - File Type Validation

    @Test("Accepts M4A major brand")
    func acceptsM4A() throws {
        let data = MP4TestHelper.buildMinimalMP4(majorBrand: "M4A ")
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try mp4Reader.read(from: url)
        #expect(info.duration != nil)
    }

    @Test("Accepts M4B major brand")
    func acceptsM4B() throws {
        let data = MP4TestHelper.buildMinimalMP4(majorBrand: "M4B ")
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try mp4Reader.read(from: url)
        #expect(info.duration != nil)
    }

    @Test("Accepts isom major brand")
    func acceptsIsom() throws {
        let data = MP4TestHelper.buildMinimalMP4(majorBrand: "isom")
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try mp4Reader.read(from: url)
        #expect(info.duration != nil)
    }

    @Test("Accepts file with compatible brand")
    func acceptsCompatibleBrand() throws {
        let ftyp = MP4TestHelper.buildFtypWithCompatible(
            majorBrand: "unkn", compatibleBrands: ["M4A "]
        )
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd])
        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moov)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try mp4Reader.read(from: url)
        #expect(info.duration != nil)
    }

    @Test("Rejects unsupported major brand without compatible brands")
    func rejectsUnsupportedBrand() throws {
        let data = MP4TestHelper.buildMinimalMP4(majorBrand: "ZZZZ")
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: MP4Error.self) {
            _ = try mp4Reader.read(from: url)
        }
    }

    @Test("Rejects file without ftyp atom")
    func rejectsMissingFtyp() throws {
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd])
        let url = try MP4TestHelper.createTempFile(data: moov)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: MP4Error.self) {
            _ = try mp4Reader.read(from: url)
        }
    }

    // MARK: - Error Cases

    @Test("Throws for file too small")
    func fileTooSmall() throws {
        let url = try MP4TestHelper.createTempFile(data: Data(repeating: 0x00, count: 4))
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: MP4Error.self) {
            _ = try mp4Reader.read(from: url)
        }
    }

    @Test("Throws for truncated ftyp payload")
    func truncatedFtyp() throws {
        // ftyp atom with only 2 bytes of data (needs >= 4 for major brand).
        let ftyp = MP4TestHelper.buildAtom(type: "ftyp", data: Data(repeating: 0x00, count: 2))
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd])
        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moov)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: MP4Error.self) {
            _ = try mp4Reader.read(from: url)
        }
    }

    @Test("Throws for non-existent file")
    func nonExistentFile() {
        let url = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).m4a")
        #expect(throws: StreamingError.self) {
            _ = try mp4Reader.read(from: url)
        }
    }

    // MARK: - Empty Metadata

    @Test("Returns empty metadata for file without ilst")
    func emptyMetadata() throws {
        let data = MP4TestHelper.buildMinimalMP4()
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try mp4Reader.read(from: url)
        #expect(info.metadata.title == nil)
        #expect(info.metadata.artist == nil)
        #expect(info.chapters.isEmpty)
    }
}
