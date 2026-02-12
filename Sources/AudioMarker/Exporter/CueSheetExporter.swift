import Foundation

/// Exports and imports chapters in Cue Sheet format.
///
/// Cue Sheets describe the track structure of a CD audio disc. Timestamps use
/// the `MM:SS:FF` format where `FF` represents CD frames (1/75th of a second).
///
/// ```
/// TITLE "Album Name"
/// PERFORMER "Artist"
/// FILE "audio.mp3" MP3
///   TRACK 01 AUDIO
///     TITLE "Introduction"
///     INDEX 01 00:00:00
///   TRACK 02 AUDIO
///     TITLE "First Song"
///     INDEX 01 01:30:00
/// ```
public enum CueSheetExporter: Sendable {

    // MARK: - Export

    /// Exports chapters to Cue Sheet format.
    /// - Parameters:
    ///   - chapters: The chapters to export.
    ///   - metadata: Optional audio metadata for global TITLE and PERFORMER.
    ///   - audioFilename: Optional audio filename for the FILE directive.
    /// - Returns: A Cue Sheet string.
    public static func export(
        _ chapters: ChapterList,
        metadata: AudioMetadata? = nil,
        audioFilename: String? = nil
    ) -> String {
        var output = ""

        if let title = metadata?.title {
            output += "TITLE \"\(escapeCueString(title))\"\n"
        }
        if let artist = metadata?.artist {
            output += "PERFORMER \"\(escapeCueString(artist))\"\n"
        }

        let filename = audioFilename ?? "audio.mp3"
        let ext = (filename as NSString).pathExtension.uppercased()
        let fileType = ext == "WAV" ? "WAVE" : ext.isEmpty ? "MP3" : ext
        output += "FILE \"\(escapeCueString(filename))\" \(fileType)\n"

        for (index, chapter) in chapters.enumerated() {
            let trackNumber = String(format: "%02d", index + 1)
            output += "  TRACK \(trackNumber) AUDIO\n"
            output += "    TITLE \"\(escapeCueString(chapter.title))\"\n"
            output += "    INDEX 01 \(formatCueTimestamp(chapter.start))\n"
        }

        return output
    }

    // MARK: - Parse

    /// Parses a Cue Sheet string into chapters.
    /// - Parameter string: The Cue Sheet content to parse.
    /// - Returns: A ``ChapterList`` with the parsed tracks.
    /// - Throws: ``ExportError/invalidData(_:)`` if no valid tracks are found.
    public static func parse(_ string: String) throws -> ChapterList {
        let rawLines = string.components(separatedBy: .newlines)
        var chapters: [Chapter] = []
        var currentTitle: String?

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("REM ") || trimmed.isEmpty {
                continue
            }

            if let title = extractQuotedValue(from: trimmed, key: "TITLE") {
                // Track-level TITLE overrides; we'll use the most recent one.
                currentTitle = title
                continue
            }

            if trimmed.hasPrefix("PERFORMER") || trimmed.hasPrefix("FILE") {
                // Informational — skip.
                continue
            }

            if trimmed.hasPrefix("TRACK") {
                // Reset title for each new track; title may appear after TRACK.
                continue
            }

            if trimmed.hasPrefix("INDEX 00") {
                // Pre-gap — ignore.
                continue
            }

            if trimmed.hasPrefix("INDEX 01") {
                let timestampStr = String(trimmed.dropFirst("INDEX 01 ".count))
                    .trimmingCharacters(in: .whitespaces)
                guard let timestamp = parseCueTimestamp(timestampStr) else { continue }

                let title = currentTitle ?? "Track \(chapters.count + 1)"
                chapters.append(Chapter(start: timestamp, title: title))
                currentTitle = nil
            }
        }

        guard !chapters.isEmpty else {
            throw ExportError.invalidData("No valid tracks found in Cue Sheet input.")
        }

        return ChapterList(chapters)
    }

    // MARK: - Timestamp Conversion

    /// Parses a Cue Sheet timestamp (`MM:SS:FF`) where FF = CD frames (1/75 sec).
    private static func parseCueTimestamp(_ string: String) -> AudioTimestamp? {
        let components = string.split(separator: ":")
        guard components.count == 3 else { return nil }

        guard let minutes = Int(components[0]) else { return nil }
        guard let seconds = Int(components[1]) else { return nil }
        guard let frames = Int(components[2]) else { return nil }

        let totalSeconds = Double(minutes) * 60.0 + Double(seconds) + Double(frames) / 75.0
        return AudioTimestamp(timeInterval: totalSeconds)
    }

    /// Formats a timestamp as `MM:SS:FF` (CD frames at 75 fps).
    private static func formatCueTimestamp(_ timestamp: AudioTimestamp) -> String {
        let totalSeconds = timestamp.timeInterval
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        let fractionalSeconds = totalSeconds - Double(Int(totalSeconds))
        let frames = Int(round(fractionalSeconds * 75.0))
        return String(format: "%02d:%02d:%02d", minutes, seconds, min(frames, 74))
    }

    // MARK: - String Helpers

    /// Extracts a quoted value from a Cue Sheet line.
    ///
    /// Given `TITLE "My Song"`, returns `"My Song"`.
    private static func extractQuotedValue(from line: String, key: String) -> String? {
        guard line.hasPrefix(key) else { return nil }
        guard let firstQuote = line.firstIndex(of: "\"") else { return nil }
        let afterQuote = line.index(after: firstQuote)
        guard let lastQuote = line[afterQuote...].firstIndex(of: "\"") else { return nil }
        return String(line[afterQuote..<lastQuote])
    }

    /// Escapes a string for Cue Sheet output (removes double quotes).
    private static func escapeCueString(_ string: String) -> String {
        string.replacingOccurrences(of: "\"", with: "'")
    }
}
