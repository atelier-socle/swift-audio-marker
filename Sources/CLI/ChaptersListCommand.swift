import ArgumentParser
import AudioMarker
import Foundation

extension Chapters {

    /// Lists chapters in an audio file.
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List chapters in an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        mutating func run() throws {
            let url = CLIHelpers.resolveURL(file)
            let engine = AudioMarkerEngine()
            let chapters = try engine.readChapters(from: url)

            if chapters.isEmpty {
                print("No chapters found in \(url.lastPathComponent).")
                return
            }

            print("Chapters (\(chapters.count)) in \(url.lastPathComponent):")
            for (index, chapter) in chapters.enumerated() {
                let number = index + 1
                print("  \(number). \(chapter.start.shortDescription) \u{2014} \(chapter.title)")
            }
        }
    }
}
