import Testing

@testable import AudioMarker

@Suite("AudioTimestamp")
struct AudioTimestampTests {

    // MARK: - Factory methods

    @Test("zero has zero time interval")
    func zero() {
        let timestamp = AudioTimestamp.zero
        #expect(timestamp.timeInterval == 0)
    }

    @Test("seconds factory creates correct time interval")
    func seconds() {
        let timestamp = AudioTimestamp.seconds(90.5)
        #expect(timestamp.timeInterval == 90.5)
    }

    @Test("milliseconds factory creates correct time interval")
    func milliseconds() {
        let timestamp = AudioTimestamp.milliseconds(1500)
        #expect(timestamp.timeInterval == 1.5)
    }

    @Test("milliseconds with zero creates zero interval")
    func millisecondsZero() {
        let timestamp = AudioTimestamp.milliseconds(0)
        #expect(timestamp.timeInterval == 0)
    }

    // MARK: - String parsing

    @Test(
        "Parses valid timestamp strings",
        arguments: [
            ("01:30:00", 5400.0),
            ("01:30:00.500", 5400.5),
            ("05:30", 330.0),
            ("05:30.250", 330.25),
            ("00:00:00", 0.0),
            ("00:00:00.000", 0.0),
            ("00:00", 0.0),
            ("10:00:00", 36000.0)
        ] as [(String, Double)]
    )
    func parseValidStrings(input: String, expected: Double) throws {
        let timestamp = try AudioTimestamp(string: input)
        #expect(abs(timestamp.timeInterval - expected) < 0.001)
    }

    @Test("Parsing rejects invalid format")
    func parseInvalidFormat() {
        #expect(throws: AudioTimestampError.self) {
            try AudioTimestamp(string: "invalid")
        }
    }

    @Test("Parsing rejects single component")
    func parseSingleComponent() {
        #expect(throws: AudioTimestampError.self) {
            try AudioTimestamp(string: "123")
        }
    }

    @Test("Parsing rejects non-numeric components")
    func parseNonNumeric() {
        #expect(throws: AudioTimestampError.self) {
            try AudioTimestamp(string: "ab:cd")
        }
    }

    @Test("Parsing rejects empty string")
    func parseEmpty() {
        #expect(throws: AudioTimestampError.self) {
            try AudioTimestamp(string: "")
        }
    }

    // MARK: - Formatting

    @Test("description formats as HH:MM:SS.mmm")
    func descriptionFormat() {
        let timestamp = AudioTimestamp.seconds(5400.5)
        #expect(timestamp.description == "01:30:00.500")
    }

    @Test("description for zero")
    func descriptionZero() {
        #expect(AudioTimestamp.zero.description == "00:00:00.000")
    }

    @Test("shortDescription omits millis when zero")
    func shortDescriptionNoMillis() {
        let timestamp = AudioTimestamp.seconds(5400)
        #expect(timestamp.shortDescription == "01:30:00")
    }

    @Test("shortDescription includes millis when non-zero")
    func shortDescriptionWithMillis() {
        let timestamp = AudioTimestamp.seconds(5400.5)
        #expect(timestamp.shortDescription == "01:30:00.500")
    }

    // MARK: - Comparable

    @Test("Ordering works correctly")
    func ordering() {
        let a = AudioTimestamp.seconds(10)
        let b = AudioTimestamp.seconds(20)
        let c = AudioTimestamp.seconds(10)

        #expect(a < b)
        #expect(b > a)
        #expect(a == c)
        #expect(a <= c)
        #expect(a >= c)
    }

    // MARK: - Edge cases

    @Test("Clamps negative time interval to zero")
    func negativeClampedToZero() {
        let timestamp = AudioTimestamp(timeInterval: -5.0)
        #expect(timestamp.timeInterval == 0)
    }

    @Test("Handles very large values")
    func veryLargeValue() {
        let timestamp = AudioTimestamp.seconds(360_000)  // 100 hours
        #expect(timestamp.timeInterval == 360_000)
        #expect(timestamp.description == "100:00:00.000")
    }

    // MARK: - Error descriptions

    @Test("invalidFormat error provides meaningful description")
    func invalidFormatErrorDescription() {
        let error = AudioTimestampError.invalidFormat("bad")
        #expect(error.errorDescription?.contains("bad") == true)
    }

    @Test("negativeValue error provides meaningful description")
    func negativeValueErrorDescription() {
        let error = AudioTimestampError.negativeValue(-1.0)
        #expect(error.errorDescription?.contains("-1.0") == true)
    }
}
