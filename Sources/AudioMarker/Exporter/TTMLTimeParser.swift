import Foundation

/// Parses TTML time expressions into ``AudioTimestamp``.
///
/// Supports:
/// - **Clock time**: `"HH:MM:SS"`, `"HH:MM:SS.mmm"`, `"HH:MM:SS:frames"`
/// - **Offset time**: `"1h"`, `"30m"`, `"5s"`, `"500ms"`, `"5.5s"`
public struct TTMLTimeParser: Sendable {

    /// Frame rate for SMPTE time codes. Defaults to `nil` (no frame support).
    private let frameRate: Int?

    /// Tick rate for tick-based offsets. Defaults to `nil`.
    private let tickRate: Int?

    /// Creates a TTML time parser.
    /// - Parameters:
    ///   - frameRate: Frame rate for SMPTE time codes. Defaults to `nil`.
    ///   - tickRate: Tick rate for tick-based offsets. Defaults to `nil`.
    public init(frameRate: Int? = nil, tickRate: Int? = nil) {
        self.frameRate = frameRate
        self.tickRate = tickRate
    }

    /// Parses a TTML time expression string.
    /// - Parameter string: The time expression (e.g., `"00:01:30.500"`, `"5s"`, `"500ms"`).
    /// - Returns: The parsed timestamp.
    /// - Throws: ``TTMLParseError/invalidTimeExpression(_:)`` if parsing fails.
    public func parse(_ string: String) throws -> AudioTimestamp {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw TTMLParseError.invalidTimeExpression(string)
        }

        // Try clock time first (contains colons).
        if trimmed.contains(":") {
            return try parseClockTime(trimmed)
        }

        // Try offset time.
        return try parseOffsetTime(trimmed)
    }

    // MARK: - Clock Time

    /// Parses clock time: `HH:MM:SS`, `HH:MM:SS.mmm`, `HH:MM:SS:frames`.
    private func parseClockTime(_ string: String) throws -> AudioTimestamp {
        let parts = string.split(separator: ":", maxSplits: .max, omittingEmptySubsequences: false)
        guard parts.count >= 3 else {
            throw TTMLParseError.invalidTimeExpression(string)
        }

        guard let hours = Double(parts[0]),
            let minutes = Double(parts[1])
        else {
            throw TTMLParseError.invalidTimeExpression(string)
        }

        var seconds: Double

        if parts.count == 3 {
            // HH:MM:SS or HH:MM:SS.mmm
            guard let secs = Double(parts[2]) else {
                throw TTMLParseError.invalidTimeExpression(string)
            }
            seconds = secs
        } else if parts.count == 4 {
            // HH:MM:SS:frames
            guard let secs = Double(parts[2]),
                let frames = Double(parts[3])
            else {
                throw TTMLParseError.invalidTimeExpression(string)
            }
            let fps = Double(frameRate ?? 30)
            seconds = secs + frames / fps
        } else {
            throw TTMLParseError.invalidTimeExpression(string)
        }

        let total = hours * 3600.0 + minutes * 60.0 + seconds
        guard total >= 0 else {
            throw TTMLParseError.invalidTimeExpression(string)
        }
        return AudioTimestamp(timeInterval: total)
    }

    // MARK: - Offset Time

    /// Parses offset time: `1h`, `30m`, `5s`, `500ms`, `5.5s`, `100t`.
    private func parseOffsetTime(_ string: String) throws -> AudioTimestamp {
        // Check for specific unit suffixes.
        if string.hasSuffix("ms") {
            return try parseNumericSuffix(string, suffix: "ms", multiplier: 0.001)
        }
        if string.hasSuffix("h") {
            return try parseNumericSuffix(string, suffix: "h", multiplier: 3600.0)
        }
        if string.hasSuffix("m") {
            return try parseNumericSuffix(string, suffix: "m", multiplier: 60.0)
        }
        if string.hasSuffix("s") {
            return try parseNumericSuffix(string, suffix: "s", multiplier: 1.0)
        }
        if string.hasSuffix("t") {
            let rate = Double(tickRate ?? 1)
            return try parseNumericSuffix(string, suffix: "t", multiplier: 1.0 / rate)
        }

        throw TTMLParseError.invalidTimeExpression(string)
    }

    /// Parses a numeric value followed by a unit suffix.
    private func parseNumericSuffix(
        _ string: String, suffix: String, multiplier: Double
    ) throws -> AudioTimestamp {
        let numericPart = String(string.dropLast(suffix.count))
        guard let value = Double(numericPart) else {
            throw TTMLParseError.invalidTimeExpression(string)
        }
        let seconds = value * multiplier
        guard seconds >= 0 else {
            throw TTMLParseError.invalidTimeExpression(string)
        }
        return AudioTimestamp(timeInterval: seconds)
    }
}
