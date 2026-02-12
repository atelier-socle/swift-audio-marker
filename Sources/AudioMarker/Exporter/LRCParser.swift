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
    ///
    /// If the LRC contains a `[la:xxx]` metadata tag and no explicit language
    /// is provided (i.e., the default `"und"` is used), the embedded language
    /// code is used instead.
    /// - Parameters:
    ///   - string: The LRC content to parse.
    ///   - language: ISO 639-2 language code. Defaults to `"und"` (undetermined).
    /// - Returns: A ``SynchronizedLyrics`` with the parsed lines sorted by time.
    /// - Throws: ``ExportError/invalidData(_:)`` if no valid timestamped lines are found.
    public static func parse(_ string: String, language: String = "und") throws -> SynchronizedLyrics {
        var lines: [LyricLine] = []
        var embeddedLanguage: String?

        for rawLine in string.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let lang = parseLanguageTag(trimmed) {
                embeddedLanguage = lang
                continue
            }
            guard let lyricLine = parseLine(trimmed) else { continue }
            lines.append(lyricLine)
        }

        guard !lines.isEmpty else {
            throw ExportError.invalidData("no valid timestamped lines found in LRC input")
        }

        lines.sort { $0.time < $1.time }

        let effectiveLanguage =
            (language == "und")
            ? (embeddedLanguage ?? language) : language
        return SynchronizedLyrics(language: effectiveLanguage, lines: lines)
    }

    // MARK: - Export

    /// Exports synchronized lyrics to LRC format.
    ///
    /// If the language is not `"und"`, a `[la:xxx]` metadata tag is included
    /// at the beginning so the language survives a round-trip.
    /// - Parameter lyrics: The synchronized lyrics to export.
    /// - Returns: An LRC-formatted string.
    public static func export(_ lyrics: SynchronizedLyrics) -> String {
        var result: [String] = []
        if lyrics.language != "und" {
            result.append("[la:\(lyrics.language)]")
        }
        for line in lyrics.lines {
            let totalMs = Int(round(line.time.timeInterval * 1000))
            let minutes = totalMs / 60_000
            let seconds = (totalMs % 60_000) / 1000
            let centiseconds = (totalMs % 1000) / 10
            result.append(
                String(format: "[%02d:%02d.%02d]%@", minutes, seconds, centiseconds, line.text))
        }
        return result.joined(separator: "\n")
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

    /// Parses a `[la:xxx]` language metadata tag from an LRC line.
    /// - Parameter line: A trimmed LRC line.
    /// - Returns: The language code, or `nil` if not a language tag.
    private static func parseLanguageTag(_ line: String) -> String? {
        guard line.hasPrefix("[la:") && line.hasSuffix("]") else { return nil }
        let code = String(line.dropFirst(4).dropLast(1))
        return code.isEmpty ? nil : code
    }
}
