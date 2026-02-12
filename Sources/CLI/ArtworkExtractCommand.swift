import ArgumentParser
import AudioMarker
import Foundation

extension ArtworkGroup {

    /// Extracts embedded artwork from an audio file and saves it to disk.
    struct Extract: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Extract embedded artwork from an audio file."
        )

        @Argument(help: "Path to the audio file.")
        var file: String

        @Option(name: [.short, .long], help: "Output file path. Defaults to cover.<ext> in current directory.")
        var output: String?

        mutating func run() throws {
            let fileURL = CLIHelpers.resolveURL(file)
            let engine = AudioMarkerEngine()
            let info = try engine.read(from: fileURL)

            guard let artwork = info.metadata.artwork else {
                throw ValidationError("No artwork found in \"\(fileURL.lastPathComponent)\".")
            }

            let outputURL: URL
            if let output {
                outputURL = CLIHelpers.resolveURL(output)
            } else {
                let ext = artwork.format == .png ? "png" : "jpg"
                let cwd = FileManager.default.currentDirectoryPath
                outputURL = URL(fileURLWithPath: cwd).appendingPathComponent("cover.\(ext)")
            }

            try artwork.data.write(to: outputURL)
            let size = CLIHelpers.formatFileSize(UInt64(artwork.data.count))
            print(
                "Artwork extracted to \(outputURL.lastPathComponent) (\(artwork.format.rawValue.uppercased()), \(size))."
            )
        }
    }
}
