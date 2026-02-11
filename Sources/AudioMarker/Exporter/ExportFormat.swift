import Foundation

/// Supported export formats for chapters and lyrics.
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
    /// LRC synchronized lyrics format.
    case lrc
    /// W3C Timed Text Markup Language (export only).
    case ttml
    /// Podcasting 2.0 (podcast-namespace) JSON format.
    case podcastNamespace

    /// The file extension for this format.
    public var fileExtension: String {
        switch self {
        case .podloveJSON: "json"
        case .podloveXML: "xml"
        case .mp4chaps: "txt"
        case .ffmetadata: "ini"
        case .markdown: "md"
        case .lrc: "lrc"
        case .ttml: "ttml"
        case .podcastNamespace: "json"
        }
    }

    /// Whether this format supports importing.
    public var supportsImport: Bool {
        switch self {
        case .markdown, .ttml: false
        case .lrc: true
        case .podcastNamespace: true
        default: true
        }
    }
}
