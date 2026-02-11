import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCommands

@Suite("CLI Command Integration")
struct CommandIntegrationTests {

    // MARK: - Read Command

    @Test("Read command reads MP3 metadata")
    func readCommand() throws {
        let url = try CLITestHelper.createMP3(title: "CLI Test")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.title == "CLI Test")
    }

    @Test("Read command outputs JSON format")
    func readCommandJSON() throws {
        let url = try CLITestHelper.createMP3(title: "JSON Test")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path, "--format", "json"])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.title == "JSON Test")
    }

    @Test("Read command reads M4A metadata")
    func readCommandM4A() throws {
        let url = try CLITestHelper.createM4A(title: "M4A Test")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.title == "M4A Test")
    }

    @Test("Read command displays chapters")
    func readCommandWithChapters() throws {
        let url = try CLITestHelper.createMP3WithChapters()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.chapters.count == 2)
    }

    @Test("Read command JSON with chapters")
    func readCommandJSONWithChapters() throws {
        let url = try CLITestHelper.createMP3WithChapters()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Read.parse([url.path, "--format", "json"])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.chapters.count == 2)
    }

    // MARK: - Write Command

    @Test("Write command modifies metadata")
    func writeCommand() throws {
        let url = try CLITestHelper.createMP3(title: "Original")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Write.parse([url.path, "--title", "Updated", "--artist", "New Artist"])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.title == "Updated")
        #expect(info.metadata.artist == "New Artist")
    }

    @Test("Write command sets all text fields")
    func writeAllTextFields() throws {
        let url = try CLITestHelper.createMP3(title: "Original")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Write.parse([
            url.path,
            "--title", "T", "--artist", "A", "--album", "Al",
            "--genre", "Rock", "--composer", "C", "--album-artist", "AA",
            "--comment", "Nice"
        ])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.title == "T")
        #expect(info.metadata.artist == "A")
        #expect(info.metadata.album == "Al")
        #expect(info.metadata.genre == "Rock")
        #expect(info.metadata.composer == "C")
        #expect(info.metadata.albumArtist == "AA")
        #expect(info.metadata.comment == "Nice")
    }

    @Test("Write command sets numeric fields")
    func writeNumericFields() throws {
        let url = try CLITestHelper.createMP3(title: "Original")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Write.parse([
            url.path,
            "--year", "2025", "--track-number", "5",
            "--disc-number", "2", "--bpm", "128"
        ])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.year == 2025)
        #expect(info.metadata.trackNumber == 5)
        #expect(info.metadata.discNumber == 2)
        #expect(info.metadata.bpm == 128)
    }

    @Test("Write command sets artwork from file")
    func writeArtwork() throws {
        let url = try CLITestHelper.createMP3(title: "Art")
        defer { try? FileManager.default.removeItem(at: url) }

        let jpegURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: jpegURL) }
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 64)
        try jpegData.write(to: jpegURL)

        var cmd = try Write.parse([url.path, "--artwork", jpegURL.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.artwork != nil)
    }

    @Test("Write command on file without existing metadata")
    func writeToBareMp3() throws {
        // File with no ID3 tag — triggers the catch path in run().
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0xFF, count: 256).write(to: url)

        var cmd = try Write.parse([url.path, "--title", "New Title"])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.title == "New Title")
    }

    // MARK: - Strip Command

    @Test("Strip command removes metadata")
    func stripCommand() throws {
        let url = try CLITestHelper.createMP3(title: "To Strip")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Strip.parse([url.path, "--force"])
        try cmd.run()

        #expect(throws: AudioMarkerError.self) {
            try AudioMarkerEngine().read(from: url)
        }
    }

    // MARK: - Info Command

    @Test("Info command displays format")
    func infoCommand() throws {
        let url = try CLITestHelper.createMP3(title: "Info Test")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Info.parse([url.path])
        try cmd.run()

        let format = try AudioMarkerEngine().detectFormat(of: url)
        #expect(format == .mp3)
    }

    @Test("Info command on M4A file")
    func infoCommandM4A() throws {
        let url = try CLITestHelper.createM4A(title: "M4A Info")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Info.parse([url.path])
        try cmd.run()

        let format = try AudioMarkerEngine().detectFormat(of: url)
        #expect(format == .m4a)
    }

    @Test("Info command on file with chapters")
    func infoCommandWithChapters() throws {
        let url = try CLITestHelper.createMP3WithChapters()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Info.parse([url.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.chapters.count == 2)
    }

    @Test("Info command on file with artwork")
    func infoCommandWithArtwork() throws {
        let url = try CLITestHelper.createMP3WithArtwork()
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Info.parse([url.path])
        try cmd.run()

        let info = try AudioMarkerEngine().read(from: url)
        #expect(info.metadata.artwork != nil)
    }
}
