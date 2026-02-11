import ArgumentParser
import AudioMarker
import Foundation

/// Displays technical information about an audio file.
struct Info: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Display technical information about an audio file."
    )

    @Argument(help: "Path to the audio file.")
    var file: String

    mutating func run() throws {
        let url = CLIHelpers.resolveURL(file)
        let engine = AudioMarkerEngine()
        let format = try engine.detectFormat(of: url)
        let info = try engine.read(from: url)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs[.size] as? UInt64 ?? 0

        print("File:     \(url.lastPathComponent)")
        print("Format:   \(format.rawValue.uppercased())")
        print("Size:     \(CLIHelpers.formatFileSize(fileSize))")

        if let duration = info.duration {
            print("Duration: \(duration.shortDescription)")
        }

        if !info.chapters.isEmpty {
            print("Chapters: \(info.chapters.count)")
        }

        if let artwork = info.metadata.artwork {
            let artFormat = artwork.format.rawValue.uppercased()
            let artSize = CLIHelpers.formatFileSize(UInt64(artwork.data.count))
            print("Artwork:  \(artFormat) (\(artSize))")
        }
    }
}
