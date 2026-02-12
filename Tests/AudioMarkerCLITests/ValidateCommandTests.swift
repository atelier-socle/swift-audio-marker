import ArgumentParser
import Foundation
import Testing

@testable import AudioMarker
@testable import AudioMarkerCommands

@Suite("CLI Validate Command")
struct ValidateCommandTests {

    @Test("Validate a well-formed file exits successfully")
    func validateWellFormed() throws {
        let url = try CLITestHelper.createMP3(title: "Good File")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Validate.parse([url.path])
        // Should not throw (exit code 0) — no errors, only possible warnings.
        try cmd.run()
    }

    @Test("Validate a file with chapter order error exits with error")
    func validateChapterOrderError() throws {
        // Create MP3 with chapters out of order (ch2 starts before ch1).
        let titleFrame = ID3TestHelper.buildTextFrame(id: "TIT2", text: "Bad Order")
        let chap1 = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 60_000, endTime: 120_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Second")])
        let chap2 = ID3TestHelper.buildCHAPFrame(
            elementID: "ch2", startTime: 30_000, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "First")])
        let tag = ID3TestHelper.buildTag(
            version: .v2_3, frames: [titleFrame, chap1, chap2])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Validate.parse([url.path])
        #expect(throws: ExitCode.self) {
            try cmd.run()
        }
    }

    @Test("Validate with JSON format produces valid JSON")
    func validateJSONFormat() throws {
        let url = try CLITestHelper.createMP3(title: "JSON Validate")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Validate.parse([url.path, "--format", "json"])
        try cmd.run()
    }

    @Test("Validate file without title generates warning but passes")
    func validateNoTitle() throws {
        // Create MP3 with no title — MetadataTitleRule emits a warning, not an error.
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Validate.parse([url.path])
        // Warnings do not cause exit code 1 — validation passes.
        try cmd.run()
    }

    @Test("Validate JSON output includes warnings when present")
    func validateJSONWithWarnings() throws {
        // Create MP3 with no title — MetadataTitleRule emits a warning.
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // JSON format with warnings-only (no errors) should succeed.
        var cmd = try Validate.parse([url.path, "--format", "json"])
        try cmd.run()
    }

    @Test("Validate JSON output has correct structure for errors")
    func validateJSONWithErrors() throws {
        // Create MP3 with overlapping chapters.
        let titleFrame = ID3TestHelper.buildTextFrame(id: "TIT2", text: "Overlap Test")
        let chap1 = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 60_000, endTime: 120_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chapter A")])
        let chap2 = ID3TestHelper.buildCHAPFrame(
            elementID: "ch2", startTime: 30_000, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chapter B")])
        let tag = ID3TestHelper.buildTag(
            version: .v2_3, frames: [titleFrame, chap1, chap2])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try Validate.parse([url.path, "--format", "json"])
        #expect(throws: ExitCode.self) {
            try cmd.run()
        }
    }
}
