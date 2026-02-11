import Foundation

/// Exports chapters to Markdown format (export only).
///
/// Output format:
/// ```markdown
/// 1. **00:00:00** - Introduction
/// 2. **00:05:30** - Main Topic
/// ```
public struct MarkdownExporter: Sendable {

    /// Creates a Markdown exporter.
    public init() {}

    // MARK: - Export

    /// Exports chapters to a numbered Markdown list.
    /// - Parameter chapters: The chapters to export.
    /// - Returns: A Markdown string with bold timestamps and em-dash separators.
    public func export(_ chapters: ChapterList) -> String {
        var lines: [String] = []
        for (index, chapter) in chapters.enumerated() {
            let timestamp = chapter.start.shortDescription
            lines.append("\(index + 1). **\(timestamp)** \u{2014} \(chapter.title)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
