import Foundation

/// A parsed ID3v2 frame.
public enum ID3Frame: Sendable, Hashable {

    /// Text frame (TIT2, TPE1, TALB, etc.).
    case text(id: String, text: String)

    /// User-defined text frame (TXXX).
    case userDefinedText(description: String, value: String)

    /// URL frame (WOAR, WOAS, WOAF, WPUB, WCOM).
    case url(id: String, url: String)

    /// User-defined URL frame (WXXX).
    case userDefinedURL(description: String, url: String)

    /// Comment frame (COMM).
    case comment(language: String, description: String, text: String)

    /// Attached picture frame (APIC).
    case attachedPicture(pictureType: UInt8, mimeType: String, description: String, data: Data)

    /// Chapter frame (CHAP).
    case chapter(
        elementID: String,
        startTime: UInt32,
        endTime: UInt32,
        subframes: [ID3Frame]
    )

    /// Table of contents frame (CTOC).
    case tableOfContents(
        elementID: String,
        isTopLevel: Bool,
        isOrdered: Bool,
        childElementIDs: [String],
        subframes: [ID3Frame]
    )

    /// Unsynchronized lyrics frame (USLT).
    case unsyncLyrics(language: String, description: String, text: String)

    /// Synchronized lyrics frame (SYLT).
    case syncLyrics(
        language: String,
        contentType: UInt8,
        description: String,
        events: [SyncLyricEvent]
    )

    /// Private data frame (PRIV).
    case privateData(owner: String, data: Data)

    /// Unique file identifier frame (UFID).
    case uniqueFileID(owner: String, identifier: Data)

    /// Play counter frame (PCNT).
    case playCounter(count: UInt64)

    /// Popularimeter frame (POPM).
    case popularimeter(email: String, rating: UInt8, playCount: UInt64)

    /// Unknown or unsupported frame preserved as raw bytes for round-trip fidelity.
    case unknown(id: String, data: Data)

    // MARK: - Properties

    /// The 4-character frame identifier.
    public var frameID: String {
        switch self {
        case .text(let id, _): return id
        case .userDefinedText: return ID3FrameID.userDefinedText.rawValue
        case .url(let id, _): return id
        case .userDefinedURL: return ID3FrameID.userDefinedURL.rawValue
        case .comment: return ID3FrameID.comment.rawValue
        case .attachedPicture: return ID3FrameID.attachedPicture.rawValue
        case .chapter: return ID3FrameID.chapter.rawValue
        case .tableOfContents: return ID3FrameID.tableOfContents.rawValue
        case .unsyncLyrics: return ID3FrameID.unsyncLyrics.rawValue
        case .syncLyrics: return ID3FrameID.syncLyrics.rawValue
        case .privateData: return ID3FrameID.privateData.rawValue
        case .uniqueFileID: return ID3FrameID.uniqueFileID.rawValue
        case .playCounter: return ID3FrameID.playCounter.rawValue
        case .popularimeter: return ID3FrameID.popularimeter.rawValue
        case .unknown(let id, _): return id
        }
    }
}

// MARK: - SyncLyricEvent

/// A single timestamped event in a synchronized lyrics frame.
public struct SyncLyricEvent: Sendable, Hashable {

    /// The text content for this event.
    public let text: String

    /// The timestamp in milliseconds.
    public let timestamp: UInt32

    /// Creates a synchronized lyric event.
    /// - Parameters:
    ///   - text: The text content.
    ///   - timestamp: The timestamp in milliseconds.
    public init(text: String, timestamp: UInt32) {
        self.text = text
        self.timestamp = timestamp
    }
}
