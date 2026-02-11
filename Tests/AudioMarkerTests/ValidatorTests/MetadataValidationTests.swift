import Foundation
import Testing

@testable import AudioMarker

@Suite("Metadata Validation Rules")
struct MetadataValidationTests {

    // MARK: - MetadataTitleRule

    @Test("Title present produces no issues")
    func titlePresent() {
        let info = AudioFileInfo(metadata: AudioMetadata(title: "My Track"))
        let issues = MetadataTitleRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Nil title produces warning")
    func titleNil() {
        let info = AudioFileInfo(metadata: AudioMetadata())
        let issues = MetadataTitleRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .warning)
        #expect(issues[0].context == "metadata.title")
    }

    @Test("Empty string title produces warning")
    func titleEmpty() {
        let info = AudioFileInfo(metadata: AudioMetadata(title: ""))
        let issues = MetadataTitleRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .warning)
    }

    @Test("Whitespace-only title produces warning")
    func titleWhitespace() {
        let info = AudioFileInfo(metadata: AudioMetadata(title: "   "))
        let issues = MetadataTitleRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .warning)
    }

    // MARK: - ArtworkFormatRule

    @Test("Valid artwork format produces no issues")
    func artworkValid() {
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        let artwork = Artwork(data: jpegData, format: .jpeg)
        let info = AudioFileInfo(metadata: AudioMetadata(artwork: artwork))
        let issues = ArtworkFormatRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("No artwork produces no issues")
    func artworkNone() {
        let info = AudioFileInfo(metadata: AudioMetadata())
        let issues = ArtworkFormatRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Artwork with unrecognized data produces error")
    func artworkUnrecognized() {
        let badData = Data([0x00, 0x01, 0x02, 0x03])
        let artwork = Artwork(data: badData, format: .jpeg)
        let info = AudioFileInfo(metadata: AudioMetadata(artwork: artwork))
        let issues = ArtworkFormatRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .error)
        #expect(issues[0].context == "metadata.artwork")
    }

    // MARK: - MetadataYearRule

    @Test("Year in range produces no issues")
    func yearValid() {
        var metadata = AudioMetadata()
        metadata.year = 2024
        let info = AudioFileInfo(metadata: metadata)
        let issues = MetadataYearRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Nil year produces no issues")
    func yearNil() {
        let info = AudioFileInfo()
        let issues = MetadataYearRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Year below 1900 produces warning")
    func yearTooLow() {
        var metadata = AudioMetadata()
        metadata.year = 1800
        let info = AudioFileInfo(metadata: metadata)
        let issues = MetadataYearRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .warning)
    }

    @Test("Year above 2100 produces warning")
    func yearTooHigh() {
        var metadata = AudioMetadata()
        metadata.year = 2200
        let info = AudioFileInfo(metadata: metadata)
        let issues = MetadataYearRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .warning)
    }

    @Test("Year at boundary 1900 produces no issues")
    func yearLowerBound() {
        var metadata = AudioMetadata()
        metadata.year = 1900
        let info = AudioFileInfo(metadata: metadata)
        let issues = MetadataYearRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Year at boundary 2100 produces no issues")
    func yearUpperBound() {
        var metadata = AudioMetadata()
        metadata.year = 2100
        let info = AudioFileInfo(metadata: metadata)
        let issues = MetadataYearRule().validate(info)
        #expect(issues.isEmpty)
    }

    // MARK: - LanguageCodeRule

    @Test("Valid 3-letter language code produces no issues")
    func languageValid() {
        var metadata = AudioMetadata()
        metadata.language = "eng"
        let info = AudioFileInfo(metadata: metadata)
        let issues = LanguageCodeRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Nil language produces no issues")
    func languageNil() {
        let info = AudioFileInfo()
        let issues = LanguageCodeRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("2-letter code produces error")
    func languageTooShort() {
        var metadata = AudioMetadata()
        metadata.language = "en"
        let info = AudioFileInfo(metadata: metadata)
        let issues = LanguageCodeRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .error)
    }

    @Test("Non-letter code produces error")
    func languageNonLetter() {
        var metadata = AudioMetadata()
        metadata.language = "e1g"
        let info = AudioFileInfo(metadata: metadata)
        let issues = LanguageCodeRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .error)
    }

    // MARK: - RatingRangeRule

    @Test("Rating within valid range produces no issues")
    func ratingValid() {
        var metadata = AudioMetadata()
        metadata.rating = 128
        let info = AudioFileInfo(metadata: metadata)
        let issues = RatingRangeRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Nil rating produces no issues")
    func ratingNil() {
        let info = AudioFileInfo()
        let issues = RatingRangeRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Rating 0 produces warning about unrated POPM")
    func ratingZero() {
        var metadata = AudioMetadata()
        metadata.rating = 0
        let info = AudioFileInfo(metadata: metadata)
        let issues = RatingRangeRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .warning)
        #expect(issues[0].context == "metadata.rating")
        #expect(issues[0].message.contains("unrated"))
    }

    @Test("Rating 255 produces no issues")
    func ratingMax() {
        var metadata = AudioMetadata()
        metadata.rating = 255
        let info = AudioFileInfo(metadata: metadata)
        let issues = RatingRangeRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Rating 1 produces no issues")
    func ratingMin() {
        var metadata = AudioMetadata()
        metadata.rating = 1
        let info = AudioFileInfo(metadata: metadata)
        let issues = RatingRangeRule().validate(info)
        #expect(issues.isEmpty)
    }
}
