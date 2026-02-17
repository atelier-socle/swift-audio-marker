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

/// Parses TTML (Timed Text Markup Language) documents into AudioMarker types.
///
/// Supports TTML 1.0 features including:
/// - Timed paragraphs (`<p>`) with `begin`/`end`/`dur` timing
/// - Karaoke spans (`<span>`) for word-level timing
/// - Styles (`<styling>/<style>`) with visual properties
/// - Regions (`<layout>/<region>`) for spatial positioning
/// - Metadata agents (`<ttm:agent>`) for accessibility
/// - Multi-language content via `<div xml:lang="...">`
/// - Line breaks (`<br/>`)
/// - Multiple time expression formats (clock, offset)
///
/// Usage:
/// ```swift
/// let parser = TTMLParser()
/// let document = try parser.parseDocument(from: ttmlString)
/// let lyrics = try parser.parseLyrics(from: ttmlString)
/// ```
public struct TTMLParser: Sendable {

    /// Creates a TTML parser.
    public init() {}

    /// Parses a TTML string into a full ``TTMLDocument`` (lossless).
    /// - Parameter string: The TTML XML content.
    /// - Returns: A complete TTML document.
    /// - Throws: ``TTMLParseError`` for any parsing failure.
    public func parseDocument(from string: String) throws -> TTMLDocument {
        guard let data = string.data(using: .utf8) else {
            throw TTMLParseError.invalidXML("Failed to encode string as UTF-8")
        }
        return try parseDocument(from: data)
    }

    /// Parses TTML data (UTF-8 encoded) into a full ``TTMLDocument``.
    /// - Parameter data: Raw TTML data.
    /// - Returns: A complete TTML document.
    /// - Throws: ``TTMLParseError`` for any parsing failure.
    public func parseDocument(from data: Data) throws -> TTMLDocument {
        let delegate = TTMLParserDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        xmlParser.shouldProcessNamespaces = true
        xmlParser.shouldReportNamespacePrefixes = true

        guard xmlParser.parse() else {
            if let error = delegate.parseError {
                throw error
            }
            let xmlError = xmlParser.parserError?.localizedDescription ?? "Unknown XML error"
            throw TTMLParseError.invalidXML(xmlError)
        }

        if let error = delegate.parseError {
            throw error
        }

        return delegate.buildDocument()
    }

    /// Parses a TTML string directly into synchronized lyrics (for audio embedding).
    /// - Parameter string: The TTML XML content.
    /// - Returns: Array of synchronized lyrics (one per language/div).
    /// - Throws: ``TTMLParseError`` for any parsing failure.
    public func parseLyrics(from string: String) throws -> [SynchronizedLyrics] {
        let document = try parseDocument(from: string)
        return document.toSynchronizedLyrics()
    }
}

// MARK: - SAX Parser Delegate

/// Internal SAX-style XML parser delegate for TTML documents.
///
/// Uses `Foundation.XMLParser` (the only native Swift XML parser).
/// This class is required because `XMLParserDelegate` is an `@objc` protocol.
private final class TTMLParserDelegate: NSObject, XMLParserDelegate {

    // MARK: - State

    var parseError: TTMLParseError?

    // Document-level attributes.
    private var language = "en"
    private var timeBase = "media"
    private var frameRate: Int?
    private var tickRate: Int?

    // Head metadata.
    private var title: String?
    private var desc: String?
    private var styles: [TTMLStyle] = []
    private var regions: [TTMLRegion] = []
    private var agents: [TTMLAgent] = []

    // Content.
    private var divisions: [TTMLDivision] = []
    private var orphanParagraphs: [TTMLParagraph] = []

    // Parsing state stack.
    var elementStack: [String] = []
    var currentText = ""

    // Metadata state.
    private var foundTTRoot = false

    // Style being built.
    private var currentStyleID: String?
    private var currentStyleProperties: [String: String] = [:]

    // Region being built.
    private var currentRegionID: String?
    private var currentRegionOrigin: String?
    private var currentRegionExtent: String?
    private var currentRegionDisplayAlign: String?
    private var currentRegionProperties: [String: String] = [:]

    // Agent being built.
    var currentAgentID: String?
    private var currentAgentType: String?
    var currentAgentName: String?

    // Division being built.
    private var currentDivLanguage: String?
    private var currentDivStyleID: String?
    private var currentDivRegionID: String?
    var currentDivParagraphs: [TTMLParagraph] = []
    var inDiv = false

    // Paragraph being built.
    var currentPBegin: String?
    private var currentPEnd: String?
    private var currentPDur: String?
    private var currentPStyleID: String?
    private var currentPRegionID: String?
    private var currentPAgentID: String?
    private var currentPRole: String?
    var currentPSpans: [TTMLSpan] = []
    var currentPText = ""
    var inParagraph = false

    // Span being built.
    private var currentSpanBegin: String?
    private var currentSpanEnd: String?
    private var currentSpanDur: String?
    private var currentSpanStyleID: String?
    var currentSpanText = ""
    var inSpan = false

    // MARK: - Build Result

    func buildDocument() -> TTMLDocument {
        // Collect any <p> elements found outside <div> into a default division.
        var allDivisions = divisions
        if !orphanParagraphs.isEmpty {
            allDivisions.append(TTMLDivision(paragraphs: orphanParagraphs))
        }

        return TTMLDocument(
            language: language,
            timeBase: timeBase,
            frameRate: frameRate,
            title: title,
            description: desc,
            styles: styles,
            regions: regions,
            agents: agents,
            divisions: allDivisions
        )
    }

    // MARK: - Time Parser

    var timeParser: TTMLTimeParser {
        TTMLTimeParser(frameRate: frameRate, tickRate: tickRate)
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        elementStack.append(elementName)
        currentText = ""

        switch elementName {
        case "tt":
            foundTTRoot = true
            parseTTAttributes(attributeDict)
        case "style": parseStyleStart(attributeDict)
        case "region": parseRegionStart(attributeDict)
        case "agent": parseAgentStart(attributeDict)
        case "div": parseDivStart(attributeDict)
        case "p": parseParagraphStart(attributeDict)
        case "span": parseSpanStart(attributeDict)
        case "br": handleLineBreak()
        default: break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "tt":
            if !foundTTRoot { parseError = .notTTML }
        case "title", "desc", "name":
            handleEndTextElement(elementName)
        case "style", "region", "agent", "div", "p", "span":
            handleEndStructuralElement(elementName)
        default:
            break
        }

        if elementStack.last == elementName {
            elementStack.removeLast()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inSpan {
            currentSpanText += string
        } else if inParagraph {
            currentPText += string
        } else {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        if self.parseError == nil {
            self.parseError = .invalidXML(parseError.localizedDescription)
        }
    }

    // MARK: - TT Root

    private func parseTTAttributes(_ attrs: [String: String]) {
        if let lang = attrs["xml:lang"] ?? attrs["lang"] {
            language = lang
        }
        if let tb = attrs["ttp:timeBase"] ?? attrs["timeBase"] {
            timeBase = tb
        }
        if let fr = attrs["ttp:frameRate"] ?? attrs["frameRate"] {
            frameRate = Int(fr)
        }
        if let tr = attrs["ttp:tickRate"] ?? attrs["tickRate"] {
            tickRate = Int(tr)
        }
    }

    // MARK: - Style

    private func parseStyleStart(_ attrs: [String: String]) {
        currentStyleID = attrs["xml:id"] ?? attrs["id"]
        currentStyleProperties = [:]
        for (key, value) in attrs where key.hasPrefix("tts:") || key.hasPrefix("style") {
            if key != "style" {
                currentStyleProperties[key] = value
            }
        }
    }

    private func finalizeStyle() {
        guard let id = currentStyleID else { return }
        styles.append(TTMLStyle(id: id, properties: currentStyleProperties))
        currentStyleID = nil
        currentStyleProperties = [:]
    }

    // MARK: - Region

    private func parseRegionStart(_ attrs: [String: String]) {
        currentRegionID = attrs["xml:id"] ?? attrs["id"]
        currentRegionOrigin = attrs["tts:origin"] ?? attrs["origin"]
        currentRegionExtent = attrs["tts:extent"] ?? attrs["extent"]
        currentRegionDisplayAlign = attrs["tts:displayAlign"] ?? attrs["displayAlign"]
        currentRegionProperties = [:]
        for (key, value) in attrs
        where key.hasPrefix("tts:") && key != "tts:origin" && key != "tts:extent"
            && key != "tts:displayAlign"
        {
            currentRegionProperties[key] = value
        }
    }

    private func finalizeRegion() {
        guard let id = currentRegionID else { return }
        regions.append(
            TTMLRegion(
                id: id,
                origin: currentRegionOrigin,
                extent: currentRegionExtent,
                displayAlign: currentRegionDisplayAlign,
                properties: currentRegionProperties
            ))
        currentRegionID = nil
    }

    // MARK: - Agent

    private func parseAgentStart(_ attrs: [String: String]) {
        currentAgentID = attrs["xml:id"] ?? attrs["id"]
        currentAgentType = attrs["type"]
        currentAgentName = nil
    }

    private func finalizeAgent() {
        guard let id = currentAgentID else { return }
        agents.append(TTMLAgent(id: id, type: currentAgentType, name: currentAgentName))
        currentAgentID = nil
    }

    // MARK: - Division

    private func parseDivStart(_ attrs: [String: String]) {
        inDiv = true
        currentDivLanguage = attrs["xml:lang"] ?? attrs["lang"]
        currentDivStyleID = attrs["style"]
        currentDivRegionID = attrs["region"]
        currentDivParagraphs = []
    }

    private func finalizeDiv() {
        guard inDiv else { return }
        divisions.append(
            TTMLDivision(
                language: currentDivLanguage,
                styleID: currentDivStyleID,
                regionID: currentDivRegionID,
                paragraphs: currentDivParagraphs
            ))
        inDiv = false
        currentDivParagraphs = []
    }

    // MARK: - Paragraph Start

    private func parseParagraphStart(_ attrs: [String: String]) {
        inParagraph = true
        currentPBegin = attrs["begin"]
        currentPEnd = attrs["end"]
        currentPDur = attrs["dur"]
        currentPStyleID = attrs["style"]
        currentPRegionID = attrs["region"]
        currentPAgentID = attrs["ttm:agent"] ?? attrs["agent"]
        currentPRole = attrs["ttm:role"] ?? attrs["role"]
        currentPSpans = []
        currentPText = ""
    }

    // MARK: - Span Start

    private func parseSpanStart(_ attrs: [String: String]) {
        inSpan = true
        currentSpanBegin = attrs["begin"]
        currentSpanEnd = attrs["end"]
        currentSpanDur = attrs["dur"]
        currentSpanStyleID = attrs["style"]
        currentSpanText = ""
    }
}

// MARK: - Element Finalization

extension TTMLParserDelegate {

    fileprivate func handleLineBreak() {
        if inSpan {
            currentSpanText += "\n"
        } else if inParagraph {
            currentPText += "\n"
        }
    }

    fileprivate func handleEndTextElement(_ name: String) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "title" where isInMetadata(): title = trimmed
        case "desc" where isInMetadata(): desc = trimmed
        case "name" where currentAgentID != nil: currentAgentName = trimmed
        default: break
        }
    }

    fileprivate func handleEndStructuralElement(_ name: String) {
        switch name {
        case "style": finalizeStyle()
        case "region": finalizeRegion()
        case "agent": finalizeAgent()
        case "div": finalizeDiv()
        case "p": finalizeParagraph()
        case "span": finalizeSpan()
        default: break
        }
    }

    fileprivate func finalizeParagraph() {
        guard inParagraph else { return }
        defer {
            inParagraph = false
            currentPSpans = []
            currentPText = ""
        }

        guard let beginStr = currentPBegin else {
            parseError = .missingTiming(element: "p")
            return
        }

        guard let begin = try? timeParser.parse(beginStr) else {
            parseError = .invalidTimeExpression(beginStr)
            return
        }

        let end = resolveEndTime(endStr: currentPEnd, durStr: currentPDur, begin: begin)

        let text: String
        if currentPSpans.isEmpty {
            text = normalizeText(currentPText)
        } else {
            text = currentPSpans.map(\.text).joined(separator: " ")
        }

        let paragraph = TTMLParagraph(
            begin: begin,
            end: end,
            text: text,
            spans: currentPSpans,
            styleID: currentPStyleID,
            regionID: currentPRegionID,
            agentID: currentPAgentID,
            role: currentPRole
        )

        if inDiv {
            currentDivParagraphs.append(paragraph)
        } else {
            orphanParagraphs.append(paragraph)
        }
    }

    fileprivate func finalizeSpan() {
        guard inSpan else { return }
        defer {
            inSpan = false
            currentSpanText = ""
        }

        let text = normalizeText(currentSpanText)
        guard !text.isEmpty else { return }

        let begin = resolveSpanBegin()
        let end = resolveEndTime(endStr: currentSpanEnd, durStr: currentSpanDur, begin: begin)

        let span = TTMLSpan(
            begin: begin,
            end: end,
            text: text,
            styleID: currentSpanStyleID
        )
        currentPSpans.append(span)
    }

    private func resolveSpanBegin() -> AudioTimestamp {
        if let beginStr = currentSpanBegin, let parsed = try? timeParser.parse(beginStr) {
            return parsed
        }
        if let pBeginStr = currentPBegin, let parsed = try? timeParser.parse(pBeginStr) {
            return parsed
        }
        return .zero
    }

    private func resolveEndTime(
        endStr: String?, durStr: String?, begin: AudioTimestamp
    ) -> AudioTimestamp? {
        if let endStr, let end = try? timeParser.parse(endStr) {
            return end
        }
        if let durStr, let dur = try? timeParser.parse(durStr) {
            return AudioTimestamp(timeInterval: begin.timeInterval + dur.timeInterval)
        }
        return nil
    }

    fileprivate func isInMetadata() -> Bool {
        elementStack.contains("metadata") || elementStack.contains("head")
    }

    fileprivate func normalizeText(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let normalized = lines.map { line in
            line.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
        }
        return normalized.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
