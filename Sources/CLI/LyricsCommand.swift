import ArgumentParser
import AudioMarker
import Foundation

/// Commands for working with synchronized lyrics.
struct Lyrics: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Work with synchronized lyrics.",
        subcommands: [Export.self]
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

            guard let syncLyrics = info.metadata.synchronizedLyrics.first else {
                throw ValidationError("No synchronized lyrics found in \"\(url.lastPathComponent)\".")
            }

            let exportFormat = try CLIHelpers.parseExportFormat(format)

            let output: String
            switch exportFormat {
            case .lrc:
                output = LRCParser.export(syncLyrics)
            case .ttml:
                output = TTMLExporter.export(
                    syncLyrics,
                    audioDuration: info.duration,
                    title: info.metadata.title
                )
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
