import ArgumentParser
import AudioMarker
import Foundation

/// Commands for working with synchronized lyrics.
struct Lyrics: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Work with synchronized lyrics.",
        subcommands: [Export.self, Import.self]
    )
}

// MARK: - Export

extension Lyrics {

    /// Exports synchronized lyrics from an audio file.
    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Export synchronized lyrics from an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Option(name: .long, help: "Output file path. Prints to stdout if omitted.")
        var to: String?

        @Option(name: .long, help: "Export format: lrc or ttml.")
        var format: String = "lrc"

        mutating func run() throws {
            let url = CLIHelpers.resolveURL(file)
            let engine = AudioMarkerEngine()
            let info = try engine.read(from: url)

            let allLyrics = info.metadata.synchronizedLyrics
            guard !allLyrics.isEmpty else {
                throw ValidationError("No synchronized lyrics found in \"\(url.lastPathComponent)\".")
            }

            let exportFormat = try CLIHelpers.parseExportFormat(format)

            let output: String
            switch exportFormat {
            case .lrc:
                output = LRCParser.export(allLyrics[0])
            case .ttml:
                let doc = TTMLDocument.from(
                    allLyrics, title: info.metadata.title)
                output = TTMLExporter.exportDocument(doc)
            default:
                throw ValidationError(
                    "Unsupported lyrics export format \"\(format)\". Expected: lrc, ttml."
                )
            }

            if let toPath = to {
                let outputURL = CLIHelpers.resolveURL(toPath)
                try output.write(to: outputURL, atomically: true, encoding: .utf8)
                print("Lyrics exported to \(outputURL.lastPathComponent).")
            } else {
                print(output)
            }
        }
    }
}

// MARK: - Import

extension Lyrics {

    /// Imports synchronized lyrics from a file into an audio file.
    struct Import: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Import synchronized lyrics into an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Option(name: .long, help: "Path to the lyrics file (LRC or TTML).")
        var from: String

        @Option(name: .long, help: "Import format: lrc or ttml.")
        var format: String = "lrc"

        @Option(name: .long, help: "ISO 639-2 language code (3 characters, e.g., eng).")
        var language: String = "und"

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)
            let fromURL = CLIHelpers.resolveURL(from)
            let engine = AudioMarkerEngine()

            let content = try String(contentsOf: fromURL, encoding: .utf8)
            let exportFormat = try CLIHelpers.parseExportFormat(format)

            let lyrics: [SynchronizedLyrics]
            switch exportFormat {
            case .lrc:
                lyrics = [try LRCParser.parse(content, language: language)]
            case .ttml:
                lyrics = try TTMLParser().parseLyrics(from: content)
            default:
                throw ValidationError(
                    "Unsupported lyrics import format \"\(format)\". Expected: lrc, ttml."
                )
            }

            var info: AudioFileInfo
            do {
                info = try engine.read(from: fileURL)
            } catch {
                info = AudioFileInfo()
            }

            info.metadata.synchronizedLyrics = lyrics
            info.metadata.unsynchronizedLyrics = nil
            try engine.modify(info, in: fileURL)

            let count = lyrics.reduce(0) { $0 + $1.lines.count }
            print("Imported \(count) lyric lines from \(fromURL.lastPathComponent).")
        }
    }
}
