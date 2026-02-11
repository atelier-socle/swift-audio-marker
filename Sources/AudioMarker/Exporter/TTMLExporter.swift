import Foundation

/// Exports synchronized lyrics to W3C Timed Text Markup Language (TTML) format.
///
/// TTML is the standard used by Apple Music for displaying synchronized lyrics.
/// This exporter produces valid TTML 1.0 XML output.
public enum TTMLExporter: Sendable {

    // MARK: - Export

    /// Exports synchronized lyrics to TTML format.
    /// - Parameters:
    ///   - lyrics: The synchronized lyrics to export.
    ///   - audioDuration: Optional total audio duration, used to compute
    ///     the end time of the last line. Defaults to `nil`.
    ///   - title: Optional title included in a `<ttm:title>` element. Defaults to `nil`.
    /// - Returns: A TTML XML string.
    public static func export(
        _ lyrics: SynchronizedLyrics,
        audioDuration: AudioTimestamp? = nil,
        title: String? = nil
    ) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<tt xml:lang=\"\(xmlEscaped(lyrics.language))\""
        xml += " xmlns=\"http://www.w3.org/ns/ttml\""
        xml += " xmlns:ttm=\"http://www.w3.org/ns/ttml#metadata\">\n"

        if let title {
            xml += "  <head>\n"
            xml += "    <metadata>\n"
            xml += "      <ttm:title>\(xmlEscaped(title))</ttm:title>\n"
            xml += "    </metadata>\n"
            xml += "  </head>\n"
        }

        xml += "  <body>\n"
        xml += "    <div>\n"

        let sortedLines = lyrics.lines.sorted { $0.time < $1.time }

        for (index, line) in sortedLines.enumerated() {
            let begin = formatTimestamp(line.time)
            let end: String
            if index + 1 < sortedLines.count {
                end = formatTimestamp(sortedLines[index + 1].time)
            } else if let duration = audioDuration {
                end = formatTimestamp(duration)
            } else {
                // Default: 5 seconds after begin
                let endTime = AudioTimestamp(timeInterval: line.time.timeInterval + 5.0)
                end = formatTimestamp(endTime)
            }
            xml += "      <p begin=\"\(begin)\" end=\"\(end)\">\(xmlEscaped(line.text))</p>\n"
        }

        xml += "    </div>\n"
        xml += "  </body>\n"
        xml += "</tt>\n"

        return xml
    }

    // MARK: - Private

    /// Formats a timestamp as `HH:MM:SS.mmm` for TTML.
    private static func formatTimestamp(_ timestamp: AudioTimestamp) -> String {
        timestamp.description
    }

    /// Escapes special XML characters.
    private static func xmlEscaped(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
