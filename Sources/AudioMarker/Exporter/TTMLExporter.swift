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

            if line.isKaraoke {
                xml += "      <p begin=\"\(begin)\" end=\"\(end)\">\n"
                for span in line.segments {
                    let spanBegin = formatTimestamp(span.startTime)
                    let spanEnd = formatTimestamp(span.endTime)
                    if let styleID = span.styleID {
                        xml +=
                            "        <span begin=\"\(spanBegin)\" end=\"\(spanEnd)\""
                            + " style=\"\(xmlEscaped(styleID))\">"
                            + "\(xmlEscaped(span.text))</span>\n"
                    } else {
                        xml +=
                            "        <span begin=\"\(spanBegin)\" end=\"\(spanEnd)\">"
                            + "\(xmlEscaped(span.text))</span>\n"
                    }
                }
                xml += "      </p>\n"
            } else {
                xml +=
                    "      <p begin=\"\(begin)\" end=\"\(end)\">"
                    + "\(xmlEscaped(line.text))</p>\n"
            }
        }

        xml += "    </div>\n"
        xml += "  </body>\n"
        xml += "</tt>\n"

        return xml
    }

    /// Exports a full ``TTMLDocument`` to TTML format (lossless round-trip).
    /// - Parameter document: The TTML document to export.
    /// - Returns: A TTML XML string preserving styles, regions, and metadata.
    public static func exportDocument(_ document: TTMLDocument) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<tt xml:lang=\"\(xmlEscaped(document.language))\""
        xml += " xmlns=\"http://www.w3.org/ns/ttml\""
        xml += " xmlns:ttm=\"http://www.w3.org/ns/ttml#metadata\""
        xml += " xmlns:tts=\"http://www.w3.org/ns/ttml#styling\""
        xml += " xmlns:ttp=\"http://www.w3.org/ns/ttml#parameter\""
        xml += " ttp:timeBase=\"\(xmlEscaped(document.timeBase))\""
        if let frameRate = document.frameRate {
            xml += " ttp:frameRate=\"\(frameRate)\""
        }
        xml += ">\n"

        // Head section.
        if hasHead(document) {
            xml += "  <head>\n"
            xml += buildMetadataXML(document)
            xml += buildStylingXML(document)
            xml += buildLayoutXML(document)
            xml += "  </head>\n"
        }

        // Body section.
        xml += "  <body>\n"
        for division in document.divisions {
            xml += buildDivisionXML(division)
        }
        xml += "  </body>\n"
        xml += "</tt>\n"

        return xml
    }

    // MARK: - Private Helpers

    private static func hasHead(_ doc: TTMLDocument) -> Bool {
        doc.title != nil || doc.description != nil
            || !doc.styles.isEmpty || !doc.regions.isEmpty || !doc.agents.isEmpty
    }

    private static func buildMetadataXML(_ doc: TTMLDocument) -> String {
        guard doc.title != nil || doc.description != nil || !doc.agents.isEmpty else {
            return ""
        }
        var xml = "    <metadata>\n"
        if let title = doc.title {
            xml += "      <ttm:title>\(xmlEscaped(title))</ttm:title>\n"
        }
        if let desc = doc.description {
            xml += "      <ttm:desc>\(xmlEscaped(desc))</ttm:desc>\n"
        }
        for agent in doc.agents {
            xml += "      <ttm:agent xml:id=\"\(xmlEscaped(agent.id))\""
            if let type = agent.type {
                xml += " type=\"\(xmlEscaped(type))\""
            }
            xml += ">\n"
            if let name = agent.name {
                xml += "        <ttm:name>\(xmlEscaped(name))</ttm:name>\n"
            }
            xml += "      </ttm:agent>\n"
        }
        xml += "    </metadata>\n"
        return xml
    }

    private static func buildStylingXML(_ doc: TTMLDocument) -> String {
        guard !doc.styles.isEmpty else { return "" }
        var xml = "    <styling>\n"
        for style in doc.styles {
            xml += "      <style xml:id=\"\(xmlEscaped(style.id))\""
            for (key, value) in style.properties.sorted(by: { $0.key < $1.key }) {
                xml += " \(key)=\"\(xmlEscaped(value))\""
            }
            xml += "/>\n"
        }
        xml += "    </styling>\n"
        return xml
    }

    private static func buildLayoutXML(_ doc: TTMLDocument) -> String {
        guard !doc.regions.isEmpty else { return "" }
        var xml = "    <layout>\n"
        for region in doc.regions {
            xml += "      <region xml:id=\"\(xmlEscaped(region.id))\""
            if let origin = region.origin {
                xml += " tts:origin=\"\(xmlEscaped(origin))\""
            }
            if let extent = region.extent {
                xml += " tts:extent=\"\(xmlEscaped(extent))\""
            }
            if let displayAlign = region.displayAlign {
                xml += " tts:displayAlign=\"\(xmlEscaped(displayAlign))\""
            }
            for (key, value) in region.properties.sorted(by: { $0.key < $1.key }) {
                xml += " \(key)=\"\(xmlEscaped(value))\""
            }
            xml += "/>\n"
        }
        xml += "    </layout>\n"
        return xml
    }

    private static func buildDivisionXML(_ div: TTMLDivision) -> String {
        var xml = "    <div"
        if let lang = div.language {
            xml += " xml:lang=\"\(xmlEscaped(lang))\""
        }
        if let style = div.styleID {
            xml += " style=\"\(xmlEscaped(style))\""
        }
        if let region = div.regionID {
            xml += " region=\"\(xmlEscaped(region))\""
        }
        xml += ">\n"

        for paragraph in div.paragraphs {
            xml += buildParagraphXML(paragraph)
        }

        xml += "    </div>\n"
        return xml
    }

    private static func buildParagraphXML(_ p: TTMLParagraph) -> String {
        var xml = "      <p begin=\"\(formatTimestamp(p.begin))\""
        if let end = p.end {
            xml += " end=\"\(formatTimestamp(end))\""
        }
        if let style = p.styleID {
            xml += " style=\"\(xmlEscaped(style))\""
        }
        if let region = p.regionID {
            xml += " region=\"\(xmlEscaped(region))\""
        }
        if let agent = p.agentID {
            xml += " ttm:agent=\"\(xmlEscaped(agent))\""
        }
        if let role = p.role {
            xml += " ttm:role=\"\(xmlEscaped(role))\""
        }

        if p.spans.isEmpty {
            xml += ">\(xmlEscaped(p.text))</p>\n"
        } else {
            xml += ">\n"
            for span in p.spans {
                xml += "        <span begin=\"\(formatTimestamp(span.begin))\""
                if let end = span.end {
                    xml += " end=\"\(formatTimestamp(end))\""
                }
                if let style = span.styleID {
                    xml += " style=\"\(xmlEscaped(style))\""
                }
                xml += ">\(xmlEscaped(span.text))</span>\n"
            }
            xml += "      </p>\n"
        }

        return xml
    }

    // MARK: - Formatting

    /// Formats a timestamp as `HH:MM:SS.mmm` for TTML.
    private static func formatTimestamp(_ timestamp: AudioTimestamp) -> String {
        timestamp.description
    }

    /// Escapes special XML characters.
    static func xmlEscaped(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
