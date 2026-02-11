import Foundation
import Testing

@testable import AudioMarker

@Suite("MP4AtomParser")
struct MP4AtomParserTests {

    let parser = MP4AtomParser()

    // MARK: - Basic Parsing

    @Test("Parses a single leaf atom")
    func parseSingleAtom() throws {
        let data = MP4TestHelper.buildAtom(type: "ftyp", data: Data(repeating: 0x41, count: 4))
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parser.parseAtoms(from: reader)
        #expect(atoms.count == 1)
        #expect(atoms[0].type == "ftyp")
        #expect(atoms[0].size == 12)
        #expect(atoms[0].offset == 0)
        #expect(atoms[0].dataOffset == 8)
        #expect(atoms[0].children.isEmpty)
    }

    @Test("Parses multiple top-level atoms")
    func parseMultipleAtoms() throws {
        let ftyp = MP4TestHelper.buildAtom(type: "ftyp", data: Data(repeating: 0x41, count: 4))
        let free = MP4TestHelper.buildAtom(type: "free", data: Data(repeating: 0x00, count: 8))
        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(free)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parser.parseAtoms(from: reader)
        #expect(atoms.count == 2)
        #expect(atoms[0].type == "ftyp")
        #expect(atoms[1].type == "free")
    }

    // MARK: - Container Parsing

    @Test("Parses container atom with children")
    func parseContainerWithChildren() throws {
        let mvhd = MP4TestHelper.buildAtom(type: "mvhd", data: Data(repeating: 0x00, count: 20))
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd])
        let url = try MP4TestHelper.createTempFile(data: moov)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parser.parseAtoms(from: reader)
        #expect(atoms.count == 1)
        #expect(atoms[0].type == "moov")
        #expect(atoms[0].children.count == 1)
        #expect(atoms[0].children[0].type == "mvhd")
    }

    @Test("Parses nested containers")
    func parseNestedContainers() throws {
        let hdlr = MP4TestHelper.buildAtom(type: "hdlr", data: Data(repeating: 0x00, count: 8))
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [hdlr])
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [trak])
        let url = try MP4TestHelper.createTempFile(data: moov)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parser.parseAtoms(from: reader)
        let trakAtom = atoms[0].children[0]
        #expect(trakAtom.type == "trak")
        #expect(trakAtom.children[0].type == "mdia")
        #expect(trakAtom.children[0].children[0].type == "hdlr")
    }

    @Test("Parses meta atom with version/flags prefix")
    func parseMetaAtom() throws {
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: [])
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [udta])
        let url = try MP4TestHelper.createTempFile(data: moov)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parser.parseAtoms(from: reader)
        let metaAtom = atoms[0].children[0].children[0]
        #expect(metaAtom.type == "meta")
        #expect(metaAtom.children.count == 1)
        #expect(metaAtom.children[0].type == "ilst")
    }

    // MARK: - Extended Size

    @Test("Parses atom with extended size (size == 1)")
    func parseExtendedSize() throws {
        // Build an atom manually with size=1 and 8-byte extended size.
        var writer = BinaryWriter()
        writer.writeUInt32(1)  // size == 1 signals extended size
        writer.writeLatin1String("free")
        writer.writeUInt64(24)  // actual 64-bit size (header + extended + 8 bytes data)
        writer.writeRepeating(0x00, count: 8)  // data

        let url = try MP4TestHelper.createTempFile(data: writer.data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parser.parseAtoms(from: reader)
        #expect(atoms.count == 1)
        #expect(atoms[0].size == 24)
        #expect(atoms[0].dataOffset == 16)
    }

    // MARK: - Size Zero (rest of file)

    @Test("Parses atom with size == 0 (extends to end of file)")
    func parseSizeZero() throws {
        let ftyp = MP4TestHelper.buildAtom(type: "ftyp", data: Data(repeating: 0x41, count: 4))
        // Build mdat with size=0 (rest of file).
        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(0)  // size == 0
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeRepeating(0xFF, count: 16)  // audio data

        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(mdatWriter.data)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parser.parseAtoms(from: reader)
        #expect(atoms.count == 2)
        #expect(atoms[1].type == "mdat")
        #expect(atoms[1].size == UInt64(mdatWriter.data.count))
    }

    // MARK: - Atom Search

    @Test("child(ofType:) finds first matching child")
    func childOfType() {
        let atom = MP4Atom(
            type: "moov", offset: 0, size: 100, dataOffset: 8,
            children: [
                MP4Atom(type: "mvhd", offset: 8, size: 20, dataOffset: 16),
                MP4Atom(type: "trak", offset: 28, size: 30, dataOffset: 36)
            ]
        )
        #expect(atom.child(ofType: "mvhd")?.type == "mvhd")
        #expect(atom.child(ofType: "xxxx") == nil)
    }

    @Test("children(ofType:) finds all matching children")
    func childrenOfType() {
        let atom = MP4Atom(
            type: "moov", offset: 0, size: 100, dataOffset: 8,
            children: [
                MP4Atom(type: "trak", offset: 8, size: 20, dataOffset: 16),
                MP4Atom(type: "trak", offset: 28, size: 20, dataOffset: 36)
            ]
        )
        #expect(atom.children(ofType: "trak").count == 2)
    }

    @Test("find(path:) navigates dot-separated path")
    func findPath() {
        let hdlr = MP4Atom(type: "hdlr", offset: 40, size: 10, dataOffset: 48)
        let mdia = MP4Atom(type: "mdia", offset: 28, size: 30, dataOffset: 36, children: [hdlr])
        let trak = MP4Atom(type: "trak", offset: 8, size: 50, dataOffset: 16, children: [mdia])
        let moov = MP4Atom(type: "moov", offset: 0, size: 60, dataOffset: 8, children: [trak])

        #expect(moov.find(path: "trak.mdia.hdlr")?.type == "hdlr")
        #expect(moov.find(path: "trak.mdia.xxxx") == nil)
        #expect(moov.find(path: "") == nil)
    }

    // MARK: - DataSize

    @Test("dataSize computes correct payload size")
    func dataSize() {
        let atom = MP4Atom(type: "ftyp", offset: 0, size: 20, dataOffset: 8)
        #expect(atom.dataSize == 12)
    }

    @Test("dataSize returns 0 when size is too small")
    func dataSizeZero() {
        let atom = MP4Atom(type: "ftyp", offset: 0, size: 4, dataOffset: 8)
        #expect(atom.dataSize == 0)
    }

    // MARK: - Edge Cases

    @Test("Empty file returns empty atom array")
    func emptyFile() throws {
        let url = try MP4TestHelper.createTempFile(data: Data())
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parser.parseAtoms(from: reader)
        #expect(atoms.isEmpty)
    }

    @Test("File smaller than 8 bytes returns empty array")
    func tinyFile() throws {
        let url = try MP4TestHelper.createTempFile(data: Data(repeating: 0x00, count: 4))
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parser.parseAtoms(from: reader)
        #expect(atoms.isEmpty)
    }

    @Test("Non-container atom has no children")
    func leafAtomNoChildren() throws {
        let mdat = MP4TestHelper.buildAtom(type: "mdat", data: Data(repeating: 0xFF, count: 16))
        let url = try MP4TestHelper.createTempFile(data: mdat)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parser.parseAtoms(from: reader)
        #expect(atoms.count == 1)
        #expect(atoms[0].children.isEmpty)
    }

    @Test("Truncated extended size throws invalidAtom")
    func truncatedExtendedSize() throws {
        // Atom with size=1 (extended) but file too small for 8-byte extended size.
        var writer = BinaryWriter()
        writer.writeUInt32(1)  // size == 1 signals extended size
        writer.writeLatin1String("free")
        // Only 4 bytes instead of 8 for extended size.
        writer.writeUInt32(0)

        let url = try MP4TestHelper.createTempFile(data: writer.data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        #expect(throws: MP4Error.self) {
            _ = try parser.parseAtoms(from: reader)
        }
    }
}
