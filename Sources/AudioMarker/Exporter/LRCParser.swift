import Foundation

/// Parses and exports synchronized lyrics in LRC format.
///
/// LRC is a simple text format for synchronized lyrics where each line is
/// prefixed with a timestamp in the form `[MM:SS.xx]` or `[MM:SS.xxx]`.
///
/// Metadata lines (e.g., `[ti:Title]`) and blank lines are ignored during parsing.
public enum LRCParser: Sendable {

    // MARK: - Parse

    /// Parses an LRC string into synchronized lyrics.
    /// - Parameters:
    ///   - string: The LRC content to parse.
    ///   - language: ISO 639-2 language code. Defaults to `"und"` (undetermined).
    /// - Returns: A ``SynchronizedLyrics`` with the parsed lines sorted by time.
    /// - Throws: ``ExportError/invalidData(_:)`` if no valid timestamped lines are found.
    public static func parse(_ string: String, language: String = "und") throws -> SynchronizedLyrics {
        var lines: [LyricLine] = []

        for rawLine in string.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let lyricLine = parseLine(trimmed) else { continue }
            lines.append(lyricLine)
        }

        guard !lines.isEmpty else {
            throw ExportError.invalidData("no valid timestamped lines found in LRC input")
        }

        lines.sort { $0.time < $1.time }

        return SynchronizedLyrics(language: language, lines: lines)
    }

    // MARK: - Export

    /// Exports synchronized lyrics to LRC format.
    /// - Parameter lyrics: The synchronized lyrics to export.
    /// - Returns: An LRC-formatted string.
    public static func export(_ lyrics: SynchronizedLyrics) -> String {
        lyrics.lines.map { line in
            let totalMs = Int(round(line.time.timeInterval * 1000))
            let minutes = totalMs / 60_000
            let seconds = (totalMs % 60_000) / 1000
            let centiseconds = (totalMs % 1000) / 10
            return String(format: "[%02d:%02d.%02d]%@", minutes, seconds, centiseconds, line.text)
        }
        .joined(separator: "\n")
    }

    // MARK: - Private

    /// Attempts to parse a single LRC line into a ``LyricLine``.
    ///
    /// Expected format: `[MM:SS.ff]text` where `ff` is 2 or 3 fractional digits.
    /// Returns `nil` for metadata lines (e.g., `[ti:Title]`) or non-matching lines.
    private static func parseLine(_ line: String) -> LyricLine? {
        guard line.hasPrefix("[") else { return nil }

        guard let closeBracket = line.firstIndex(of: "]") else { return nil }

        let inner = line[line.index(after: line.startIndex)..<closeBracket]

        // Skip metadata lines: [ti:Title], [ar:Artist], etc.
        // Metadata tags start with letters followed by a colon, and have no dot.
        if let first = inner.first, first.isLetter && inner.contains(":") && !inner.contains(".") {
            return nil
        }

        // Parse MM:SS.ff or MM:SS.fff
        let parts = inner.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        guard let minutes = Int(parts[0]) else { return nil }

        let secondsPart = parts[1]
        let secondsComponents = secondsPart.split(separator: ".", maxSplits: 1)
        guard secondsComponents.count == 2 else { return nil }

        guard let seconds = Int(secondsComponents[0]) else { return nil }

        let fractionalStr = secondsComponents[1]
        guard fractionalStr.count == 2 || fractionalStr.count == 3 else { return nil }
        guard let fractional = Int(fractionalStr) else { return nil }

        // 2-digit → centiseconds (×10 to get ms), 3-digit → milliseconds
        let milliseconds: Int
        if fractionalStr.count == 2 {
            milliseconds = fractional * 10
        } else {
            milliseconds = fractional
        }

        let totalMs = minutes * 60_000 + seconds * 1000 + milliseconds
        let timestamp = AudioTimestamp.milliseconds(totalMs)
        let text = String(line[line.index(after: closeBracket)...])

        return LyricLine(time: timestamp, text: text)
    }
}
