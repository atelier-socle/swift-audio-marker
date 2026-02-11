import Foundation

/// Exports and imports chapters in FFmpeg metadata format.
///
/// Output format:
/// ```
/// ;FFMETADATA1
///
/// [CHAPTER]
/// TIMEBASE=1/1000
/// START=0
/// END=60000
/// title=Introduction
/// ```
public struct FFMetadataExporter: Sendable {

    /// Creates an FFmpeg metadata exporter.
    public init() {}

    // MARK: - Export

    /// Exports chapters to FFmpeg metadata format.
    ///
    /// Uses `TIMEBASE=1/1000` with START/END values in milliseconds.
    /// - Parameter chapters: The chapters to export.
    /// - Returns: An FFmpeg metadata string.
    public func export(_ chapters: ChapterList) -> String {
        var output = ";FFMETADATA1\n"
        for chapter in chapters {
            output += "\n[CHAPTER]\n"
            output += "TIMEBASE=1/1000\n"
            let startMs = Int(round(chapter.start.timeInterval * 1000))
            output += "START=\(startMs)\n"
            if let end = chapter.end {
                let endMs = Int(round(end.timeInterval * 1000))
                output += "END=\(endMs)\n"
            }
            output += "title=\(escapeFFMetadata(chapter.title))\n"
        }
        return output
    }

    // MARK: - Import

    /// Imports chapters from FFmpeg metadata format.
    ///
    /// Supports `TIMEBASE=1/1000` (milliseconds) and `TIMEBASE=1/1000000` (microseconds).
    /// - Parameter string: The metadata string to parse.
    /// - Returns: A ``ChapterList`` with the parsed chapters.
    /// - Throws: ``ExportError`` if the format is invalid.
    public func importChapters(from string: String) throws -> ChapterList {
        let lines = string.components(separatedBy: .newlines)
        var chapters = ChapterList()
        var state = ChapterState()
        var inChapter = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "[CHAPTER]" {
                if inChapter {
                    chapters.append(try makeChapter(from: state))
                }
                inChapter = true
                state = ChapterState()
                continue
            }

            guard inChapter else { continue }
            parseChapterLine(trimmed, into: &state)
        }

        if inChapter {
            chapters.append(try makeChapter(from: state))
        }
        return chapters
    }
}

// MARK: - Escaping

extension FFMetadataExporter {

    private func escapeFFMetadata(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "=", with: "\\=")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "#", with: "\\#")
            .replacingOccurrences(of: "\n", with: "\\\n")
    }

    private func unescapeFFMetadata(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\\n", with: "\n")
            .replacingOccurrences(of: "\\#", with: "#")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\=", with: "=")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}

// MARK: - Parsing Helpers

extension FFMetadataExporter {

    /// Intermediate state for parsing a single [CHAPTER] section.
    private struct ChapterState {
        var start: Int?
        var end: Int?
        var title: String?
        var timebaseFactor: Double = 0.001
    }

    private func parseChapterLine(_ line: String, into state: inout ChapterState) {
        if let value = extractValue(from: line, key: "TIMEBASE") {
            state.timebaseFactor = parseTimebase(value)
        } else if let value = extractValue(from: line, key: "START") {
            state.start = Int(value)
        } else if let value = extractValue(from: line, key: "END") {
            state.end = Int(value)
        } else if let value = extractValue(from: line, key: "title") {
            state.title = unescapeFFMetadata(value)
        }
    }

    private func makeChapter(from state: ChapterState) throws -> Chapter {
        guard let startValue = state.start else {
            throw ExportError.invalidFormat("Missing START in chapter section.")
        }
        let startSeconds = Double(startValue) * state.timebaseFactor
        let endTimestamp: AudioTimestamp? = state.end.map {
            AudioTimestamp(timeInterval: Double($0) * state.timebaseFactor)
        }
        return Chapter(
            start: AudioTimestamp(timeInterval: startSeconds),
            title: state.title ?? "",
            end: endTimestamp)
    }

    private func extractValue(from line: String, key: String) -> String? {
        let prefix = key + "="
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count))
    }

    /// Parses a TIMEBASE value (e.g. "1/1000") and returns the factor to convert units to seconds.
    private func parseTimebase(_ value: String) -> Double {
        let parts = value.split(separator: "/")
        guard parts.count == 2,
            let numerator = Double(parts[0]),
            let denominator = Double(parts[1]),
            denominator > 0
        else {
            return 0.001
        }
        return numerator / denominator
    }
}
