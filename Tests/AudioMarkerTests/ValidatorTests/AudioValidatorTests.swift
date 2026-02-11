import Foundation
import Testing

@testable import AudioMarker

@Suite("Audio Validator")
struct AudioValidatorTests {

    // MARK: - Default rules

    @Test("Default rules contain all 10 built-in rules")
    func defaultRulesCount() {
        let validator = AudioValidator()
        #expect(validator.rules.count == 10)
    }

    @Test("Default rules include all chapter rules")
    func defaultRulesChapter() {
        let names = AudioValidator.defaultRules.map(\.name)
        #expect(names.contains("Chapter Order"))
        #expect(names.contains("Chapter Overlap"))
        #expect(names.contains("Chapter Title"))
        #expect(names.contains("Chapter Bounds"))
        #expect(names.contains("Chapter Non-Negative"))
    }

    @Test("Default rules include all metadata rules")
    func defaultRulesMetadata() {
        let names = AudioValidator.defaultRules.map(\.name)
        #expect(names.contains("Metadata Title"))
        #expect(names.contains("Artwork Format"))
        #expect(names.contains("Metadata Year"))
        #expect(names.contains("Language Code"))
        #expect(names.contains("Rating Range"))
    }

    // MARK: - Valid file

    @Test("Valid file produces isValid true with no errors")
    func validFile() {
        let info = AudioFileInfo(
            metadata: AudioMetadata(title: "Podcast Episode 1"),
            chapters: ChapterList([
                Chapter(start: .seconds(0), title: "Intro"),
                Chapter(start: .seconds(60), title: "Main"),
                Chapter(start: .seconds(120), title: "Outro")
            ]),
            duration: .seconds(180)
        )
        let result = AudioValidator().validate(info)
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
    }

    // MARK: - Invalid file

    @Test("Invalid file produces errors and warnings")
    func invalidFile() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .seconds(20), title: "B"),
                Chapter(start: .seconds(10), title: "")
            ]),
            duration: .seconds(100)
        )
        let result = AudioValidator().validate(info)
        #expect(!result.isValid)
        #expect(!result.errors.isEmpty)
        #expect(!result.warnings.isEmpty)
    }

    // MARK: - Custom rules

    @Test("Validator works with custom rule set")
    func customRules() {
        let validator = AudioValidator(rules: [ChapterTitleRule()])
        let info = AudioFileInfo(
            chapters: ChapterList([Chapter(start: .zero, title: "Valid")])
        )
        let result = validator.validate(info)
        #expect(result.isValid)
        #expect(result.issues.isEmpty)
    }

    @Test("Validator with empty rules produces valid result")
    func emptyRules() {
        let validator = AudioValidator(rules: [])
        let result = validator.validate(AudioFileInfo())
        #expect(result.isValid)
        #expect(result.issues.isEmpty)
    }

    // MARK: - Empty file

    @Test("Default AudioFileInfo does not crash and produces expected result")
    func emptyFile() {
        let result = AudioValidator().validate(AudioFileInfo())
        // No errors expected (empty chapters are fine), but missing title → warning.
        #expect(result.isValid)
        #expect(!result.warnings.isEmpty)
    }

    // MARK: - ValidationResult helpers

    @Test("ValidationResult.valid has no issues")
    func validResult() {
        let result = ValidationResult.valid
        #expect(result.isValid)
        #expect(result.issues.isEmpty)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.isEmpty)
    }

    @Test("ValidationResult separates errors and warnings")
    func resultSeparation() {
        let issues = [
            ValidationIssue(severity: .error, message: "Error 1"),
            ValidationIssue(severity: .warning, message: "Warning 1"),
            ValidationIssue(severity: .error, message: "Error 2")
        ]
        let result = ValidationResult(issues: issues)
        #expect(!result.isValid)
        #expect(result.errors.count == 2)
        #expect(result.warnings.count == 1)
    }

    @Test("ValidationResult with only warnings is valid")
    func warningsOnly() {
        let issues = [
            ValidationIssue(severity: .warning, message: "W1"),
            ValidationIssue(severity: .warning, message: "W2")
        ]
        let result = ValidationResult(issues: issues)
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.count == 2)
    }

    // MARK: - ValidationIssue description

    @Test("ValidationIssue description includes severity and message")
    func issueDescription() {
        let error = ValidationIssue(severity: .error, message: "Something wrong")
        #expect(error.description.contains("ERROR"))
        #expect(error.description.contains("Something wrong"))

        let warning = ValidationIssue(severity: .warning, message: "Check this")
        #expect(warning.description.contains("WARNING"))
    }

    @Test("ValidationIssue description includes context when present")
    func issueDescriptionWithContext() {
        let issue = ValidationIssue(severity: .error, message: "Bad", context: "chapter[0]")
        #expect(issue.description.contains("chapter[0]"))
    }

    @Test("ValidationIssue description omits context when nil")
    func issueDescriptionWithoutContext() {
        let issue = ValidationIssue(severity: .warning, message: "Hmm")
        #expect(!issue.description.contains("("))
    }
}
