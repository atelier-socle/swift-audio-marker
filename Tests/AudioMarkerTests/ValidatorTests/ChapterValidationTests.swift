import Foundation
import Testing

@testable import AudioMarker

@Suite("Chapter Validation Rules")
struct ChapterValidationTests {

    // MARK: - ChapterOrderRule

    @Test("Chapters in ascending order produce no issues")
    func orderValid() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .seconds(0), title: "A"),
                Chapter(start: .seconds(10), title: "B"),
                Chapter(start: .seconds(20), title: "C")
            ])
        )
        let issues = ChapterOrderRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Chapters out of order produce error with index")
    func orderInvalid() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .seconds(20), title: "B"),
                Chapter(start: .seconds(10), title: "A")
            ])
        )
        let issues = ChapterOrderRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .error)
        #expect(issues[0].context == "chapter[1]")
    }

    @Test("Chapters with same start time produce error")
    func orderDuplicate() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .seconds(10), title: "A"),
                Chapter(start: .seconds(10), title: "B")
            ])
        )
        let issues = ChapterOrderRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .error)
    }

    @Test("Empty chapter list produces no order issues")
    func orderEmpty() {
        let info = AudioFileInfo()
        let issues = ChapterOrderRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Single chapter produces no order issues")
    func orderSingle() {
        let info = AudioFileInfo(
            chapters: ChapterList([Chapter(start: .zero, title: "Only")])
        )
        let issues = ChapterOrderRule().validate(info)
        #expect(issues.isEmpty)
    }

    // MARK: - ChapterOverlapRule

    @Test("Non-overlapping chapters produce no issues")
    func overlapValid() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .seconds(0), title: "A", end: .seconds(10)),
                Chapter(start: .seconds(10), title: "B", end: .seconds(20))
            ])
        )
        let issues = ChapterOverlapRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Overlapping chapters produce error")
    func overlapInvalid() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .seconds(0), title: "A", end: .seconds(15)),
                Chapter(start: .seconds(10), title: "B", end: .seconds(20))
            ])
        )
        let issues = ChapterOverlapRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .error)
        #expect(issues[0].context == "chapter[0]")
    }

    @Test("Chapters without end times produce no overlap issues")
    func overlapNoEnd() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .seconds(0), title: "A"),
                Chapter(start: .seconds(10), title: "B")
            ])
        )
        let issues = ChapterOverlapRule().validate(info)
        #expect(issues.isEmpty)
    }

    // MARK: - ChapterTitleRule

    @Test("Non-empty titles produce no issues")
    func titleValid() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .zero, title: "Introduction"),
                Chapter(start: .seconds(10), title: "Main")
            ])
        )
        let issues = ChapterTitleRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Empty title produces error with index")
    func titleEmpty() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .zero, title: ""),
                Chapter(start: .seconds(10), title: "Valid")
            ])
        )
        let issues = ChapterTitleRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .error)
        #expect(issues[0].context == "chapter[0]")
    }

    @Test("Whitespace-only title produces error with index")
    func titleWhitespace() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .zero, title: "   "),
                Chapter(start: .seconds(10), title: "Valid")
            ])
        )
        let issues = ChapterTitleRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .error)
        #expect(issues[0].context == "chapter[0]")
    }

    // MARK: - ChapterBoundsRule

    @Test("Chapters within duration produce no issues")
    func boundsValid() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .seconds(0), title: "A"),
                Chapter(start: .seconds(50), title: "B")
            ]),
            duration: .seconds(100)
        )
        let issues = ChapterBoundsRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("Chapter start beyond duration produces error")
    func boundsExceeded() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .seconds(0), title: "A"),
                Chapter(start: .seconds(200), title: "B")
            ]),
            duration: .seconds(100)
        )
        let issues = ChapterBoundsRule().validate(info)
        #expect(issues.count == 1)
        #expect(issues[0].severity == .error)
        #expect(issues[0].context == "chapter[1]")
    }

    @Test("Unknown duration skips bounds check")
    func boundsNoDuration() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .seconds(999), title: "A")
            ])
        )
        let issues = ChapterBoundsRule().validate(info)
        #expect(issues.isEmpty)
    }

    // MARK: - ChapterNonNegativeRule

    @Test("Positive start times produce no issues")
    func nonNegativeValid() {
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: .zero, title: "A"),
                Chapter(start: .seconds(10), title: "B")
            ])
        )
        let issues = ChapterNonNegativeRule().validate(info)
        #expect(issues.isEmpty)
    }

    @Test("AudioTimestamp clamps negative to zero, so no issues")
    func nonNegativeClamped() {
        // AudioTimestamp clamps negatives to 0, so this should produce no issues.
        let info = AudioFileInfo(
            chapters: ChapterList([
                Chapter(start: AudioTimestamp(timeInterval: -5), title: "A")
            ])
        )
        let issues = ChapterNonNegativeRule().validate(info)
        #expect(issues.isEmpty)
    }
}
