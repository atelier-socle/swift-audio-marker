// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation
import Testing

@testable import AudioMarker

/// Demonstrates the validation system: rules, results, severity levels, and engine integration.
@Suite("Showcase: Validation")
struct ValidationShowcaseTests {

    // MARK: - Clean Validation

    @Test("Validate clean metadata — no issues")
    func validateClean() {
        // Build a well-formed AudioFileInfo
        let info = AudioFileInfo(
            metadata: AudioMetadata(title: "Valid Song", artist: "Artist", album: "Album"),
            chapters: ChapterList([
                Chapter(start: .zero, title: "Intro", end: .seconds(60)),
                Chapter(start: .seconds(60), title: "Verse", end: .seconds(120))
            ]),
            duration: .seconds(120)
        )

        let result = AudioValidator().validate(info)
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Problematic Metadata

    @Test("Validate problematic metadata — catches all issue types")
    func validateProblematic() {
        var meta = AudioMetadata()
        // Empty title triggers a warning
        meta.title = ""
        // Negative year triggers an error
        meta.year = -1
        // Invalid language code (not 3 chars) triggers a warning
        meta.language = "english"

        // Chapter with start > end triggers an error
        let badChapter = Chapter(start: .seconds(60), title: "Bad", end: .seconds(30))
        let info = AudioFileInfo(
            metadata: meta,
            chapters: ChapterList([badChapter])
        )

        let result = AudioValidator().validate(info)

        // Has both errors and warnings
        #expect(!result.isValid)
        #expect(!result.errors.isEmpty)
        #expect(!result.warnings.isEmpty)

        // ValidationIssue structure
        let firstError = result.errors[0]
        #expect(firstError.severity == .error)
        #expect(!firstError.message.isEmpty)

        // Filter by severity
        let allWarnings = result.issues.filter { $0.severity == .warning }
        #expect(!allWarnings.isEmpty)
    }

    // MARK: - Engine Integration

    @Test("Engine validation integration — validateOrThrow")
    func validateOrThrowShowcase() {
        let engine = AudioMarkerEngine()

        // Valid info passes silently
        let validInfo = AudioFileInfo(
            metadata: AudioMetadata(title: "Good"),
            chapters: ChapterList()
        )
        let validResult = engine.validate(validInfo)
        #expect(validResult.isValid)

        // validate() returns a result with errors
        var badMeta = AudioMetadata()
        badMeta.language = "english"  // Not a valid 3-letter ISO 639-2 code → error
        let badInfo = AudioFileInfo(metadata: badMeta)
        let badResult = engine.validate(badInfo)
        #expect(!badResult.isValid)

        // validateOrThrow() throws AudioMarkerError.validationFailed
        #expect(throws: AudioMarkerError.self) {
            try engine.validateOrThrow(badInfo)
        }
    }

    // MARK: - Custom Rule

    @Test("Custom validation rule — domain-specific logic")
    func customRule() {
        // Define a custom rule that requires a genre
        struct GenreRequiredRule: ValidationRule {
            let name = "Genre Required"
            func validate(_ info: AudioFileInfo) -> [ValidationIssue] {
                if info.metadata.genre == nil || info.metadata.genre?.isEmpty == true {
                    return [
                        ValidationIssue(
                            severity: .warning,
                            message: "Genre is recommended for discoverability.")
                    ]
                }
                return []
            }
        }

        // Create validator with only our custom rule
        let validator = AudioValidator(rules: [GenreRequiredRule()])

        // Missing genre → warning
        let noGenre = AudioFileInfo(metadata: AudioMetadata(title: "No Genre"))
        let result1 = validator.validate(noGenre)
        #expect(result1.isValid)  // Warnings don't fail validation
        #expect(result1.warnings.count == 1)
        #expect(result1.warnings[0].message.contains("Genre"))

        // With genre → clean
        var meta = AudioMetadata(title: "Has Genre")
        meta.genre = "Rock"
        let withGenre = AudioFileInfo(metadata: meta)
        let result2 = validator.validate(withGenre)
        #expect(result2.isValid)
        #expect(result2.warnings.isEmpty)
    }

    // MARK: - Auto-Validation

    @Test("Configuration validateBeforeWriting auto-validates on write")
    func autoValidation() throws {
        // Create a config with validation enabled (default)
        let config = Configuration(validateBeforeWriting: true)
        let engine = AudioMarkerEngine(configuration: config)

        // Create a file with a valid tag first
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Test")])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        // Write invalid data — invalid language code triggers validation error
        var badMeta = AudioMetadata()
        badMeta.language = "english"  // Not a valid 3-letter ISO 639-2 code → error
        let badInfo = AudioFileInfo(metadata: badMeta)

        #expect(throws: AudioMarkerError.self) {
            try engine.write(badInfo, to: url)
        }
    }
}
