import Testing

@testable import AudioMarker

@Suite("TTML Time Parser")
struct TTMLTimeParserTests {

    let parser = TTMLTimeParser()

    // MARK: - Clock Time

    @Test("Parses HH:MM:SS format")
    func clockTimeHHMMSS() throws {
        let timestamp = try parser.parse("01:30:00")
        #expect(timestamp == .seconds(5400))
    }

    @Test("Parses HH:MM:SS.mmm format")
    func clockTimeWithMilliseconds() throws {
        let timestamp = try parser.parse("00:01:30.500")
        #expect(timestamp == .milliseconds(90_500))
    }

    @Test("Parses 00:00:00.000 as zero")
    func clockTimeZero() throws {
        let timestamp = try parser.parse("00:00:00.000")
        #expect(timestamp == .zero)
    }

    @Test("Parses HH:MM:SS:frames with default 30fps")
    func clockTimeWithFrames() throws {
        let timestamp = try parser.parse("00:00:01:15")
        // 1 second + 15/30 = 1.5 seconds
        #expect(timestamp == .milliseconds(1500))
    }

    @Test("Parses HH:MM:SS:frames with custom frame rate")
    func clockTimeWithCustomFrameRate() throws {
        let parser = TTMLTimeParser(frameRate: 25)
        let timestamp = try parser.parse("00:00:01:10")
        // 1 second + 10/25 = 1.4 seconds
        #expect(timestamp == .milliseconds(1400))
    }

    @Test("Parses large clock time")
    func largeClockTime() throws {
        let timestamp = try parser.parse("02:30:45.123")
        // 2*3600 + 30*60 + 45.123 = 9045.123
        #expect(timestamp == .milliseconds(9_045_123))
    }

    // MARK: - Offset Time

    @Test("Parses seconds offset")
    func offsetSeconds() throws {
        let timestamp = try parser.parse("5s")
        #expect(timestamp == .seconds(5))
    }

    @Test("Parses fractional seconds offset")
    func offsetFractionalSeconds() throws {
        let timestamp = try parser.parse("5.5s")
        #expect(timestamp == .milliseconds(5500))
    }

    @Test("Parses milliseconds offset")
    func offsetMilliseconds() throws {
        let timestamp = try parser.parse("500ms")
        #expect(timestamp == .milliseconds(500))
    }

    @Test("Parses hours offset")
    func offsetHours() throws {
        let timestamp = try parser.parse("1h")
        #expect(timestamp == .seconds(3600))
    }

    @Test("Parses minutes offset")
    func offsetMinutes() throws {
        let timestamp = try parser.parse("30m")
        #expect(timestamp == .seconds(1800))
    }

    @Test("Parses ticks offset")
    func offsetTicks() throws {
        let parser = TTMLTimeParser(tickRate: 1000)
        let timestamp = try parser.parse("5000t")
        #expect(timestamp == .seconds(5))
    }

    @Test("Parses 0s as zero")
    func offsetZero() throws {
        let timestamp = try parser.parse("0s")
        #expect(timestamp == .zero)
    }

    // MARK: - Whitespace Handling

    @Test("Trims leading and trailing whitespace")
    func trimWhitespace() throws {
        let timestamp = try parser.parse("  00:01:00.000  ")
        #expect(timestamp == .seconds(60))
    }

    // MARK: - Errors

    @Test("Rejects empty string")
    func emptyStringThrows() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("")
        }
    }

    @Test("Rejects whitespace-only string")
    func whitespaceOnlyThrows() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("   ")
        }
    }

    @Test("Rejects invalid clock time")
    func invalidClockTime() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("abc:def:ghi")
        }
    }

    @Test("Rejects unknown offset unit")
    func unknownOffsetUnit() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("5x")
        }
    }

    @Test("Rejects plain number without unit")
    func plainNumber() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("42")
        }
    }

    @Test("Rejects too few colon-separated parts")
    func tooFewParts() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("01:30")
        }
    }

    @Test("Rejects too many colon-separated parts")
    func tooManyParts() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("01:02:03:04:05")
        }
    }

    @Test("Rejects non-numeric seconds in clock time")
    func nonNumericSeconds() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("00:00:abc")
        }
    }

    @Test("Rejects non-numeric frames in SMPTE time")
    func nonNumericFrames() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("00:00:01:xyz")
        }
    }

    @Test("Rejects non-numeric offset value")
    func nonNumericOffset() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("abcs")
        }
    }

    @Test("Rejects negative offset value")
    func negativeOffset() {
        #expect(throws: TTMLParseError.self) {
            try parser.parse("-5s")
        }
    }
}
