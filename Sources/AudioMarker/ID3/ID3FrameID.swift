/// Known ID3v2 frame identifiers.
public enum ID3FrameID: String, Sendable, Hashable, CaseIterable {

    // MARK: - Tier 1: Chapter & Podcast Essentials

    /// Chapter frame.
    case chapter = "CHAP"
    /// Table of contents frame.
    case tableOfContents = "CTOC"
    /// Attached picture frame.
    case attachedPicture = "APIC"
    /// Title/songname/content description.
    case title = "TIT2"
    /// Lead performer(s)/soloist(s).
    case artist = "TPE1"
    /// Album/movie/show title.
    case album = "TALB"
    /// Content type (genre).
    case genre = "TCON"
    /// Track number/position in set.
    case trackNumber = "TRCK"
    /// Year (v2.3 only).
    case yearV23 = "TYER"
    /// Recording time (v2.4, replaces TYER).
    case recordingDate = "TDRC"
    /// Comment frame.
    case comment = "COMM"
    /// User-defined text information frame.
    case userDefinedText = "TXXX"
    /// Unsynchronized lyrics/text transcription.
    case unsyncLyrics = "USLT"
    /// Synchronized lyrics/text.
    case syncLyrics = "SYLT"
    /// Official artist/performer webpage.
    case artistURL = "WOAR"
    /// Official audio source webpage.
    case audioSourceURL = "WOAS"
    /// User-defined URL link frame.
    case userDefinedURL = "WXXX"

    // MARK: - Tier 2: Professional Metadata

    /// Band/orchestra/accompaniment.
    case albumArtist = "TPE2"
    /// Composer.
    case composer = "TCOM"
    /// Publisher.
    case publisher = "TPUB"
    /// Copyright message.
    case copyright = "TCOP"
    /// Encoded by.
    case encodedBy = "TENC"
    /// Length in milliseconds.
    case length = "TLEN"
    /// BPM (beats per minute).
    case bpm = "TBPM"
    /// Initial key.
    case musicalKey = "TKEY"
    /// Language(s).
    case language = "TLAN"
    /// Part of a set (disc number).
    case discNumber = "TPOS"
    /// ISRC (International Standard Recording Code).
    case isrc = "TSRC"
    /// Official audio file webpage.
    case audioFileURL = "WOAF"
    /// Publishers official webpage.
    case publisherURL = "WPUB"
    /// Commercial information.
    case commercialURL = "WCOM"
    /// Private frame.
    case privateData = "PRIV"
    /// Unique file identifier.
    case uniqueFileID = "UFID"
    /// Play counter.
    case playCounter = "PCNT"
    /// Popularimeter.
    case popularimeter = "POPM"
}
