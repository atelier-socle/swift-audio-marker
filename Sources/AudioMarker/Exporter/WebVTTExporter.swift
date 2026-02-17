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

/// Parses and exports synchronized lyrics in WebVTT format.
///
/// WebVTT (Web Video Text Tracks) is the standard subtitle format for the web.
/// Each cue has a start and end timestamp in `HH:MM:SS.mmm` or `MM:SS.mmm` format,
/// separated by ` --> `.
///
/// ```
/// WEBVTT
///
/// 1
/// 00:00:05.000 --> 00:00:08.500
/// Welcome to the show
/// ```
public enum WebVTTExporter: Sendable {

    // MARK: - Export

    /// Exports synchronized lyrics to WebVTT format.
    ///
    /// When multiple ``SynchronizedLyrics`` are provided, all lines are merged
    /// and sorted by time. The end time of each cue is computed from the next
    /// cue's start time or from `audioDuration` for the last cue.
    /// - Parameters:
    ///   - lyrics: The synchronized lyrics to export.
    ///   - audioDuration: Optional total audio duration for the last cue's end time.
    /// - Returns: A WebVTT-formatted string.
    public static func export(
        _ lyrics: [SynchronizedLyrics],
        audioDuration: AudioTimestamp? = nil
    ) -> String {
        let allLines = lyrics.flatMap(\.lines).sorted { $0.time < $1.time }
        guard !allLines.isEmpty else { return "WEBVTT\n" }

        var result = "WEBVTT\n"

        for (index, line) in allLines.enumerated() {
            let endTime: AudioTimestamp
            if index + 1 < allLines.count {
                endTime = allLines[index + 1].time
            } else if let duration = audioDuration {
                endTime = duration
            } else {
                // Default: add 5 seconds to start.
                endTime = AudioTimestamp(timeInterval: line.time.timeInterval + 5.0)
            }

            result += "\n\(index + 1)\n"
            result += "\(formatTimestamp(line.time)) --> \(formatTimestamp(endTime))\n"
            result += "\(line.text)\n"
        }

        return result
    }

    // MARK: - Parse

    /// Parses a WebVTT string into synchronized lyrics.
    /// - Parameters:
    ///   - string: The WebVTT content to parse.
    ///   - language: ISO 639-2 language code. Defaults to `"und"`.
    /// - Returns: A ``SynchronizedLyrics`` with the parsed cues.
    /// - Throws: ``ExportError/invalidFormat(_:)`` if the header is missing.
    ///           ``ExportError/invalidData(_:)`` if no valid cues are found.
    public static func parse(_ string: String, language: String = "und") throws -> SynchronizedLyrics {
        let rawLines = string.components(separatedBy: .newlines)
        guard !rawLines.isEmpty else {
            throw ExportError.invalidFormat("Empty WebVTT input.")
        }

        // Validate WEBVTT header.
        let firstNonEmpty = rawLines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let header = firstNonEmpty,
            header.trimmingCharacters(in: .whitespaces).hasPrefix("WEBVTT")
        else {
            throw ExportError.invalidFormat("Missing WEBVTT header.")
        }

        let lines = parseCues(from: rawLines)

        guard !lines.isEmpty else {
            throw ExportError.invalidData("No valid cues found in WebVTT input.")
        }

        return SynchronizedLyrics(language: language, lines: lines)
    }

    // MARK: - Private

    /// Parses cues from raw WebVTT lines.
    private static func parseCues(from rawLines: [String]) -> [LyricLine] {
        var lines: [LyricLine] = []
        var index = skipHeader(in: rawLines)

        while index < rawLines.count {
            let trimmed = rawLines[index].trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("NOTE") {
                index = skipNoteBlock(from: index, in: rawLines)
                continue
            }

            let (cue, nextIndex) = parseSingleCue(from: index, trimmed: trimmed, in: rawLines)
            index = nextIndex
            if let cue { lines.append(cue) }
        }

        return lines
    }

    /// Skips the WebVTT header block, returning the index after it.
    private static func skipHeader(in rawLines: [String]) -> Int {
        var index = 0
        while index < rawLines.count {
            let trimmed = rawLines[index].trimmingCharacters(in: .whitespaces)
            index += 1
            if trimmed.isEmpty { break }
        }
        return index
    }

    /// Skips a NOTE comment block, returning the index after it.
    private static func skipNoteBlock(from start: Int, in rawLines: [String]) -> Int {
        var index = start + 1
        while index < rawLines.count
            && !rawLines[index].trimmingCharacters(in: .whitespaces).isEmpty
        {
            index += 1
        }
        return index
    }

    /// Parses a single cue starting at the given index.
    /// - Returns: A tuple of an optional `LyricLine` and the next index to process.
    private static func parseSingleCue(
        from start: Int, trimmed: String, in rawLines: [String]
    ) -> (LyricLine?, Int) {
        var index = start

        // Resolve the timestamp line (may be this line or the next if this is a cue number).
        let tsLine: String
        if trimmed.contains("-->") {
            tsLine = trimmed
        } else {
            index += 1
            guard index < rawLines.count else { return (nil, index) }
            let nextTrimmed = rawLines[index].trimmingCharacters(in: .whitespaces)
            guard nextTrimmed.contains("-->") else { return (nil, index + 1) }
            tsLine = nextTrimmed
        }
        index += 1

        guard let startTime = parseTimestampLine(tsLine) else {
            return (nil, index + 1)
        }

        let (text, nextIndex) = collectCueText(from: index, in: rawLines)
        guard !text.isEmpty else { return (nil, nextIndex) }
        return (LyricLine(time: startTime, text: text), nextIndex)
    }

    /// Collects text lines for a cue until a blank line.
    private static func collectCueText(from start: Int, in rawLines: [String]) -> (String, Int) {
        var parts: [String] = []
        var index = start
        while index < rawLines.count {
            let textTrimmed = rawLines[index].trimmingCharacters(in: .whitespaces)
            if textTrimmed.isEmpty { break }
            parts.append(stripHTMLTags(textTrimmed))
            index += 1
        }
        return (parts.joined(separator: " "), index)
    }

    /// Parses the start timestamp from a WebVTT timestamp line.
    ///
    /// Format: `HH:MM:SS.mmm --> HH:MM:SS.mmm` or `MM:SS.mmm --> MM:SS.mmm`.
    private static func parseTimestampLine(_ line: String) -> AudioTimestamp? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else { return nil }
        let startStr = parts[0].trimmingCharacters(in: .whitespaces)
        return parseTimestamp(startStr)
    }

    /// Parses a single WebVTT timestamp.
    ///
    /// Supports `HH:MM:SS.mmm` and `MM:SS.mmm`.
    private static func parseTimestamp(_ string: String) -> AudioTimestamp? {
        let components = string.split(separator: ":")
        guard components.count == 2 || components.count == 3 else { return nil }

        let hours: Int
        let minutes: Int
        let secondsPart: Substring

        if components.count == 3 {
            guard let h = Int(components[0]), let m = Int(components[1]) else { return nil }
            hours = h
            minutes = m
            secondsPart = components[2]
        } else {
            guard let m = Int(components[0]) else { return nil }
            hours = 0
            minutes = m
            secondsPart = components[1]
        }

        guard let (seconds, millis) = parseSecondsAndMillis(secondsPart, separator: ".") else {
            return nil
        }
        let totalMs = hours * 3_600_000 + minutes * 60_000 + seconds * 1000 + millis
        return .milliseconds(totalMs)
    }

    /// Parses the seconds and normalized milliseconds from a `SS.mmm` or `SS,mmm` component.
    private static func parseSecondsAndMillis(
        _ part: Substring, separator: Character
    ) -> (seconds: Int, millis: Int)? {
        let components = part.split(separator: separator, maxSplits: 1)
        guard components.count == 2 else { return nil }
        guard let seconds = Int(components[0]), let rawMillis = Int(components[1]) else {
            return nil
        }
        let normalized: Int
        switch components[1].count {
        case 1: normalized = rawMillis * 100
        case 2: normalized = rawMillis * 10
        default: normalized = rawMillis
        }
        return (seconds, normalized)
    }

    /// Formats a timestamp as `HH:MM:SS.mmm`.
    private static func formatTimestamp(_ timestamp: AudioTimestamp) -> String {
        timestamp.description
    }

    /// Strips basic HTML tags from text.
    private static func stripHTMLTags(_ text: String) -> String {
        var result = text
        // Remove common VTT/HTML tags: <v>, <c>, <b>, <i>, <u>, and their closing variants.
        let tagPattern = "</?[a-zA-Z][^>]*>"
        if let regex = try? NSRegularExpression(pattern: tagPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return result
    }
}
