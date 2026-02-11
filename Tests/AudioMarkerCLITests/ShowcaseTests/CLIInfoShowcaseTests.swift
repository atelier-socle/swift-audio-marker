import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCommands

/// Demonstrates the CLI info command: technical details for MP3 and M4A files.
@Suite("Showcase: CLI Info")
struct CLIInfoShowcaseTests {

    // MARK: - MP3 Info

    @Test("audiomarker info — display MP3 file technical details")
    func infoMP3() throws {
        // Create an MP3 with metadata and artwork
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 32)
        let frames: [Data] = [
            ID3TestHelper.buildTextFrame(id: "TIT2", text: "Info Test"),
            ID3TestHelper.buildAPICFrame(imageData: jpegData),
            ID3TestHelper.buildCHAPFrame(
                elementID: "ch1", startTime: 0, endTime: 60_000,
                subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chapter")])
        ]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Info command runs without error
        var cmd = try Info.parse([url.path])
        try cmd.run()
    }

    // MARK: - M4A Info

    @Test("audiomarker info — M4A file")
    func infoM4A() throws {
        let url = try CLITestHelper.createM4A(title: "M4A Info Test")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Info.parse([url.path])
        try cmd.run()
    }
}
