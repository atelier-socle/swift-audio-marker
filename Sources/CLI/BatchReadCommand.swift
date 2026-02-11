import ArgumentParser
import AudioMarker
import Foundation

extension Batch {

    /// Reads metadata from all audio files in a directory.
    struct BatchRead: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "read",
            abstract: "Read metadata from all audio files in a directory."
        )

        @Argument(help: "Path to the directory.")
        var directory: String

        @Flag(name: .long, help: "Include subdirectories.")
        var recursive: Bool = false

        @Option(name: .long, help: "Maximum concurrent operations.")
        var concurrency: Int = 4

        mutating func run() async throws {
            let files = try CLIHelpers.findAudioFiles(in: directory, recursive: recursive)

            guard !files.isEmpty else {
                print("No audio files found in \"\(directory)\".")
                return
            }

            print("Reading \(files.count) file(s)...")

            let items = files.map { BatchItem(url: $0, operation: .read) }
            let processor = BatchProcessor(maxConcurrency: concurrency)

            for await progress in processor.processWithProgress(items) {
                guard let result = progress.latestResult else { continue }
                let name = result.item.url.lastPathComponent
                if result.isSuccess {
                    let title = result.info?.metadata.title ?? "Untitled"
                    print("  [\(progress.completed)/\(progress.total)] \(name): \(title)")
                } else {
                    print("  [\(progress.completed)/\(progress.total)] \(name): ERROR")
                }
            }

            let summary = await processor.process(items)
            print()
            print("Done: \(summary.succeeded) succeeded, \(summary.failed) failed.")
        }
    }
}
