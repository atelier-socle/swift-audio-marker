import ArgumentParser
import AudioMarker
import Foundation

/// Strips all metadata and chapters from an audio file.
struct Strip: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Strip all metadata and chapters from an audio file."
    )

    @Argument(help: "Path to the audio file.")
    var file: String

    @Flag(name: .long, help: "Skip confirmation prompt.")
    var force: Bool = false

    mutating func run() throws {
        let url = CLIHelpers.resolveURL(file)

        if !force {
            print("This will remove ALL metadata from \(url.lastPathComponent). Continue? [y/N] ", terminator: "")
            guard let answer = Swift.readLine(), answer.lowercased() == "y" else {
                print("Aborted.")
                return
            }
        }

        let engine = AudioMarkerEngine()
        try engine.strip(from: url)
        print("All metadata stripped from \(url.lastPathComponent).")
    }
}
