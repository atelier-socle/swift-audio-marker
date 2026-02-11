import Foundation

// MARK: - AudioTimestampError

/// Errors that can occur when parsing an ``AudioTimestamp`` from a string.
public enum AudioTimestampError: Error, LocalizedError, Sendable, Hashable {
    /// The string does not match any supported timestamp format.
    case invalidFormat(String)
    /// The parsed time interval is negative.
    case negativeValue(Double)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let string):
            return "Invalid timestamp format: \"\(string)\". Expected HH:MM:SS, HH:MM:SS.mmm, MM:SS, or MM:SS.mmm."
        case .negativeValue(let value):
            return "Timestamp value must be non-negative, got \(value)."
        }
    }
}

// MARK: - AudioTimestamp

/// Represents an audio timestamp with millisecond precision.
public struct AudioTimestamp: Sendable, Hashable, Comparable, CustomStringConvertible {

    /// The time interval in seconds.
    public let timeInterval: TimeInterval

    // MARK: - Initializers

    /// Creates a timestamp from a time interval in seconds.
    /// - Parameter timeInterval: The time in seconds (must be non-negative).
    public init(timeInterval: TimeInterval) {
        self.timeInterval = max(0, timeInterval)
    }

    /// Creates a timestamp by parsing a human-readable string.
    ///
    /// Supported formats:
    /// - `"HH:MM:SS"` — e.g. `"01:30:00"`
    /// - `"HH:MM:SS.mmm"` — e.g. `"01:30:00.500"`
    /// - `"MM:SS"` — e.g. `"05:30"`
    /// - `"MM:SS.mmm"` — e.g. `"05:30.250"`
    ///
    /// - Parameter string: The timestamp string to parse.
    /// - Throws: ``AudioTimestampError/invalidFormat(_:)`` or ``AudioTimestampError/negativeValue(_:)``.
    public init(string: String) throws {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        let parts = trimmed.split(separator: ":", maxSplits: .max, omittingEmptySubsequences: false)

        let interval: TimeInterval

        switch parts.count {
        case 2:
            // MM:SS or MM:SS.mmm
            guard let minutes = Double(parts[0]),
                let seconds = Double(parts[1])
            else {
                throw AudioTimestampError.invalidFormat(string)
            }
            interval = minutes * 60.0 + seconds

        case 3:
            // HH:MM:SS or HH:MM:SS.mmm
            guard let hours = Double(parts[0]),
                let minutes = Double(parts[1]),
                let seconds = Double(parts[2])
            else {
                throw AudioTimestampError.invalidFormat(string)
            }
            interval = hours * 3600.0 + minutes * 60.0 + seconds

        default:
            throw AudioTimestampError.invalidFormat(string)
        }

        guard interval >= 0 else {
            throw AudioTimestampError.negativeValue(interval)
        }

        self.timeInterval = interval
    }

    // MARK: - Factories

    /// A timestamp at the very beginning (0 seconds).
    public static let zero = AudioTimestamp(timeInterval: 0)

    /// Creates a timestamp from a value in seconds.
    /// - Parameter value: Time in seconds.
    /// - Returns: An ``AudioTimestamp`` at the given time.
    public static func seconds(_ value: Double) -> AudioTimestamp {
        AudioTimestamp(timeInterval: value)
    }

    /// Creates a timestamp from a value in milliseconds.
    /// - Parameter value: Time in milliseconds.
    /// - Returns: An ``AudioTimestamp`` at the given time.
    public static func milliseconds(_ value: Int) -> AudioTimestamp {
        AudioTimestamp(timeInterval: Double(value) / 1000.0)
    }

    // MARK: - Formatting

    /// The timestamp formatted as `"HH:MM:SS.mmm"`.
    public var description: String {
        let totalMilliseconds = Int(round(timeInterval * 1000))
        let hours = totalMilliseconds / 3_600_000
        let minutes = (totalMilliseconds % 3_600_000) / 60_000
        let seconds = (totalMilliseconds % 60_000) / 1000
        let millis = totalMilliseconds % 1000
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, millis)
    }

    /// The timestamp formatted as `"HH:MM:SS"` when milliseconds are zero,
    /// or `"HH:MM:SS.mmm"` otherwise.
    public var shortDescription: String {
        let totalMilliseconds = Int(round(timeInterval * 1000))
        let millis = totalMilliseconds % 1000
        if millis == 0 {
            let hours = totalMilliseconds / 3_600_000
            let minutes = (totalMilliseconds % 3_600_000) / 60_000
            let seconds = (totalMilliseconds % 60_000) / 1000
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return description
    }

    // MARK: - Comparable

    public static func < (lhs: AudioTimestamp, rhs: AudioTimestamp) -> Bool {
        lhs.timeInterval < rhs.timeInterval
    }
}
