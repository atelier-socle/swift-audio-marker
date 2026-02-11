import ArgumentParser
import AudioMarker
import Foundation

extension Chapters {

    /// Imports chapters from a text file.
    struct Import: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "import",
            abstract: "Import chapters from a text file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Option(name: .long, help: "Path to the chapter file.")
        var from: String

        @Option(name: .long, help: "Chapter format: podlove-json, podlove-xml, mp4chaps, ffmetadata.")
        var format: String = "podlove-json"

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)
            let sourceURL = CLIHelpers.resolveURL(from)
            let exportFormat = try CLIHelpers.parseExportFormat(format)

            let content = try String(contentsOf: sourceURL, encoding: .utf8)
            let engine = AudioMarkerEngine()
            try engine.importChapters(from: content, format: exportFormat, to: fileURL)

            print("Chapters imported from \(sourceURL.lastPathComponent) to \(fileURL.lastPathComponent).")
        }
    }
}
