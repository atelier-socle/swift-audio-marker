import ArgumentParser
import AudioMarker
import Foundation

extension Chapters {

    /// Adds a chapter to an audio file.
    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add a chapter to an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Option(name: .long, help: "Chapter start time (HH:MM:SS or HH:MM:SS.mmm).")
        var start: String

        @Option(name: .long, help: "Chapter title.")
        var title: String

        @Option(name: .long, help: "Chapter URL.")
        var url: String?

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)
            let engine = AudioMarkerEngine()

            var info: AudioFileInfo
            do {
                info = try engine.read(from: fileURL)
            } catch {
                info = AudioFileInfo()
            }

            let timestamp = try AudioTimestamp(string: start)
            let chapterURL = url.flatMap { URL(string: $0) }
            let chapter = Chapter(start: timestamp, title: title, url: chapterURL)

            info.chapters.append(chapter)
            info.chapters.sort()

            try engine.modify(info, in: fileURL)
            print("Added chapter \"\(title)\" at \(timestamp.shortDescription).")
        }
    }
}
