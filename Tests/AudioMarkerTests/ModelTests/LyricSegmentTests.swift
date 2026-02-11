import Testing

@testable import AudioMarker

@Suite("Lyric Segment")
struct LyricSegmentTests {

    // MARK: - Basic Creation

    @Test("Creates segment with required fields")
    func basicCreation() {
        let segment = LyricSegment(
            startTime: .seconds(1),
            endTime: .seconds(2),
            text: "Hello")
        #expect(segment.startTime == .seconds(1))
        #expect(segment.endTime == .seconds(2))
        #expect(segment.text == "Hello")
        #expect(segment.styleID == nil)
    }

    @Test("Creates segment with styleID")
    func withStyleID() {
        let segment = LyricSegment(
            startTime: .zero,
            endTime: .seconds(1),
            text: "Word",
            styleID: "highlight")
        #expect(segment.styleID == "highlight")
    }

    // MARK: - Hashable / Equatable

    @Test("Equal segments are Equatable")
    func equatable() {
        let s1 = LyricSegment(
            startTime: .seconds(1), endTime: .seconds(2), text: "Hi")
        let s2 = LyricSegment(
            startTime: .seconds(1), endTime: .seconds(2), text: "Hi")
        #expect(s1 == s2)
    }

    @Test("Different segments are not equal")
    func notEqual() {
        let s1 = LyricSegment(
            startTime: .seconds(1), endTime: .seconds(2), text: "Hi")
        let s2 = LyricSegment(
            startTime: .seconds(1), endTime: .seconds(2), text: "Bye")
        #expect(s1 != s2)
    }

    @Test("Equal segments produce same hash")
    func hashable() {
        let s1 = LyricSegment(
            startTime: .zero, endTime: .seconds(1), text: "A", styleID: "s1")
        let s2 = LyricSegment(
            startTime: .zero, endTime: .seconds(1), text: "A", styleID: "s1")
        #expect(s1.hashValue == s2.hashValue)
    }

    @Test("Segments with different styleIDs are not equal")
    func styleIDDifference() {
        let s1 = LyricSegment(
            startTime: .zero, endTime: .seconds(1), text: "A", styleID: "s1")
        let s2 = LyricSegment(
            startTime: .zero, endTime: .seconds(1), text: "A", styleID: "s2")
        #expect(s1 != s2)
    }
}
