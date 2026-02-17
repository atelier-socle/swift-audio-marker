// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation

/// Exports and imports chapters in Podlove Simple Chapters XML format.
///
/// Output format:
/// ```xml
/// <?xml version="1.0" encoding="UTF-8"?>
/// <psc:chapters version="1.2" xmlns:psc="http://podlove.org/simple-chapters">
///   <psc:chapter start="HH:MM:SS.mmm" title="..." />
/// </psc:chapters>
/// ```
public struct PodloveXMLExporter: Sendable {

    /// Creates a Podlove XML exporter.
    public init() {}

    // MARK: - Export

    /// Exports chapters to Podlove Simple Chapters XML.
    /// - Parameter chapters: The chapters to export.
    /// - Returns: An XML string.
    public func export(_ chapters: ChapterList) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<psc:chapters version=\"1.2\" xmlns:psc=\"http://podlove.org/simple-chapters\">\n"
        for chapter in chapters {
            xml += "  <psc:chapter start=\"\(chapter.start.description)\""
            xml += " title=\"\(escapeXML(chapter.title))\""
            if let url = chapter.url {
                xml += " href=\"\(escapeXML(url.absoluteString))\""
            }
            xml += " />\n"
        }
        xml += "</psc:chapters>\n"
        return xml
    }

    // MARK: - Import

    /// Imports chapters from Podlove Simple Chapters XML.
    /// - Parameter string: The XML string to parse.
    /// - Returns: A ``ChapterList`` with the parsed chapters.
    /// - Throws: ``ExportError`` if the XML is malformed.
    public func importChapters(from string: String) throws -> ChapterList {
        guard let data = string.data(using: .utf8) else {
            throw ExportError.invalidData("Failed to decode string as UTF-8.")
        }
        let delegate = PodloveXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            if let parseError = delegate.parseError {
                throw parseError
            }
            let description = parser.parserError?.localizedDescription ?? "Unknown error"
            throw ExportError.invalidFormat("XML parsing failed: \(description)")
        }
        if let parseError = delegate.parseError {
            throw parseError
        }
        return delegate.chapters
    }

    // MARK: - XML Escaping

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - XML Parser Delegate

private final class PodloveXMLParserDelegate: NSObject, XMLParserDelegate {

    var chapters = ChapterList()
    var parseError: ExportError?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        guard localName == "chapter" else { return }

        guard let startString = attributes["start"] else {
            parseError = ExportError.invalidFormat("Missing 'start' attribute in chapter element.")
            parser.abortParsing()
            return
        }
        guard let title = attributes["title"] else {
            parseError = ExportError.invalidFormat("Missing 'title' attribute in chapter element.")
            parser.abortParsing()
            return
        }

        do {
            let start = try AudioTimestamp(string: startString)
            let url: URL? = attributes["href"].flatMap { URL(string: $0) }
            chapters.append(Chapter(start: start, title: title, url: url))
        } catch {
            parseError = ExportError.invalidFormat("Invalid timestamp '\(startString)'.")
            parser.abortParsing()
        }
    }
}
