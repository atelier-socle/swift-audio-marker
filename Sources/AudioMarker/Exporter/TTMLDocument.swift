/// A complete TTML document preserving full structure for lossless round-trip.
///
/// This type captures the entire TTML document structure including styles,
/// regions, metadata, and the full content hierarchy. Use this for TTML-to-TTML
/// round-trips. For embedding in audio files, convert to ``SynchronizedLyrics``
/// via ``toSynchronizedLyrics()``.
public struct TTMLDocument: Sendable, Hashable {

    /// Default language (from `<tt xml:lang="...">`).
    public let language: String

    /// Time base (`"media"`, `"smpte"`, `"clock"`).
    public let timeBase: String

    /// Frame rate (for SMPTE time base).
    public let frameRate: Int?

    /// Document title (from `<ttm:title>`).
    public let title: String?

    /// Document description (from `<ttm:desc>`).
    public let description: String?

    /// Named styles from `<styling>`.
    public let styles: [TTMLStyle]

    /// Named regions from `<layout>`.
    public let regions: [TTMLRegion]

    /// Metadata agents from `<metadata>`.
    public let agents: [TTMLAgent]

    /// Content divisions (each with optional language and region override).
    public let divisions: [TTMLDivision]

    /// Creates a TTML document.
    /// - Parameters:
    ///   - language: Default language. Defaults to `"en"`.
    ///   - timeBase: Time base. Defaults to `"media"`.
    ///   - frameRate: Frame rate. Defaults to `nil`.
    ///   - title: Document title. Defaults to `nil`.
    ///   - description: Document description. Defaults to `nil`.
    ///   - styles: Named styles. Defaults to empty.
    ///   - regions: Named regions. Defaults to empty.
    ///   - agents: Metadata agents. Defaults to empty.
    ///   - divisions: Content divisions. Defaults to empty.
    public init(
        language: String = "en",
        timeBase: String = "media",
        frameRate: Int? = nil,
        title: String? = nil,
        description: String? = nil,
        styles: [TTMLStyle] = [],
        regions: [TTMLRegion] = [],
        agents: [TTMLAgent] = [],
        divisions: [TTMLDivision] = []
    ) {
        self.language = language
        self.timeBase = timeBase
        self.frameRate = frameRate
        self.title = title
        self.description = description
        self.styles = styles
        self.regions = regions
        self.agents = agents
        self.divisions = divisions
    }
}

// MARK: - Conversion

extension TTMLDocument {

    /// Converts to synchronized lyrics for embedding in audio files.
    ///
    /// Produces one ``SynchronizedLyrics`` per division (language group).
    /// Karaoke spans are preserved in ``LyricLine/segments``.
    public func toSynchronizedLyrics() -> [SynchronizedLyrics] {
        divisions.map { division in
            let lang = division.language ?? language
            let iso639 = Self.toISO6392(lang)
            let lines = division.paragraphs.map { paragraph -> LyricLine in
                if paragraph.spans.isEmpty {
                    return LyricLine(time: paragraph.begin, text: paragraph.text)
                }
                let segments = paragraph.spans.map { span in
                    LyricSegment(
                        startTime: span.begin,
                        endTime: span.end ?? paragraph.end ?? span.begin,
                        text: span.text,
                        styleID: span.styleID
                    )
                }
                return LyricLine(
                    time: paragraph.begin, text: paragraph.text,
                    segments: segments)
            }
            return SynchronizedLyrics(language: iso639, lines: lines)
        }
    }

    /// Creates a ``TTMLDocument`` from synchronized lyrics (for export upgrade).
    /// - Parameter lyrics: Array of synchronized lyrics to convert.
    /// - Returns: A TTML document representing the lyrics.
    public static func from(_ lyrics: [SynchronizedLyrics]) -> TTMLDocument {
        let divisions = lyrics.map { syncLyrics in
            let paragraphs = syncLyrics.lines.map { line -> TTMLParagraph in
                let spans = line.segments.map { segment in
                    TTMLSpan(
                        begin: segment.startTime,
                        end: segment.endTime,
                        text: segment.text,
                        styleID: segment.styleID
                    )
                }
                return TTMLParagraph(
                    begin: line.time, text: line.text, spans: spans)
            }
            return TTMLDivision(
                language: syncLyrics.language, paragraphs: paragraphs)
        }
        let lang = lyrics.first?.language ?? "und"
        return TTMLDocument(language: lang, divisions: divisions)
    }

    /// Converts a 2-letter ISO 639-1 code to a 3-letter ISO 639-2 code.
    private static func toISO6392(_ code: String) -> String {
        guard code.count == 2 else { return code }
        let mapping: [String: String] = [
            "en": "eng", "fr": "fra", "de": "deu", "es": "spa",
            "it": "ita", "pt": "por", "ja": "jpn", "ko": "kor",
            "zh": "zho", "ar": "ara", "ru": "rus", "nl": "nld",
            "sv": "swe", "da": "dan", "no": "nor", "fi": "fin",
            "pl": "pol", "tr": "tur", "hi": "hin", "th": "tha"
        ]
        return mapping[code.lowercased()] ?? code
    }
}

// MARK: - TTMLDivision

/// A TTML division — a group of timed paragraphs sharing a language/region.
public struct TTMLDivision: Sendable, Hashable {

    /// Language for this division (overrides document language).
    public let language: String?

    /// Style reference.
    public let styleID: String?

    /// Region reference.
    public let regionID: String?

    /// Timed paragraphs.
    public let paragraphs: [TTMLParagraph]

    /// Creates a TTML division.
    /// - Parameters:
    ///   - language: Language override. Defaults to `nil`.
    ///   - styleID: Style reference. Defaults to `nil`.
    ///   - regionID: Region reference. Defaults to `nil`.
    ///   - paragraphs: Timed paragraphs. Defaults to empty.
    public init(
        language: String? = nil,
        styleID: String? = nil,
        regionID: String? = nil,
        paragraphs: [TTMLParagraph] = []
    ) {
        self.language = language
        self.styleID = styleID
        self.regionID = regionID
        self.paragraphs = paragraphs
    }
}

// MARK: - TTMLParagraph

/// A TTML paragraph — a timed text block that may contain karaoke spans.
public struct TTMLParagraph: Sendable, Hashable {

    /// Start time.
    public let begin: AudioTimestamp

    /// End time.
    public let end: AudioTimestamp?

    /// Full text content (spans joined).
    public let text: String

    /// Karaoke spans (empty if no word-level timing).
    public let spans: [TTMLSpan]

    /// Style reference.
    public let styleID: String?

    /// Region reference.
    public let regionID: String?

    /// Agent reference (for accessibility — who speaks this line).
    public let agentID: String?

    /// Role (e.g., `"dialog"`, `"description"`, `"narration"`).
    public let role: String?

    /// Creates a TTML paragraph.
    /// - Parameters:
    ///   - begin: Start time.
    ///   - end: End time. Defaults to `nil`.
    ///   - text: Full text content.
    ///   - spans: Karaoke spans. Defaults to empty.
    ///   - styleID: Style reference. Defaults to `nil`.
    ///   - regionID: Region reference. Defaults to `nil`.
    ///   - agentID: Agent reference. Defaults to `nil`.
    ///   - role: Role descriptor. Defaults to `nil`.
    public init(
        begin: AudioTimestamp,
        end: AudioTimestamp? = nil,
        text: String,
        spans: [TTMLSpan] = [],
        styleID: String? = nil,
        regionID: String? = nil,
        agentID: String? = nil,
        role: String? = nil
    ) {
        self.begin = begin
        self.end = end
        self.text = text
        self.spans = spans
        self.styleID = styleID
        self.regionID = regionID
        self.agentID = agentID
        self.role = role
    }
}

// MARK: - TTMLSpan

/// A TTML span — a timed segment within a paragraph (for karaoke).
public struct TTMLSpan: Sendable, Hashable {

    /// Start time of this span.
    public let begin: AudioTimestamp

    /// End time of this span.
    public let end: AudioTimestamp?

    /// Text content.
    public let text: String

    /// Style reference.
    public let styleID: String?

    /// Creates a TTML span.
    /// - Parameters:
    ///   - begin: Start time.
    ///   - end: End time. Defaults to `nil`.
    ///   - text: Text content.
    ///   - styleID: Style reference. Defaults to `nil`.
    public init(
        begin: AudioTimestamp,
        end: AudioTimestamp? = nil,
        text: String,
        styleID: String? = nil
    ) {
        self.begin = begin
        self.end = end
        self.text = text
        self.styleID = styleID
    }
}
