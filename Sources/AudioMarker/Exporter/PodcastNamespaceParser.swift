import Foundation

/// Exports and imports chapters in Podcasting 2.0 (podcast-namespace) JSON format.
///
/// Output format:
/// ```json
/// {
///   "version": "1.2.0",
///   "chapters": [
///     { "startTime": 168.5, "title": "Chapter", "url": "https://..." }
///   ]
/// }
/// ```
///
/// Key differences from Podlove Simple Chapters:
/// - `startTime`: number (seconds, possibly decimal), not string
/// - `url` key (not `href`)
/// - `img`, `toc`, `location` fields: ignored on import
public enum PodcastNamespaceParser: Sendable {

    // MARK: - Export

    /// Exports chapters to Podcasting 2.0 JSON format.
    /// - Parameter chapters: The chapters to export.
    /// - Returns: A pretty-printed JSON string.
    /// - Throws: ``ExportError/invalidData(_:)`` if encoding fails.
    public static func export(_ chapters: ChapterList) throws -> String {
        var chapterArray: [[String: Any]] = []
        for chapter in chapters {
            var dict: [String: Any] = [
                "startTime": formatStartTime(chapter.start.timeInterval),
                "title": chapter.title
            ]
            if let url = chapter.url {
                dict["url"] = url.absoluteString
            }
            chapterArray.append(dict)
        }

        let root: [String: Any] = [
            "version": "1.2.0",
            "chapters": chapterArray
        ]

        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])

        guard let string = String(data: data, encoding: .utf8) else {
            throw ExportError.invalidData("Failed to encode JSON as UTF-8.")
        }
        return string
    }

    // MARK: - Import

    /// Imports chapters from Podcasting 2.0 JSON format.
    /// - Parameter string: The JSON string to parse.
    /// - Returns: A ``ChapterList`` with the parsed chapters.
    /// - Throws: ``ExportError`` if the JSON is malformed.
    public static func parse(_ string: String) throws -> ChapterList {
        guard let data = string.data(using: .utf8) else {
            throw ExportError.invalidData("Failed to decode string as UTF-8.")
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ExportError.invalidFormat("Invalid JSON: \(error.localizedDescription)")
        }

        guard let root = object as? [String: Any] else {
            throw ExportError.invalidFormat("Expected a JSON object at root level.")
        }
        guard let chaptersArray = root["chapters"] as? [[String: Any]] else {
            throw ExportError.invalidFormat("Missing or invalid 'chapters' array.")
        }

        var chapters = ChapterList()
        for dict in chaptersArray {
            guard let startTime = dict["startTime"] as? Double else {
                throw ExportError.invalidFormat("Missing or invalid 'startTime' in chapter entry.")
            }
            guard let title = dict["title"] as? String else {
                throw ExportError.invalidFormat("Missing 'title' in chapter entry.")
            }
            let url: URL? = (dict["url"] as? String).flatMap { URL(string: $0) }
            chapters.append(Chapter(start: .seconds(startTime), title: title, url: url))
        }
        return chapters
    }
}

// MARK: - Helpers

extension PodcastNamespaceParser {

    /// Formats a start time as a number, using integer when fractional part is zero.
    private static func formatStartTime(_ seconds: TimeInterval) -> Any {
        let rounded = (seconds * 1000).rounded() / 1000
        if rounded == rounded.rounded(.down) {
            return Int(rounded)
        }
        return rounded
    }
}
