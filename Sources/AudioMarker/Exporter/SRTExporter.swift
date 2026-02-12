import Foundation

/// Parses and exports synchronized lyrics in SubRip (SRT) format.
///
/// SRT is the most widely used subtitle format. Each cue has a sequence number,
/// timestamps with commas for milliseconds (`HH:MM:SS,mmm`), and text content.
///
/// ```
/// 1
/// 00:00:05,000 --> 00:00:08,500
/// Welcome to the show
///
/// 2
/// 00:00:10,000 --> 00:00:14,000
/// Feel the music
/// ```
public enum SRTExporter: Sendable {

    // MARK: - Export

    /// Exports synchronized lyrics to SRT format.
    ///
    /// When multiple ``SynchronizedLyrics`` are provided, all lines are merged
    /// and sorted by time. The end time of each cue is computed from the next
    /// cue's start time or from `audioDuration` for the last cue.
    /// - Parameters:
    ///   - lyrics: The synchronized lyrics to export.
    ///   - audioDuration: Optional total audio duration for the last cue's end time.
    /// - Returns: An SRT-formatted string.
    public static func export(
        _ lyrics: [SynchronizedLyrics],
        audioDuration: AudioTimestamp? = nil
    ) -> String {
        let allLines = lyrics.flatMap(\.lines).sorted { $0.time < $1.time }
        guard !allLines.isEmpty else { return "" }

        var result = ""

        for (index, line) in allLines.enumerated() {
            let endTime: AudioTimestamp
            if index + 1 < allLines.count {
                endTime = allLines[index + 1].time
            } else if let duration = audioDuration {
                endTime = duration
            } else {
                endTime = AudioTimestamp(timeInterval: line.time.timeInterval + 5.0)
            }

            if index > 0 { result += "\n" }
            result += "\(index + 1)\n"
            result += "\(formatTimestamp(line.time)) --> \(formatTimestamp(endTime))\n"
            result += "\(line.text)\n"
        }

        return result
    }

    // MARK: - Parse

    /// Parses an SRT string into synchronized lyrics.
    /// - Parameters:
    ///   - string: The SRT content to parse.
    ///   - language: ISO 639-2 language code. Defaults to `"und"`.
    /// - Returns: A ``SynchronizedLyrics`` with the parsed cues.
    /// - Throws: ``ExportError/invalidData(_:)`` if no valid cues are found.
    public static func parse(_ string: String, language: String = "und") throws -> SynchronizedLyrics {
        let rawLines = string.components(separatedBy: .newlines)
        let lines = parseCues(from: rawLines)

        guard !lines.isEmpty else {
            throw ExportError.invalidData("No valid cues found in SRT input.")
        }

        return SynchronizedLyrics(language: language, lines: lines)
    }

    // MARK: - Private

    /// Parses cues from raw SRT lines.
    private static func parseCues(from rawLines: [String]) -> [LyricLine] {
        var lines: [LyricLine] = []
        var index = 0

        while index < rawLines.count {
            // Skip blank lines.
            let trimmed = rawLines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }

            // Expect a sequence number (digits only).
            guard trimmed.allSatisfy(\.isWholeNumber) else {
                index += 1
                continue
            }
            index += 1

            // Expect a timestamp line.
            guard index < rawLines.count else { break }
            let tsLine = rawLines[index].trimmingCharacters(in: .whitespaces)
            guard tsLine.contains("-->") else {
                index += 1
                continue
            }

            guard let startTime = parseTimestampLine(tsLine) else {
                index += 1
                continue
            }
            index += 1

            // Collect text lines until blank line.
            var textParts: [String] = []
            while index < rawLines.count {
                let textTrimmed = rawLines[index].trimmingCharacters(in: .whitespaces)
                if textTrimmed.isEmpty { break }
                textParts.append(stripHTMLTags(textTrimmed))
                index += 1
            }

            if !textParts.isEmpty {
                let text = textParts.joined(separator: " ")
                lines.append(LyricLine(time: startTime, text: text))
            }
        }

        return lines
    }

    /// Parses the start timestamp from an SRT timestamp line.
    ///
    /// Format: `HH:MM:SS,mmm --> HH:MM:SS,mmm`.
    private static func parseTimestampLine(_ line: String) -> AudioTimestamp? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else { return nil }
        let startStr = parts[0].trimmingCharacters(in: .whitespaces)
        return parseTimestamp(startStr)
    }

    /// Parses a single SRT timestamp (`HH:MM:SS,mmm`).
    private static func parseTimestamp(_ string: String) -> AudioTimestamp? {
        // SRT uses commas: HH:MM:SS,mmm
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        let components = normalized.split(separator: ":")
        guard components.count == 3 else { return nil }

        guard let hours = Int(components[0]) else { return nil }
        guard let minutes = Int(components[1]) else { return nil }

        let secComponents = components[2].split(separator: ".", maxSplits: 1)
        guard secComponents.count == 2 else { return nil }
        guard let seconds = Int(secComponents[0]) else { return nil }
        guard let millis = Int(secComponents[1]) else { return nil }

        let normalizedMillis: Int
        switch secComponents[1].count {
        case 1: normalizedMillis = millis * 100
        case 2: normalizedMillis = millis * 10
        default: normalizedMillis = millis
        }

        let totalMs = hours * 3_600_000 + minutes * 60_000 + seconds * 1000 + normalizedMillis
        return .milliseconds(totalMs)
    }

    /// Formats a timestamp as `HH:MM:SS,mmm` (SRT uses commas).
    private static func formatTimestamp(_ timestamp: AudioTimestamp) -> String {
        let totalMs = Int(round(timestamp.timeInterval * 1000))
        let hours = totalMs / 3_600_000
        let minutes = (totalMs % 3_600_000) / 60_000
        let seconds = (totalMs % 60_000) / 1000
        let millis = totalMs % 1000
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, millis)
    }

    /// Strips basic HTML tags from text.
    private static func stripHTMLTags(_ text: String) -> String {
        var result = text
        let tagPattern = "</?[a-zA-Z][^>]*>"
        if let regex = try? NSRegularExpression(pattern: tagPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return result
    }
}
