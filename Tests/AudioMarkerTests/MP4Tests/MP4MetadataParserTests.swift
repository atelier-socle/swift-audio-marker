import Foundation
import Testing

@testable import AudioMarker

@Suite("MP4MetadataParser")
struct MP4MetadataParserTests {

    let parser = MP4MetadataParser()
    let atomParser = MP4AtomParser()

    // MARK: - Text Metadata

    @Test("Parses title from ©nam")
    func parseTitle() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTTextItem(type: "\u{00A9}nam", text: "My Song")]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.title == "My Song")
    }

    @Test("Parses artist from ©ART")
    func parseArtist() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTTextItem(type: "\u{00A9}ART", text: "The Artist")]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.artist == "The Artist")
    }

    @Test("Parses album from ©alb")
    func parseAlbum() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTTextItem(type: "\u{00A9}alb", text: "Best Album")]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.album == "Best Album")
    }

    @Test("Parses genre from ©gen")
    func parseGenre() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTTextItem(type: "\u{00A9}gen", text: "Rock")]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.genre == "Rock")
    }

    @Test("Parses year from ©day")
    func parseYear() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTTextItem(type: "\u{00A9}day", text: "2024")]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.year == 2024)
    }

    @Test("Parses year from full date string")
    func parseYearFromDate() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [
                MP4TestHelper.buildILSTTextItem(type: "\u{00A9}day", text: "2024-06-15")
            ]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.year == 2024)
    }

    @Test("Parses all text fields")
    func parseAllTextFields() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [
                MP4TestHelper.buildILSTTextItem(type: "\u{00A9}wrt", text: "Composer"),
                MP4TestHelper.buildILSTTextItem(type: "\u{00A9}cmt", text: "A comment"),
                MP4TestHelper.buildILSTTextItem(type: "\u{00A9}too", text: "AudioMarker"),
                MP4TestHelper.buildILSTTextItem(type: "\u{00A9}lyr", text: "Some lyrics"),
                MP4TestHelper.buildILSTTextItem(type: "aART", text: "Album Artist"),
                MP4TestHelper.buildILSTTextItem(type: "cprt", text: "2024 Test")
            ]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.composer == "Composer")
        #expect(metadata.comment == "A comment")
        #expect(metadata.encoder == "AudioMarker")
        #expect(metadata.unsynchronizedLyrics == "Some lyrics")
        #expect(metadata.albumArtist == "Album Artist")
        #expect(metadata.copyright == "2024 Test")
    }

    // MARK: - Numeric Metadata

    @Test("Parses track number from trkn")
    func parseTrackNumber() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTIntegerPair(type: "trkn", value: 5, total: 12)]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.trackNumber == 5)
    }

    @Test("Parses disc number from disk")
    func parseDiscNumber() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTIntegerPair(type: "disk", value: 2, total: 3)]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.discNumber == 2)
    }

    @Test("Parses BPM from tmpo")
    func parseBPM() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTUInt16Item(type: "tmpo", value: 120)]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.bpm == 120)
    }

    // MARK: - Genre (gnre)

    @Test("Parses genre from gnre atom (ID3v1 index)")
    func parseGnreAtom() throws {
        // Index 1 (0-based) = "Classic Rock" (gnre uses 1-based, so pass 2).
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildGnreAtom(genreIndex: 2)]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.genre == "Classic Rock")
    }

    @Test("©gen takes precedence over gnre")
    func genTextPrecedence() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [
                MP4TestHelper.buildILSTTextItem(type: "\u{00A9}gen", text: "Indie"),
                MP4TestHelper.buildGnreAtom(genreIndex: 1)
            ]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.genre == "Indie")
    }

    // MARK: - Artwork

    @Test("Parses JPEG artwork from covr")
    func parseJPEGArtwork() throws {
        // Minimal JPEG magic bytes.
        var jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        jpegData.append(Data(repeating: 0x00, count: 16))
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTArtwork(typeIndicator: 13, imageData: jpegData)]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.artwork != nil)
        #expect(metadata.artwork?.format == .jpeg)
    }

    @Test("Parses PNG artwork from covr")
    func parsePNGArtwork() throws {
        // PNG magic bytes.
        var pngData = Data([0x89, 0x50, 0x4E, 0x47])
        pngData.append(Data(repeating: 0x00, count: 16))
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTArtwork(typeIndicator: 14, imageData: pngData)]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.artwork != nil)
        #expect(metadata.artwork?.format == .png)
    }

    // MARK: - Reverse DNS (----)

    @Test("Parses reverse DNS custom text field")
    func parseReverseDNS() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [
                MP4TestHelper.buildReverseDNSAtom(
                    mean: "com.apple.iTunes",
                    name: "ISRC",
                    value: "US1234567890"
                )
            ]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.customTextFields["com.apple.iTunes:ISRC"] == "US1234567890")
    }

    // MARK: - Duration

    @Test("Parses duration from mvhd version 0")
    func parseDurationV0() throws {
        let data = MP4TestHelper.buildMinimalMP4(timescale: 44100, duration: 441_000)
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let duration = try parser.parseDuration(from: atoms, reader: reader)
        let durationValue = try #require(duration)
        #expect(durationValue.timeInterval == 10.0)
    }

    @Test("Parses duration from mvhd version 1")
    func parseDurationV1() throws {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHDv1(timescale: 48000, duration: 480_000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd])
        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moov)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let duration = try parser.parseDuration(from: atoms, reader: reader)
        let durationValue = try #require(duration)
        #expect(durationValue.timeInterval == 10.0)
    }

    @Test("Returns nil duration when moov is missing")
    func durationNilWithoutMoov() throws {
        let ftyp = MP4TestHelper.buildAtom(type: "ftyp", data: Data(repeating: 0x00, count: 4))
        let url = try MP4TestHelper.createTempFile(data: ftyp)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let duration = try parser.parseDuration(from: atoms, reader: reader)
        #expect(duration == nil)
    }

    // MARK: - Error Cases

    @Test("Throws atomNotFound when moov is missing")
    func missingMoov() throws {
        let ftyp = MP4TestHelper.buildAtom(type: "ftyp", data: Data(repeating: 0x00, count: 4))
        let url = try MP4TestHelper.createTempFile(data: ftyp)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        #expect(throws: MP4Error.self) {
            _ = try parser.parseMetadata(from: atoms, reader: reader)
        }
    }

    @Test("Returns empty metadata when ilst is missing")
    func missingIlst() throws {
        let data = MP4TestHelper.buildMinimalMP4()
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.title == nil)
        #expect(metadata.artist == nil)
    }
}

// MARK: - Coverage Edge Cases

extension MP4MetadataParserTests {

    @Test("ilst item without data sub-atom returns nil")
    func ilstItemWithoutData() throws {
        // Build ©nam atom without a "data" child — just an empty container.
        let emptyItem = MP4TestHelper.buildContainerAtom(type: "\u{00A9}nam", children: [])
        let data = MP4TestHelper.buildMP4WithMetadata(ilstItems: [emptyItem])
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.title == nil)
    }

    @Test("Data atom with payload too small returns nil text")
    func dataAtomTooSmall() throws {
        // Build a data atom with only 4 bytes (needs > 8).
        let dataAtom = MP4TestHelper.buildAtom(type: "data", data: Data(repeating: 0x00, count: 4))
        let item = MP4TestHelper.buildContainerAtom(type: "\u{00A9}nam", children: [dataAtom])
        let data = MP4TestHelper.buildMP4WithMetadata(ilstItems: [item])
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.title == nil)
    }

    @Test("Track number value of 0 returns nil")
    func trackNumberZero() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildILSTIntegerPair(type: "trkn", value: 0)]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.trackNumber == nil)
    }

    @Test("Artwork with unrecognized format and bad type indicator returns nil")
    func artworkUnrecognizedFormat() throws {
        // Image data with no magic bytes and unknown type indicator (99).
        let imageData = Data(repeating: 0x42, count: 20)
        let dataPayload = MP4TestHelper.buildDataPayload(typeIndicator: 99, value: imageData)
        let dataAtom = MP4TestHelper.buildAtom(type: "data", data: dataPayload)
        let covr = MP4TestHelper.buildContainerAtom(type: "covr", children: [dataAtom])
        let data = MP4TestHelper.buildMP4WithMetadata(ilstItems: [covr])
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.artwork == nil)
    }

    @Test("Genre index out of range returns nil")
    func genreOutOfRange() throws {
        let data = MP4TestHelper.buildMP4WithMetadata(
            ilstItems: [MP4TestHelper.buildGnreAtom(genreIndex: 999)]
        )
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.genre == nil)
    }

    @Test("Truncated mvhd returns nil duration")
    func truncatedMvhd() throws {
        // Build an mvhd with too few bytes.
        let mvhd = MP4TestHelper.buildAtom(type: "mvhd", data: Data(repeating: 0x00, count: 4))
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd])
        let ftyp = MP4TestHelper.buildFtyp()
        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moov)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let duration = try parser.parseDuration(from: atoms, reader: reader)
        #expect(duration == nil)
    }

    @Test("mvhd with timescale 0 returns nil duration")
    func mvhdZeroTimescale() throws {
        let mvhd = MP4TestHelper.buildMVHD(timescale: 0, duration: 1000)
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd])
        let ftyp = MP4TestHelper.buildFtyp()
        var fileData = Data()
        fileData.append(ftyp)
        fileData.append(moov)
        let url = try MP4TestHelper.createTempFile(data: fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let duration = try parser.parseDuration(from: atoms, reader: reader)
        #expect(duration == nil)
    }

    @Test("Reverse DNS atom missing mean/name returns no custom field")
    func reverseDNSMissingParts() throws {
        // ---- atom with only a data sub-atom, no mean or name.
        let dataPayload = MP4TestHelper.buildDataPayload(typeIndicator: 1, value: Data("val".utf8))
        let dataAtom = MP4TestHelper.buildAtom(type: "data", data: dataPayload)
        let reverseDNS = MP4TestHelper.buildContainerAtom(type: "----", children: [dataAtom])
        let data = MP4TestHelper.buildMP4WithMetadata(ilstItems: [reverseDNS])
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.customTextFields.isEmpty)
    }

    @Test("Unknown ilst atom type is ignored")
    func unknownIlstAtom() throws {
        let item = MP4TestHelper.buildILSTTextItem(type: "zzzz", text: "ignored")
        let data = MP4TestHelper.buildMP4WithMetadata(ilstItems: [item])
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.title == nil)
    }

    @Test("Artwork with empty image data returns nil")
    func artworkEmptyImageData() throws {
        // Data atom with type indicator + locale but 0 image bytes.
        let dataPayload = MP4TestHelper.buildDataPayload(typeIndicator: 13, value: Data())
        let dataAtom = MP4TestHelper.buildAtom(type: "data", data: dataPayload)
        let covr = MP4TestHelper.buildContainerAtom(type: "covr", children: [dataAtom])
        let data = MP4TestHelper.buildMP4WithMetadata(ilstItems: [covr])
        let url = try MP4TestHelper.createTempFile(data: data)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try atomParser.parseAtoms(from: reader)
        let metadata = try parser.parseMetadata(from: atoms, reader: reader)
        #expect(metadata.artwork == nil)
    }
}
