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
        switch format {
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
        case .lrc:
            throw ExportError.unsupportedFormat("LRC is a lyrics format, not a chapter format")
        case .ttml:
            throw ExportError.unsupportedFormat("TTML is a lyrics format, not a chapter format")
        case .podcastNamespace:
            try PodcastNamespaceParser.export(chapters)
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
        switch format {
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
        case .lrc:
            throw ExportError.unsupportedFormat("LRC is a lyrics format, not a chapter format")
        case .ttml:
            throw ExportError.unsupportedFormat("TTML is a lyrics format, not a chapter format")
        case .podcastNamespace:
            try PodcastNamespaceParser.parse(string)
        }
    }
}
