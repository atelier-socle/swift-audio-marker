import Foundation
import Testing

@testable import AudioMarker

@Suite("MP4 Moov Builder")
struct MP4MoovBuilderTests {

    let moovBuilder = MP4MoovBuilder()

    // MARK: - Rebuild

    @Test("Rebuilds moov with new metadata")
    func rebuildWithMetadata() throws {
        let originalFile = MP4TestHelper.buildMinimalMP4()
        let url = try MP4TestHelper.createTempFile(data: originalFile)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)
        let moov = try #require(atoms.first { $0.type == "moov" })

        var metadata = AudioMetadata()
        metadata.title = "New Title"

        let newMoov = try moovBuilder.rebuildMoov(
            from: moov, reader: reader,
            metadata: metadata, chapters: ChapterList())

        // Verify the new moov contains udta.
        let moovURL = try MP4TestHelper.createTempFile(data: newMoov)
        defer { try? FileManager.default.removeItem(at: moovURL) }

        let moovReader = try FileReader(url: moovURL)
        defer { moovReader.close() }

        let newAtoms = try parser.parseAtoms(from: moovReader)
        #expect(newAtoms.count == 1)
        #expect(newAtoms[0].type == "moov")
        #expect(newAtoms[0].child(ofType: "mvhd") != nil)
        #expect(newAtoms[0].child(ofType: "udta") != nil)
    }

    @Test("Preserves existing trak atoms")
    func preservesTrak() throws {
        let fileData = MP4TestHelper.buildMP4WithQuickTimeChapters(titles: ["Ch1", "Ch2"])
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)
        let moov = try #require(atoms.first { $0.type == "moov" })

        let newMoov = try moovBuilder.rebuildMoov(
            from: moov, reader: reader,
            metadata: AudioMetadata(title: "New"), chapters: ChapterList())

        let moovURL = try MP4TestHelper.createTempFile(data: newMoov)
        defer { try? FileManager.default.removeItem(at: moovURL) }

        let moovReader = try FileReader(url: moovURL)
        defer { moovReader.close() }

        let newAtoms = try parser.parseAtoms(from: moovReader)
        let trakAtoms = newAtoms[0].children(ofType: "trak")
        #expect(!trakAtoms.isEmpty)
    }

    @Test("Adds udta when moov has none")
    func addsUdta() throws {
        let originalFile = MP4TestHelper.buildMinimalMP4()
        let url = try MP4TestHelper.createTempFile(data: originalFile)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)
        let moov = try #require(atoms.first { $0.type == "moov" })

        // Verify no udta in original.
        #expect(moov.child(ofType: "udta") == nil)

        var metadata = AudioMetadata()
        metadata.title = "Added"

        let newMoov = try moovBuilder.rebuildMoov(
            from: moov, reader: reader,
            metadata: metadata, chapters: ChapterList())

        let moovURL = try MP4TestHelper.createTempFile(data: newMoov)
        defer { try? FileManager.default.removeItem(at: moovURL) }

        let moovReader = try FileReader(url: moovURL)
        defer { moovReader.close() }

        let newAtoms = try parser.parseAtoms(from: moovReader)
        #expect(newAtoms[0].child(ofType: "udta") != nil)
    }

    // MARK: - Offset Adjustment

    @Test("Adjusts stco offsets by positive delta")
    func adjustStcoPositive() throws {
        let stcoData = MP4TestHelper.buildStcoAtom(offsets: [100, 200, 300])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [stcoData])

        let adjusted = try moovBuilder.adjustChunkOffsets(in: moov, delta: 50)

        // Parse the adjusted moov to verify offsets.
        let url = try MP4TestHelper.createTempFile(data: adjusted)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)
        let stco = try #require(atoms[0].child(ofType: "stco"))
        let offsets = try readStcoOffsets(stco, reader: reader)

        #expect(offsets == [150, 250, 350])
    }

    @Test("Adjusts stco offsets by negative delta")
    func adjustStcoNegative() throws {
        let stcoData = MP4TestHelper.buildStcoAtom(offsets: [100, 200, 300])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [stcoData])

        let adjusted = try moovBuilder.adjustChunkOffsets(in: moov, delta: -30)

        let url = try MP4TestHelper.createTempFile(data: adjusted)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)
        let stco = try #require(atoms[0].child(ofType: "stco"))
        let offsets = try readStcoOffsets(stco, reader: reader)

        #expect(offsets == [70, 170, 270])
    }

    @Test("Zero delta returns unchanged data")
    func zeroDelta() throws {
        let stcoData = MP4TestHelper.buildStcoAtom(offsets: [100, 200])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [stcoData])

        let adjusted = try moovBuilder.adjustChunkOffsets(in: moov, delta: 0)
        #expect(adjusted == moov)
    }

    // MARK: - CO64 Offset Adjustment

    @Test("Adjusts co64 offsets by positive delta")
    func adjustCo64Positive() throws {
        let co64Data = MP4TestHelper.buildCo64Atom(offsets: [1000, 2000, 3000])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [co64Data])

        let adjusted = try moovBuilder.adjustChunkOffsets(in: moov, delta: 100)

        let url = try MP4TestHelper.createTempFile(data: adjusted)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)
        let co64 = try #require(atoms[0].child(ofType: "co64"))
        let offsets = try readCo64Offsets(co64, reader: reader)

        #expect(offsets == [1100, 2100, 3100])
    }

    @Test("Adjusts co64 offsets by negative delta")
    func adjustCo64Negative() throws {
        let co64Data = MP4TestHelper.buildCo64Atom(offsets: [1000, 2000])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [co64Data])

        let adjusted = try moovBuilder.adjustChunkOffsets(in: moov, delta: -200)

        let url = try MP4TestHelper.createTempFile(data: adjusted)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)
        let co64 = try #require(atoms[0].child(ofType: "co64"))
        let offsets = try readCo64Offsets(co64, reader: reader)

        #expect(offsets == [800, 1800])
    }

    @Test("Adjusts both stco and co64 in same moov")
    func adjustMixedOffsets() throws {
        let stcoData = MP4TestHelper.buildStcoAtom(offsets: [100])
        let co64Data = MP4TestHelper.buildCo64Atom(offsets: [5000])
        let moov = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [stcoData, co64Data])

        let adjusted = try moovBuilder.adjustChunkOffsets(in: moov, delta: 50)

        let url = try MP4TestHelper.createTempFile(data: adjusted)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)
        let stco = try #require(atoms[0].child(ofType: "stco"))
        let stcoOffsets = try readStcoOffsets(stco, reader: reader)
        #expect(stcoOffsets == [150])

        let co64 = try #require(atoms[0].child(ofType: "co64"))
        let co64Offsets = try readCo64Offsets(co64, reader: reader)
        #expect(co64Offsets == [5050])
    }

    // MARK: - Test Helpers

    /// Reads UInt32 offsets from a parsed stco atom.
    private func readStcoOffsets(_ stco: MP4Atom, reader: FileReader) throws -> [UInt32] {
        let data = try reader.read(at: stco.dataOffset, count: Int(stco.dataSize))
        var binaryReader = BinaryReader(data: data)
        try binaryReader.skip(4)  // version + flags
        let count = try binaryReader.readUInt32()
        var offsets: [UInt32] = []
        for _ in 0..<count {
            offsets.append(try binaryReader.readUInt32())
        }
        return offsets
    }

    /// Reads UInt64 offsets from a parsed co64 atom.
    private func readCo64Offsets(_ co64: MP4Atom, reader: FileReader) throws -> [UInt64] {
        let data = try reader.read(at: co64.dataOffset, count: Int(co64.dataSize))
        var binaryReader = BinaryReader(data: data)
        try binaryReader.skip(4)  // version + flags
        let count = try binaryReader.readUInt32()
        var offsets: [UInt64] = []
        for _ in 0..<count {
            offsets.append(try binaryReader.readUInt64())
        }
        return offsets
    }
}
