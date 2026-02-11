import Foundation
import Testing

@testable import AudioMarker

@Suite("MP4 Atom Builder")
struct MP4AtomBuilderTests {

    let builder = MP4AtomBuilder()

    // MARK: - Generic Atoms

    @Test("Builds atom with correct header and data")
    func buildAtom() {
        let data = Data([0x41, 0x42, 0x43, 0x44])
        let atom = builder.buildAtom(type: "ftyp", data: data)

        // Size: 8 (header) + 4 (data) = 12.
        #expect(atom.count == 12)
        // First 4 bytes: size = 12 (big-endian).
        #expect(atom[0] == 0x00)
        #expect(atom[1] == 0x00)
        #expect(atom[2] == 0x00)
        #expect(atom[3] == 0x0C)
        // Bytes 4–7: type "ftyp".
        #expect(String(data: atom[4..<8], encoding: .isoLatin1) == "ftyp")
        // Bytes 8–11: data.
        #expect(atom[8..<12] == data[0..<4])
    }

    @Test("Builds container atom with children")
    func buildContainerAtom() {
        let child1 = builder.buildAtom(type: "mvhd", data: Data(repeating: 0x00, count: 4))
        let child2 = builder.buildAtom(type: "trak", data: Data(repeating: 0x01, count: 8))
        let container = builder.buildContainerAtom(type: "moov", children: [child1, child2])

        // Size: 8 + child1.count + child2.count = 8 + 12 + 16 = 36.
        #expect(container.count == 36)
        #expect(String(data: container[4..<8], encoding: .isoLatin1) == "moov")
    }

    @Test("Builds empty container atom")
    func buildEmptyContainer() {
        let container = builder.buildContainerAtom(type: "ilst", children: [])
        #expect(container.count == 8)
        #expect(String(data: container[4..<8], encoding: .isoLatin1) == "ilst")
    }

    // MARK: - Data Atoms

    @Test("Builds data atom with type indicator and locale")
    func buildDataAtom() {
        let value = Data("Hello".utf8)
        let atom = builder.buildDataAtom(typeIndicator: 1, value: value)

        // Size: 8 (header) + 4 (type) + 4 (locale) + 5 (value) = 21.
        #expect(atom.count == 21)
        #expect(String(data: atom[4..<8], encoding: .isoLatin1) == "data")
        // Type indicator at offset 8 = 1 (UTF-8).
        #expect(atom[8] == 0x00)
        #expect(atom[9] == 0x00)
        #expect(atom[10] == 0x00)
        #expect(atom[11] == 0x01)
    }

    // MARK: - Metadata Items

    @Test("Builds metadata item with data sub-atom")
    func buildMetadataItem() {
        let value = Data("Test".utf8)
        let item = builder.buildMetadataItem(type: "\u{00A9}nam", typeIndicator: 1, value: value)

        // Outer: 8 (header) + inner data atom (8 + 4 + 4 + 4 = 20) = 28.
        #expect(item.count == 28)
    }

    // MARK: - Meta Atom

    @Test("Builds meta atom with version/flags prefix")
    func buildMetaAtom() {
        let ilst = builder.buildContainerAtom(type: "ilst", children: [])
        let meta = builder.buildMetaAtom(children: [ilst])

        // Size: 8 (header) + 4 (version/flags) + 8 (ilst) = 20.
        #expect(meta.count == 20)
        #expect(String(data: meta[4..<8], encoding: .isoLatin1) == "meta")
        // Version/flags at offset 8 should be 0.
        #expect(meta[8] == 0x00)
        #expect(meta[9] == 0x00)
        #expect(meta[10] == 0x00)
        #expect(meta[11] == 0x00)
    }

    // MARK: - Round-Trip

    @Test("Built atom can be parsed by MP4AtomParser")
    func roundTripWithParser() throws {
        let child = builder.buildAtom(type: "mvhd", data: Data(repeating: 0x00, count: 20))
        let moov = builder.buildContainerAtom(type: "moov", children: [child])

        let url = try MP4TestHelper.createTempFile(data: moov)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)

        #expect(atoms.count == 1)
        #expect(atoms[0].type == "moov")
        #expect(atoms[0].children.count == 1)
        #expect(atoms[0].children[0].type == "mvhd")
    }
}
