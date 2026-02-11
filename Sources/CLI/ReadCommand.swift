import ArgumentParser
import AudioMarker
import Foundation

/// Reads and displays metadata and chapters from an audio file.
struct Read: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Read metadata and chapters from an audio file."
    )

    @Argument(help: "Path to the audio file.")
    var file: String

    @Option(name: .long, help: "Output format: text or json.")
    var format: String = "text"

    mutating func run() throws {
        let url = CLIHelpers.resolveURL(file)
        let engine = AudioMarkerEngine()
        let info = try engine.read(from: url)
        let detected = try engine.detectFormat(of: url)

        if format == "json" {
            printJSON(info, format: detected, url: url)
        } else {
            printText(info, format: detected, url: url)
        }
    }
}

// MARK: - Output Formatting

extension Read {

    private func printText(_ info: AudioFileInfo, format: AudioFormat, url: URL) {
        print("File: \(url.lastPathComponent)")
        print("Format: \(format.rawValue.uppercased())")
        print()

        print("Metadata:")
        printField("Title", info.metadata.title)
        printField("Artist", info.metadata.artist)
        printField("Album", info.metadata.album)
        printField("Year", info.metadata.year.map(String.init))
        printField("Track", info.metadata.trackNumber.map(String.init))
        printField("Disc", info.metadata.discNumber.map(String.init))
        printField("Genre", info.metadata.genre)
        printField("Composer", info.metadata.composer)
        printField("Album Artist", info.metadata.albumArtist)
        printField("Comment", info.metadata.comment)
        printField("BPM", info.metadata.bpm.map(String.init))
        printField("Duration", info.duration?.shortDescription)

        if !info.chapters.isEmpty {
            print()
            print("Chapters (\(info.chapters.count)):")
            for (index, chapter) in info.chapters.enumerated() {
                let number = index + 1
                print("  \(number). \(chapter.start.shortDescription) \u{2014} \(chapter.title)")
            }
        }

        printLyrics(info)
        printSyncLyrics(info)
    }

    private func printLyrics(_ info: AudioFileInfo) {
        guard let lyrics = info.metadata.unsynchronizedLyrics else { return }
        print()
        print("Lyrics:")
        let lines = lyrics.components(separatedBy: .newlines)
        let maxLines = 10
        let maxChars = 500
        var output = ""
        var lineCount = 0
        for line in lines {
            guard lineCount < maxLines && output.count < maxChars else { break }
            if !output.isEmpty { output += "\n" }
            let remaining = maxChars - output.count
            if line.count > remaining {
                output += String(line.prefix(remaining))
            } else {
                output += line
            }
            lineCount += 1
        }
        let truncated = lineCount < lines.count || output.count < lyrics.count
        print("  \(output)\(truncated ? "..." : "")")
    }

    private func printSyncLyrics(_ info: AudioFileInfo) {
        guard !info.metadata.synchronizedLyrics.isEmpty else { return }
        for syncLyrics in info.metadata.synchronizedLyrics {
            print()
            print("Synchronized Lyrics (\(syncLyrics.language), \(syncLyrics.contentType)):")
            let maxLines = 20
            for line in syncLyrics.lines.prefix(maxLines) {
                print("  \(line.time.shortDescription) \(line.text)")
            }
            if syncLyrics.lines.count > maxLines {
                print("  ... (\(syncLyrics.lines.count - maxLines) more lines)")
            }
        }
    }

    private func printField(_ label: String, _ value: String?) {
        guard let value else { return }
        let padding = String(repeating: " ", count: max(0, 14 - label.count))
        print("  \(label):\(padding)\(value)")
    }

    private func printJSON(_ info: AudioFileInfo, format: AudioFormat, url: URL) {
        var dict: [String: Any] = [
            "file": url.lastPathComponent,
            "format": format.rawValue
        ]

        dict["metadata"] = buildMetadataDict(info)

        if !info.chapters.isEmpty {
            dict["chapters"] = info.chapters.map { chapter in
                var chap: [String: Any] = [
                    "start": chapter.start.description,
                    "title": chapter.title
                ]
                if let url = chapter.url { chap["url"] = url.absoluteString }
                return chap
            }
        }

        if let unsyncLyrics = info.metadata.unsynchronizedLyrics {
            dict["unsynchronizedLyrics"] = unsyncLyrics
        }

        if !info.metadata.synchronizedLyrics.isEmpty {
            dict["synchronizedLyrics"] = info.metadata.synchronizedLyrics.map { syncLyrics in
                var entry: [String: Any] = [
                    "language": syncLyrics.language,
                    "contentType": String(describing: syncLyrics.contentType),
                    "descriptor": syncLyrics.descriptor
                ]
                entry["lines"] = syncLyrics.lines.map { line in
                    [
                        "time": line.time.description,
                        "text": line.text
                    ]
                }
                return entry
            }
        }

        if let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            print(String(data: data, encoding: .utf8) ?? "{}")
        }
    }

    private func buildMetadataDict(_ info: AudioFileInfo) -> [String: Any] {
        var meta: [String: Any] = [:]
        if let title = info.metadata.title { meta["title"] = title }
        if let artist = info.metadata.artist { meta["artist"] = artist }
        if let album = info.metadata.album { meta["album"] = album }
        if let year = info.metadata.year { meta["year"] = year }
        if let trackNumber = info.metadata.trackNumber { meta["trackNumber"] = trackNumber }
        if let genre = info.metadata.genre { meta["genre"] = genre }
        if let duration = info.duration { meta["duration"] = duration.description }
        return meta
    }
}
