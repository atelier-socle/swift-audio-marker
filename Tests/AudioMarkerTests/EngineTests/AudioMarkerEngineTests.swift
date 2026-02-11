import Foundation
import Testing

@testable import AudioMarker

@Suite("AudioMarker Engine")
struct AudioMarkerEngineTests {

    let engine = AudioMarkerEngine()

    // MARK: - Helpers

    /// Creates a temporary MP3 file with the given metadata title.
    private func createMP3(title: String? = nil) throws -> URL {
        var frames: [Data] = []
        if let title {
            frames.append(ID3TestHelper.buildTextFrame(id: "TIT2", text: title))
        }
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        return try ID3TestHelper.createTempFile(tagData: tag)
    }

    /// Creates a temporary M4A file with ftyp + moov + mdat.
    private func createM4A(title: String? = nil) throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)

        var moovChildren: [Data] = [mvhd]
        if let title {
            let items = [MP4TestHelper.buildILSTTextItem(type: "\u{00A9}nam", text: title)]
            let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: items)
            let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
            let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])
            moovChildren.append(udta)
        }
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: moovChildren)
        let mdat = MP4TestHelper.buildAtom(type: "mdat", data: Data(repeating: 0xFF, count: 128))

        var file = Data()
        file.append(ftyp)
        file.append(moov)
        file.append(mdat)

        return try MP4TestHelper.createTempFile(data: file)
    }

    // MARK: - Format Detection

    @Test("Detects MP3 format")
    func detectMP3() throws {
        let url = try createMP3(title: "Test")
        defer { try? FileManager.default.removeItem(at: url) }

        let format = try engine.detectFormat(of: url)
        #expect(format == .mp3)
    }

    @Test("Detects M4A format")
    func detectM4A() throws {
        let url = try createM4A()
        defer { try? FileManager.default.removeItem(at: url) }

        let format = try engine.detectFormat(of: url)
        #expect(format == .m4a)
    }

    @Test("Unknown format throws unknownFormat")
    func detectUnknownFormat() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        try Data(repeating: 0x00, count: 64).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: AudioMarkerError.self) {
            try engine.detectFormat(of: url)
        }
    }

    // MARK: - Reading

    @Test("Reads MP3 metadata")
    func readMP3() throws {
        let url = try createMP3(title: "Engine Test")
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try engine.read(from: url)
        #expect(info.metadata.title == "Engine Test")
    }

    @Test("Reads M4A metadata")
    func readM4A() throws {
        let url = try createM4A(title: "M4A Test")
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try engine.read(from: url)
        #expect(info.metadata.title == "M4A Test")
    }

    // MARK: - Writing

    @Test("Write MP3 round-trip")
    func writeMP3RoundTrip() throws {
        let url = try createMP3()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.title = "Written Title"
        try engine.write(info, to: url)

        let readBack = try engine.read(from: url)
        #expect(readBack.metadata.title == "Written Title")
    }

    @Test("Write M4A round-trip")
    func writeM4ARoundTrip() throws {
        let url = try createM4A()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.title = "M4A Written"
        try engine.write(info, to: url)

        let readBack = try engine.read(from: url)
        #expect(readBack.metadata.title == "M4A Written")
    }

    // MARK: - Modify

    @Test("Modify MP3 updates metadata")
    func modifyMP3() throws {
        let url = try createMP3(title: "Original")
        defer { try? FileManager.default.removeItem(at: url) }

        var info = try engine.read(from: url)
        info.metadata.title = "Modified"
        try engine.modify(info, in: url)

        let readBack = try engine.read(from: url)
        #expect(readBack.metadata.title == "Modified")
    }

    // MARK: - Strip

    @Test("Strip MP3 removes metadata")
    func stripMP3() throws {
        let url = try createMP3(title: "To Remove")
        defer { try? FileManager.default.removeItem(at: url) }

        try engine.strip(from: url)

        #expect(throws: AudioMarkerError.self) {
            try engine.read(from: url)
        }
    }

    @Test("Strip M4A removes metadata")
    func stripM4A() throws {
        let url = try createM4A(title: "To Remove")
        defer { try? FileManager.default.removeItem(at: url) }

        try engine.strip(from: url)

        let readBack = try engine.read(from: url)
        #expect(readBack.metadata.title == nil)
    }

    // MARK: - Chapters

    @Test("Read chapters from MP3")
    func readChapters() throws {
        let chapFrame = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 0, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chapter 1")])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [chapFrame])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Chapter 1")
    }

    @Test("Write chapters to MP3")
    func writeChapters() throws {
        let url = try createMP3(title: "Has Chapters")
        defer { try? FileManager.default.removeItem(at: url) }

        let chapters = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .seconds(60), title: "Main")
        ])
        try engine.writeChapters(chapters, to: url)

        let readBack = try engine.readChapters(from: url)
        #expect(readBack.count == 2)
        #expect(readBack[0].title == "Intro")
        #expect(readBack[1].title == "Main")
    }

    // MARK: - Export / Import

    @Test("Export chapters to Podlove JSON")
    func exportChapters() throws {
        let chapFrame = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 0, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Intro")])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [chapFrame])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let json = try engine.exportChapters(from: url, format: .podloveJSON)
        #expect(json.contains("Intro"))
        #expect(json.contains("\"version\" : \"1.2\""))
    }

    @Test("Import chapters from Podlove JSON to MP3")
    func importChapters() throws {
        let url = try createMP3(title: "Import Test")
        defer { try? FileManager.default.removeItem(at: url) }

        let json = """
            {
              "version": "1.2",
              "chapters": [
                { "start": "00:00:00.000", "title": "Imported" }
              ]
            }
            """
        try engine.importChapters(from: json, format: .podloveJSON, to: url)

        let chapters = try engine.readChapters(from: url)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Imported")
    }

    // MARK: - Validation

    @Test("Validate returns result for valid info")
    func validateValid() {
        let info = AudioFileInfo(metadata: AudioMetadata(title: "Good"))
        let result = engine.validate(info)
        #expect(result.isValid)
    }

    @Test("validateOrThrow throws for invalid info")
    func validateOrThrowInvalid() {
        var metadata = AudioMetadata()
        metadata.language = "xx"  // Invalid: must be 3-letter ISO 639-2 code.
        let info = AudioFileInfo(metadata: metadata)

        #expect(throws: AudioMarkerError.self) {
            try engine.validateOrThrow(info)
        }
    }

    @Test("validateBeforeWriting = false skips validation")
    func skipValidation() throws {
        let config = Configuration(validateBeforeWriting: false)
        let eng = AudioMarkerEngine(configuration: config)
        let url = try createMP3()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.language = "xx"  // Would fail validation (error-level).
        // Should not throw because validation is disabled.
        try eng.write(info, to: url)
    }
}
