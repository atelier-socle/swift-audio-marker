import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCommands

/// Demonstrates the CLI strip command: removing metadata and preserving audio data.
@Suite("Showcase: CLI Strip")
struct CLIStripShowcaseTests {

    // MARK: - Force Strip

    @Test("audiomarker strip --force — remove all metadata")
    func stripForce() throws {
        // Create an MP3 with full metadata + chapters + artwork + lyrics
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 32)
        let frames: [Data] = [
            ID3TestHelper.buildTextFrame(id: "TIT2", text: "Full Song"),
            ID3TestHelper.buildTextFrame(id: "TPE1", text: "Artist"),
            ID3TestHelper.buildTextFrame(id: "TALB", text: "Album"),
            ID3TestHelper.buildAPICFrame(imageData: jpegData),
            ID3TestHelper.buildUSLTFrame(text: "Some lyrics here"),
            ID3TestHelper.buildCHAPFrame(
                elementID: "ch1", startTime: 0, endTime: 60_000,
                subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chapter")])
        ]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Verify everything is present before strip
        let before = try AudioMarkerEngine().read(from: url)
        #expect(before.metadata.title == "Full Song")
        #expect(before.metadata.artwork != nil)
        #expect(before.metadata.unsynchronizedLyrics != nil)
        #expect(!before.chapters.isEmpty)

        // Strip with --force (skips confirmation prompt)
        var cmd = try Strip.parse([url.path, "--force"])
        try cmd.run()

        // After stripping, the MP3 no longer has an ID3 tag — reading throws
        #expect(throws: AudioMarkerError.self) {
            _ = try AudioMarkerEngine().read(from: url)
        }
    }

    // MARK: - Preserves Audio

    @Test("audiomarker strip — preserves audio data")
    func stripPreservesAudio() throws {
        // Create a file and note the size
        let audioBytes = 512
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TIT2", text: "Big Song"),
                ID3TestHelper.buildTextFrame(id: "TPE1", text: "Big Artist"),
                ID3TestHelper.buildTextFrame(id: "TALB", text: "Big Album")
            ])
        let url = try ID3TestHelper.createTempFile(tagData: tag, audioBytes: audioBytes)
        defer { try? FileManager.default.removeItem(at: url) }

        let attrsBefore = try FileManager.default.attributesOfItem(atPath: url.path)
        let sizeBefore = (attrsBefore[.size] as? UInt64) ?? 0

        // Strip
        var cmd = try Strip.parse([url.path, "--force"])
        try cmd.run()

        let attrsAfter = try FileManager.default.attributesOfItem(atPath: url.path)
        let sizeAfter = (attrsAfter[.size] as? UInt64) ?? 0

        // File should be smaller (metadata removed) but > 0 (audio preserved)
        #expect(sizeAfter < sizeBefore)
        #expect(sizeAfter > 0)
    }
}
