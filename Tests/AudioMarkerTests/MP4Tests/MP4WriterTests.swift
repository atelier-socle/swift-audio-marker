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

    // MARK: - Error Cases

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

// MARK: - Test File Builders

extension MP4WriterTests {

    /// Creates a test MP4 with ftyp + moov + mdat.
    private func createTestMP4WithMdat(
        mdatContent: Data = Data(repeating: 0xFF, count: 64)
    ) throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)

        // Build stco with a placeholder offset pointing into mdat.
        let stco = MP4TestHelper.buildStcoAtom(offsets: [0])
        let stsz = MP4TestHelper.buildStszAtom(defaultSize: UInt32(mdatContent.count), sizes: [])
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 441_000)])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 44100)
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trak])

        // Build mdat.
        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        // Calculate actual stco offset.
        let mdatDataOffset = UInt32(ftyp.count + moov.count + 8)

        // Rebuild with correct offset.
        let stcoFixed = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stblFixed = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = MP4TestHelper.buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trakFixed])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        file.append(mdatWriter.data)

        return try MP4TestHelper.createTempFile(data: file)
    }

    /// Creates a test MP4 with metadata and mdat.
    private func createTestMP4WithMetadataAndMdat() throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)

        let mdatContent = Data(repeating: 0xFF, count: 64)

        let titleItem = MP4TestHelper.buildILSTTextItem(
            type: "\u{00A9}nam", text: "Original Title")
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: [titleItem])
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])

        let stco = MP4TestHelper.buildStcoAtom(offsets: [0])
        let stsz = MP4TestHelper.buildStszAtom(defaultSize: UInt32(mdatContent.count), sizes: [])
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 441_000)])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 44100)
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, trak, udta])

        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        // Calculate actual stco offset.
        let mdatDataOffset = UInt32(ftyp.count + moov.count + 8)

        // Rebuild with correct offset.
        let stcoFixed = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stblFixed = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = MP4TestHelper.buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, trakFixed, udta])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        file.append(mdatWriter.data)

        return try MP4TestHelper.createTempFile(data: file)
    }

    /// Creates a test MP4 with ftyp + mdat + moov layout (mdat first).
    private func createTestMP4MdatFirst() throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let mdatContent = Data(repeating: 0xAA, count: 64)

        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        // stco offset points to mdat data (after ftyp + mdat header).
        let mdatDataOffset = UInt32(ftyp.count + 8)
        let stco = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stsz = MP4TestHelper.buildStszAtom(
            defaultSize: UInt32(mdatContent.count), sizes: [])
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 441_000)])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 44100)
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trak])

        // Layout: ftyp | mdat | moov.
        var file = Data()
        file.append(ftyp)
        file.append(mdatWriter.data)
        file.append(moov)
        return try MP4TestHelper.createTempFile(data: file)
    }

    /// Creates a test MP4 with mdat-first layout and metadata.
    private func createTestMP4MdatFirstWithMetadata() throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let mdatContent = Data(repeating: 0xBB, count: 64)

        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        let titleItem = MP4TestHelper.buildILSTTextItem(
            type: "\u{00A9}nam", text: "Original")
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: [titleItem])
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])

        let mdatDataOffset = UInt32(ftyp.count + 8)
        let stco = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stsz = MP4TestHelper.buildStszAtom(
            defaultSize: UInt32(mdatContent.count), sizes: [])
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 441_000)])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 44100)
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, trak, udta])

        var file = Data()
        file.append(ftyp)
        file.append(mdatWriter.data)
        file.append(moov)
        return try MP4TestHelper.createTempFile(data: file)
    }
}
