/// Describes the type of synchronized text content (ID3v2 SYLT content type descriptor).
public enum ContentType: UInt8, Sendable, Hashable, CaseIterable {
    case other = 0
    case lyrics = 1
    case textTranscription = 2
    case movementOrPartName = 3
    case events = 4
    case chord = 5
    case trivia = 6
    case webpageURLs = 7
    case imageURLs = 8
}
