import Foundation

/// Unified API for exporting and importing chapters in multiple formats.
///
/// Dispatches to format-specific exporters: ``PodloveJSONExporter``,
/// ``PodloveXMLExporter``, ``MP4ChapsExporter``, ``FFMetadataExporter``,
/// and ``MarkdownExporter``.
public struct ChapterExporter: Sendable {

    /// Creates a chapter exporter.
    public init() {}

    // MARK: - Export

    /// Exports chapters to the specified format.
    /// - Parameters:
    ///   - chapters: The chapters to export.
    ///   - format: The target export format.
    /// - Returns: A string in the specified format.
    /// - Throws: ``ExportError`` if encoding fails.
    public func export(_ chapters: ChapterList, format: ExportFormat) throws -> String {
        try Self.guardNotLyricsOnly(format)
        return switch format {
        case .podloveJSON:
            try PodloveJSONExporter().export(chapters)
        case .podloveXML:
            PodloveXMLExporter().export(chapters)
        case .mp4chaps:
            MP4ChapsExporter().export(chapters)
        case .ffmetadata:
            FFMetadataExporter().export(chapters)
        case .markdown:
            MarkdownExporter().export(chapters)
        case .podcastNamespace:
            try PodcastNamespaceParser.export(chapters)
        case .cueSheet:
            CueSheetExporter.export(chapters)
        case .lrc, .ttml, .webvtt, .srt:
            // Already handled by guardNotLyricsOnly above.
            throw ExportError.unsupportedFormat("\(format) is a lyrics format")
        }
    }

    // MARK: - Import

    /// Imports chapters from a string in the specified format.
    /// - Parameters:
    ///   - string: The input string to parse.
    ///   - format: The source format.
    /// - Returns: A ``ChapterList`` with the parsed chapters.
    /// - Throws: ``ExportError/importNotSupported(_:)`` for Markdown,
    ///           or format-specific errors.
    public func importChapters(from string: String, format: ExportFormat) throws -> ChapterList {
        try Self.guardNotLyricsOnly(format)
        return switch format {
        case .podloveJSON:
            try PodloveJSONExporter().importChapters(from: string)
        case .podloveXML:
            try PodloveXMLExporter().importChapters(from: string)
        case .mp4chaps:
            try MP4ChapsExporter().importChapters(from: string)
        case .ffmetadata:
            try FFMetadataExporter().importChapters(from: string)
        case .markdown:
            throw ExportError.importNotSupported("markdown")
        case .podcastNamespace:
            try PodcastNamespaceParser.parse(string)
        case .cueSheet:
            try CueSheetExporter.parse(string)
        case .lrc, .ttml, .webvtt, .srt:
            // Already handled by guardNotLyricsOnly above.
            throw ExportError.unsupportedFormat("\(format) is a lyrics format")
        }
    }

    // MARK: - Private

    /// Lyrics-only formats that cannot be used for chapter export/import.
    private static let lyricsOnlyFormats: Set<ExportFormat> = [.lrc, .ttml, .webvtt, .srt]

    /// Throws if the format is lyrics-only.
    private static func guardNotLyricsOnly(_ format: ExportFormat) throws {
        if lyricsOnlyFormats.contains(format) {
            throw ExportError.unsupportedFormat(
                "\(format.rawValue) is a lyrics format, not a chapter format")
        }
    }
}
