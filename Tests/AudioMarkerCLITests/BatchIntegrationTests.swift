import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCLI

@Suite("CLI Batch Integration")
struct BatchIntegrationTests {

    // MARK: - Batch Read Command

    @Test("Batch read command reads directory")
    func batchReadCommand() async throws {
        let dir = try CLITestHelper.createTempDirectory(files: ["song1.mp3", "song2.mp3"])
        defer { try? FileManager.default.removeItem(at: dir) }

        var cmd = try Batch.BatchRead.parse([dir.path])
        try await cmd.run()
    }

    @Test("Batch read with empty directory")
    func batchReadEmptyDirectory() async throws {
        let dir = try CLITestHelper.createTempDirectory(files: [])
        defer { try? FileManager.default.removeItem(at: dir) }

        var cmd = try Batch.BatchRead.parse([dir.path])
        try await cmd.run()
    }

    @Test("Batch read with recursive flag")
    func batchReadRecursive() async throws {
        let dir = try CLITestHelper.createTempDirectory(files: ["song1.mp3"])
        defer { try? FileManager.default.removeItem(at: dir) }

        var cmd = try Batch.BatchRead.parse([dir.path, "--recursive"])
        try await cmd.run()
    }

    // MARK: - Batch Strip Command

    @Test("Batch strip command strips directory with force")
    func batchStripCommand() async throws {
        let dir = try CLITestHelper.createTempDirectory(files: ["song1.mp3", "song2.mp3"])
        defer { try? FileManager.default.removeItem(at: dir) }

        var cmd = try Batch.BatchStrip.parse([dir.path, "--force"])
        try await cmd.run()
    }

    @Test("Batch strip with empty directory")
    func batchStripEmptyDirectory() async throws {
        let dir = try CLITestHelper.createTempDirectory(files: [])
        defer { try? FileManager.default.removeItem(at: dir) }

        var cmd = try Batch.BatchStrip.parse([dir.path, "--force"])
        try await cmd.run()
    }

    @Test("Batch read with unreadable file hits error path")
    func batchReadWithCorruptFile() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Create a corrupt MP3 (no valid ID3 tag, just random bytes).
        let corrupt = dir.appendingPathComponent("corrupt.mp3")
        try Data(repeating: 0x00, count: 64).write(to: corrupt)

        var cmd = try Batch.BatchRead.parse([dir.path])
        try await cmd.run()
    }

    @Test("Batch strip with unreadable file hits error path")
    func batchStripWithCorruptFile() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let corrupt = dir.appendingPathComponent("corrupt.mp3")
        try Data(repeating: 0x00, count: 64).write(to: corrupt)

        var cmd = try Batch.BatchStrip.parse([dir.path, "--force"])
        try await cmd.run()
    }
}
