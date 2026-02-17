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

@Suite("MP4 Writer")
struct MP4WriterTests {

    let writer = MP4Writer()
    let reader = MP4Reader()

    // MARK: - Write Metadata

    @Test("Write metadata then read back produces identical metadata")
    func writeAndReadMetadata() throws {
        let url = try createTestMP4WithMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.title = "Written Title"
        info.metadata.artist = "Written Artist"
        info.metadata.album = "Written Album"

        try writer.write(info, to: url)
        let readBack = try reader.read(from: url)

        #expect(readBack.metadata.title == "Written Title")
        #expect(readBack.metadata.artist == "Written Artist")
        #expect(readBack.metadata.album == "Written Album")
    }

    @Test("Write chapters then read back produces identical chapters")
    func writeAndReadChapters() throws {
        let url = try createTestMP4WithMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .seconds(30.0), title: "Main"),
            Chapter(start: .seconds(60.0), title: "Outro")
        ])

        try writer.write(info, to: url)
        let readBack = try reader.read(from: url)

        #expect(readBack.chapters.count == 3)
        #expect(readBack.chapters[0].title == "Intro")
        #expect(readBack.chapters[1].title == "Main")
        #expect(readBack.chapters[2].title == "Outro")
        #expect(readBack.chapters[0].start.timeInterval == 0.0)
        #expect(readBack.chapters[1].start.timeInterval == 30.0)
        #expect(readBack.chapters[2].start.timeInterval == 60.0)
    }

    @Test("Write artwork then read back preserves image data")
    func writeAndReadArtwork() throws {
        let url = try createTestMP4WithMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0xAB), count: 50))
        var info = AudioFileInfo()
        info.metadata.artwork = Artwork(data: imageData, format: .jpeg)

        try writer.write(info, to: url)
        let readBack = try reader.read(from: url)

        let artwork = try #require(readBack.metadata.artwork)
        #expect(artwork.format == .jpeg)
        #expect(artwork.data == imageData)
    }

    // MARK: - Strip Metadata

    @Test("Strip metadata removes all metadata")
    func stripMetadata() throws {
        let url = try createTestMP4WithMetadataAndMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        // Verify metadata exists before strip.
        let before = try reader.read(from: url)
        #expect(before.metadata.title == "Original Title")

        try writer.stripMetadata(from: url)
        let after = try reader.read(from: url)

        #expect(after.metadata.title == nil)
        #expect(after.metadata.artist == nil)
        #expect(after.chapters.isEmpty)
    }

    @Test("Strip metadata preserves chapters with original titles")
    func stripPreservesChapters() throws {
        let url = try createTestMP4WithMetadataChaptersAndMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        let before = try reader.read(from: url)
        #expect(before.metadata.title == "Album Title")
        #expect(before.chapters.count == 2)
        #expect(before.chapters[0].title == "First Chapter")
        #expect(before.chapters[1].title == "Second Chapter")

        try writer.stripMetadata(from: url)
        let after = try reader.read(from: url)

        // Metadata must be gone.
        #expect(after.metadata.title == nil)
        #expect(after.metadata.artist == nil)

        // Chapters must be intact with original titles.
        #expect(after.chapters.count == 2)
        #expect(after.chapters[0].title == "First Chapter")
        #expect(after.chapters[1].title == "Second Chapter")
    }

    // MARK: - Audio Data Preservation

    @Test("Write preserves mdat audio data")
    func preservesMdat() throws {
        let mdatContent = Data(repeating: 0xAB, count: 256)
        let url = try createTestMP4WithMdat(mdatContent: mdatContent)
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.title = "New Title"

        try writer.write(info, to: url)

        // Read the file and find mdat to verify content.
        let fileReader = try FileReader(url: url)
        defer { fileReader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: fileReader)
        let mdat = try #require(atoms.first { $0.type == "mdat" })
        let readMdat = try fileReader.read(at: mdat.dataOffset, count: Int(mdat.dataSize))

        #expect(readMdat == mdatContent)
    }

    // MARK: - QuickTime Text Track

    @Test("Write chapters creates QuickTime text track")
    func writeChaptersCreatesTextTrack() throws {
        let url = try createTestMP4WithMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .seconds(30.0), title: "Main"),
            Chapter(start: .seconds(60.0), title: "Outro")
        ])

        try writer.write(info, to: url)

        // Verify chapters read back correctly.
        let readBack = try reader.read(from: url)
        #expect(readBack.chapters.count == 3)
        #expect(readBack.chapters[0].title == "Intro")
        #expect(readBack.chapters[1].title == "Main")
        #expect(readBack.chapters[2].title == "Outro")

        // Verify a text track exists in the moov.
        let hasTrack = try hasTextTrackInMoov(at: url)
        #expect(hasTrack)
    }

    @Test("Write new chapters replaces existing text track")
    func writeChaptersUpdatesExistingTextTrack() throws {
        let url = try createTestMP4WithMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        // Write initial chapters.
        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "Old Chapter 1"),
            Chapter(start: .seconds(30.0), title: "Old Chapter 2")
        ])
        try writer.write(info, to: url)

        // Write new chapters.
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "New Chapter 1"),
            Chapter(start: .seconds(20.0), title: "New Chapter 2"),
            Chapter(start: .seconds(40.0), title: "New Chapter 3")
        ])
        try writer.write(info, to: url)

        // Verify new chapters are read back.
        let readBack = try reader.read(from: url)
        #expect(readBack.chapters.count == 3)
        #expect(readBack.chapters[0].title == "New Chapter 1")
        #expect(readBack.chapters[1].title == "New Chapter 2")
        #expect(readBack.chapters[2].title == "New Chapter 3")

        // Verify only one text track exists (old one was replaced).
        let textTrackCount = try countTextTracksInMoov(at: url)
        #expect(textTrackCount == 1)
    }

    @Test("Write chapters on mdat-first layout creates text track")
    func writeChaptersMdatFirst() throws {
        let url = try createTestMP4MdatFirst()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "First"),
            Chapter(start: .seconds(30.0), title: "Second")
        ])

        try writer.write(info, to: url)
        let readBack = try reader.read(from: url)

        #expect(readBack.chapters.count == 2)
        #expect(readBack.chapters[0].title == "First")
        #expect(readBack.chapters[1].title == "Second")

        let hasTrack = try hasTextTrackInMoov(at: url)
        #expect(hasTrack)
    }

    // MARK: - Round-Trip

    @Test("Full round-trip: read, modify, write, read, compare")
    func fullRoundTrip() throws {
        let url = try createTestMP4WithMetadataAndMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        // Read original.
        let original = try reader.read(from: url)
        #expect(original.metadata.title == "Original Title")

        // Modify and write.
        var modified = original
        modified.metadata.title = "Modified Title"
        modified.metadata.artist = "New Artist"
        modified.chapters = ChapterList([
            Chapter(start: .zero, title: "New Chapter")
        ])

        try writer.write(modified, to: url)

        // Read back.
        let readBack = try reader.read(from: url)
        #expect(readBack.metadata.title == "Modified Title")
        #expect(readBack.metadata.artist == "New Artist")
        #expect(readBack.chapters.count == 1)
        #expect(readBack.chapters[0].title == "New Chapter")
    }

    // MARK: - Mdat-First Layout

    @Test("Handles ftyp-mdat-moov layout")
    func mdatFirstLayout() throws {
        let url = try createTestMP4MdatFirst()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.title = "Mdat First"

        try writer.write(info, to: url)
        let readBack = try reader.read(from: url)

        #expect(readBack.metadata.title == "Mdat First")
    }

    @Test("Strip metadata on mdat-first layout")
    func stripMdatFirst() throws {
        let url = try createTestMP4MdatFirstWithMetadata()
        defer { try? FileManager.default.removeItem(at: url) }

        let before = try reader.read(from: url)
        #expect(before.metadata.title == "Original")

        try writer.stripMetadata(from: url)
        let after = try reader.read(from: url)
        #expect(after.metadata.title == nil)
    }

    // MARK: - Free Atom Gap (stco/co64 Offset Correction)

    @Test("Write with free atom between moov and mdat preserves correct stco offsets")
    func writeWithFreeAtomBetweenMoovAndMdat() throws {
        let mdatContent = Data(repeating: 0xCD, count: 128)
        let url = try createTestMP4WithFreeBeforeMdat(mdatContent: mdatContent)
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.title = "Gap Test"

        try writer.write(info, to: url)

        // Verify mdat content is preserved and stco points within mdat.
        let fileReader = try FileReader(url: url)
        defer { fileReader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: fileReader)
        let mdat = try #require(atoms.first { $0.type == "mdat" })
        let readMdat = try fileReader.read(at: mdat.dataOffset, count: Int(mdat.dataSize))
        #expect(readMdat == mdatContent)

        // Read stco offset from the output moov.
        let moov = try #require(atoms.first { $0.type == "moov" })
        let stcoOffset = try findStcoFirstOffset(in: moov, reader: fileReader)
        #expect(stcoOffset >= mdat.offset + 8)
        #expect(stcoOffset < mdat.offset + mdat.size)
    }

    @Test("Strip with free atom between moov and mdat preserves correct stco offsets")
    func stripWithFreeAtomBetweenMoovAndMdat() throws {
        let mdatContent = Data(repeating: 0xEF, count: 128)
        let url = try createTestMP4WithFreeBeforeMdatAndMetadata(mdatContent: mdatContent)
        defer { try? FileManager.default.removeItem(at: url) }

        try writer.stripMetadata(from: url)

        let fileReader = try FileReader(url: url)
        defer { fileReader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: fileReader)
        let mdat = try #require(atoms.first { $0.type == "mdat" })
        let readMdat = try fileReader.read(at: mdat.dataOffset, count: Int(mdat.dataSize))
        #expect(readMdat == mdatContent)

        let moov = try #require(atoms.first { $0.type == "moov" })
        let stcoOffset = try findStcoFirstOffset(in: moov, reader: fileReader)
        #expect(stcoOffset >= mdat.offset + 8)
        #expect(stcoOffset < mdat.offset + mdat.size)
    }

}

// MARK: - Chapter URLs

extension MP4WriterTests {

    @Test("Round-trip chapter URLs")
    func roundTripChapterURLs() throws {
        let url = try createTestMP4WithMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "Intro",
                url: URL(string: "https://example.com/intro")),
            Chapter(
                start: .seconds(30.0), title: "Main",
                url: URL(string: "https://example.com/main")),
            Chapter(start: .seconds(60.0), title: "Outro")
        ])

        try writer.write(info, to: url)
        let readBack = try reader.read(from: url)

        #expect(readBack.chapters.count == 3)
        #expect(readBack.chapters[0].url?.absoluteString == "https://example.com/intro")
        #expect(readBack.chapters[1].url?.absoluteString == "https://example.com/main")
        #expect(readBack.chapters[2].url == nil)
    }
}

// MARK: - Chapter Artwork

extension MP4WriterTests {

    @Test("Round-trip chapter artwork")
    func roundTripChapterArtwork() throws {
        let url = try createTestMP4WithMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        let jpegData = MP4TestHelper.buildMinimalJPEG(size: 100)
        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "With Art",
                artwork: Artwork(data: jpegData, format: .jpeg)),
            Chapter(
                start: .seconds(30.0), title: "With Art 2",
                artwork: Artwork(data: jpegData, format: .jpeg))
        ])

        try writer.write(info, to: url)
        let readBack = try reader.read(from: url)

        #expect(readBack.chapters.count == 2)
        #expect(readBack.chapters[0].artwork?.format == .jpeg)
        #expect(readBack.chapters[0].artwork?.data == jpegData)
        #expect(readBack.chapters[1].artwork?.format == .jpeg)
    }

    @Test("Round-trip chapter URLs and artwork together")
    func roundTripChapterURLsAndArtwork() throws {
        let url = try createTestMP4WithMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        let jpegData = MP4TestHelper.buildMinimalJPEG(size: 80)
        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "Intro",
                url: URL(string: "https://example.com"),
                artwork: Artwork(data: jpegData, format: .jpeg)),
            Chapter(
                start: .seconds(30.0), title: "Main",
                url: URL(string: "https://example.com/2"),
                artwork: Artwork(data: jpegData, format: .jpeg))
        ])

        try writer.write(info, to: url)
        let readBack = try reader.read(from: url)

        #expect(readBack.chapters.count == 2)
        #expect(readBack.chapters[0].url?.absoluteString == "https://example.com")
        #expect(readBack.chapters[0].artwork?.format == .jpeg)
        #expect(readBack.chapters[1].url?.absoluteString == "https://example.com/2")
        #expect(readBack.chapters[1].artwork?.format == .jpeg)
    }

    @Test("tref/chap contains multiple track IDs when artwork present")
    func trefChapContainsMultipleTrackIDs() throws {
        let url = try createTestMP4WithMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        let jpegData = MP4TestHelper.buildMinimalJPEG()
        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(
                start: .zero, title: "Ch1",
                artwork: Artwork(data: jpegData, format: .jpeg))
        ])

        try writer.write(info, to: url)

        // Parse the output file and check tref/chap.
        let fileReader = try FileReader(url: url)
        defer { fileReader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: fileReader)
        let moov = try #require(atoms.first { $0.type == "moov" })

        // Find audio track's tref/chap.
        var chapIDs: [UInt32] = []
        for trak in moov.children(ofType: "trak") {
            if let hdlr = trak.find(path: "mdia.hdlr"),
                let data = try? fileReader.read(at: hdlr.dataOffset, count: 12),
                String(data: data[8..<12], encoding: .isoLatin1) == "soun",
                let tref = trak.child(ofType: "tref"),
                let chap = tref.child(ofType: "chap")
            {
                let count = Int(chap.dataSize) / 4
                let chapData = try fileReader.read(at: chap.dataOffset, count: count * 4)
                var binaryReader = BinaryReader(data: chapData)
                for _ in 0..<count {
                    chapIDs.append(try binaryReader.readUInt32())
                }
            }
        }

        // Should have 2 IDs: text track and video track.
        #expect(chapIDs.count == 2)
    }
}

// MARK: - Error Cases

extension MP4WriterTests {

    @Test("Throws for file without moov")
    func missingMoov() throws {
        let ftyp = MP4TestHelper.buildFtyp()
        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(24)
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeRepeating(0xFF, count: 16)

        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(mdatWriter.data)

        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: MP4Error.self) {
            _ = try writer.write(AudioFileInfo(), to: url)
        }
    }

    @Test("Throws for file without mdat")
    func missingMdat() throws {
        let data = MP4TestHelper.buildMinimalMP4()
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: MP4Error.self) {
            _ = try writer.write(AudioFileInfo(), to: url)
        }
    }
}

// MARK: - Text Track Replacement & stsd

extension MP4WriterTests {

    @Test("Write chapters replaces existing sbtl text track")
    func writeChaptersReplacesSubtitleTrack() throws {
        let url = try createTestMP4WithSbtlTrack()
        defer { try? FileManager.default.removeItem(at: url) }

        // Verify the sbtl track exists before writing.
        let beforeCount = try countTextOrSbtlTracksInMoov(at: url)
        #expect(beforeCount == 1)

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "New Ch1"),
            Chapter(start: .seconds(30.0), title: "New Ch2")
        ])

        try writer.write(info, to: url)

        // Verify only one text track exists (sbtl removed, text added).
        let afterCount = try countTextOrSbtlTracksInMoov(at: url)
        #expect(afterCount == 1)

        // Verify chapters read back correctly.
        let readBack = try reader.read(from: url)
        #expect(readBack.chapters.count == 2)
        #expect(readBack.chapters[0].title == "New Ch1")
        #expect(readBack.chapters[1].title == "New Ch2")
    }

    @Test("Text track stsd has correct size (no overread)")
    func textTrackStsdCorrectSize() throws {
        let url = try createTestMP4WithMdat()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.chapters = ChapterList([
            Chapter(start: .zero, title: "Ch1")
        ])

        try writer.write(info, to: url)

        // Parse the file and find the text track's stsd.
        let fileReader = try FileReader(url: url)
        defer { fileReader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: fileReader)
        let moov = try #require(atoms.first { $0.type == "moov" })

        // Find the text track.
        var textTrack: MP4Atom?
        for trak in moov.children(ofType: "trak") {
            if let hdlr = trak.find(path: "mdia.hdlr"),
                let data = try? fileReader.read(at: hdlr.dataOffset, count: 12),
                String(data: data[8..<12], encoding: .isoLatin1) == "text"
            {
                textTrack = trak
                break
            }
        }
        let track = try #require(textTrack)

        // Read the stsd atom.
        let stsd = try #require(track.find(path: "mdia.minf.stbl.stsd"))
        let stsdData = try fileReader.read(
            at: stsd.dataOffset, count: Int(stsd.dataSize))

        // After version+flags(4) + entry_count(4), the text description starts.
        // The first 4 bytes of the description are its declared size.
        let descSize =
            UInt32(stsdData[8]) << 24
            | UInt32(stsdData[9]) << 16
            | UInt32(stsdData[10]) << 8
            | UInt32(stsdData[11])

        // Declared size should equal actual remaining bytes from description start.
        let actualDescBytes = stsdData.count - 8
        #expect(descSize == UInt32(actualDescBytes))
        #expect(descSize == 59)
    }
}
