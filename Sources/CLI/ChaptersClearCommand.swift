import ArgumentParser
import AudioMarker
import Foundation

extension Chapters {

    /// Removes all chapters from an audio file.
    struct Clear: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove all chapters from an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)
            let engine = AudioMarkerEngine()

            var info: AudioFileInfo
            do {
                info = try engine.read(from: fileURL)
            } catch {
                info = AudioFileInfo()
            }

            info.chapters = ChapterList()
            try engine.modify(info, in: fileURL)
            print("All chapters removed from \(fileURL.lastPathComponent).")
        }
    }
}
