import Foundation
import Testing

@testable import AudioMarker

@Suite("Chapter")
struct ChapterTests {

    // MARK: - Basic creation

    @Test("Creates with required fields only")
    func basicCreation() {
        let chapter = Chapter(start: .seconds(10), title: "Introduction")
        #expect(chapter.title == "Introduction")
        #expect(chapter.start == AudioTimestamp.seconds(10))
        #expect(chapter.end == nil)
        #expect(chapter.url == nil)
        #expect(chapter.artwork == nil)
    }

    @Test("Creates with all optional fields")
    func fullCreation() {
        let artwork = Artwork(data: Data([0xFF, 0xD8, 0xFF]), format: .jpeg)
        let chapterURL = URL(string: "https://example.com")
        let chapter = Chapter(
            start: .seconds(0),
            title: "Prologue",
            end: .seconds(60),
            url: chapterURL,
            artwork: artwork
        )
        #expect(chapter.title == "Prologue")
        #expect(chapter.start == .zero)
        #expect(chapter.end == .seconds(60))
        #expect(chapter.url == chapterURL)
        #expect(chapter.artwork == artwork)
    }

    // MARK: - ID generation

    @Test("Generates unique IDs")
    func uniqueIDs() {
        let a = Chapter(start: .zero, title: "A")
        let b = Chapter(start: .zero, title: "A")
        #expect(a.id != b.id)
    }

    // MARK: - Hashable and Equatable

    @Test("Same chapter has consistent id")
    func identifiable() {
        let chapter = Chapter(start: .seconds(10), title: "Test")
        #expect(chapter.id == chapter.id)
    }

    @Test("Different chapters are not equal")
    func notEqual() {
        let a = Chapter(start: .zero, title: "A")
        let b = Chapter(start: .zero, title: "A")
        #expect(a != b)
    }
}
