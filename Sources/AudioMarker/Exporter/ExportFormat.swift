import Foundation

/// Supported chapter export formats.
public enum ExportFormat: String, Sendable, CaseIterable {
    /// Podlove Simple Chapters (JSON).
    case podloveJSON
    /// Podlove Simple Chapters (XML).
    case podloveXML
    /// MP4Chaps plain text format.
    case mp4chaps
    /// FFmpeg metadata format.
    case ffmetadata
    /// Markdown (export only).
    case markdown

    /// The file extension for this format.
    public var fileExtension: String {
        switch self {
        case .podloveJSON: "json"
        case .podloveXML: "xml"
        case .mp4chaps: "txt"
        case .ffmetadata: "ini"
        case .markdown: "md"
        }
    }

    /// Whether this format supports importing chapters.
    public var supportsImport: Bool {
        switch self {
        case .markdown: false
        default: true
        }
    }
}
