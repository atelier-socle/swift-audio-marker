import Foundation

/// Exports and imports chapters in MP4Chaps plain text format.
///
/// Output format (one chapter per line):
/// ```
/// HH:MM:SS.mmm Title
/// ```
public struct MP4ChapsExporter: Sendable {

    /// Creates an MP4Chaps exporter.
    public init() {}

    // MARK: - Export

    /// Exports chapters to MP4Chaps plain text format.
    /// - Parameter chapters: The chapters to export.
    /// - Returns: A plain text string with one chapter per line.
    public func export(_ chapters: ChapterList) -> String {
        var lines: [String] = []
        for chapter in chapters {
            lines.append("\(chapter.start.description) \(chapter.title)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Import

    /// Imports chapters from MP4Chaps plain text format.
    /// - Parameter string: The text to parse.
    /// - Returns: A ``ChapterList`` with the parsed chapters.
    /// - Throws: ``ExportError`` or ``AudioTimestampError`` if parsing fails.
    public func importChapters(from string: String) throws -> ChapterList {
        var chapters = ChapterList()
        let lines = string.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard let spaceIndex = trimmed.firstIndex(of: " "),
                spaceIndex > trimmed.startIndex
            else {
                throw ExportError.invalidFormat("Invalid line: \"\(trimmed)\".")
            }

            let timestampStr = String(trimmed[trimmed.startIndex..<spaceIndex])
            let title = String(trimmed[trimmed.index(after: spaceIndex)...])
                .trimmingCharacters(in: .whitespaces)

            guard !title.isEmpty else {
                throw ExportError.invalidFormat("Empty title in line: \"\(trimmed)\".")
            }

            let start = try AudioTimestamp(string: timestampStr)
            chapters.append(Chapter(start: start, title: title))
        }
        return chapters
    }
}
