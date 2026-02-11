import ArgumentParser
import AudioMarker
import Foundation

extension Batch {

    /// Strips metadata from all audio files in a directory.
    struct BatchStrip: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "strip",
            abstract: "Strip metadata from all audio files in a directory."
        )

        @Argument(help: "Path to the directory.")
        var directory: String

        @Flag(name: .long, help: "Include subdirectories.")
        var recursive: Bool = false

        @Flag(name: .long, help: "Skip confirmation prompt.")
        var force: Bool = false

        @Option(name: .long, help: "Maximum concurrent operations.")
        var concurrency: Int = 4

        mutating func run() async throws {
            let files = try CLIHelpers.findAudioFiles(in: directory, recursive: recursive)

            guard !files.isEmpty else {
                print("No audio files found in \"\(directory)\".")
                return
            }

            if !force {
                print(
                    "This will strip ALL metadata from \(files.count) file(s). Continue? [y/N] ",
                    terminator: ""
                )
                guard let answer = Swift.readLine(), answer.lowercased() == "y" else {
                    print("Aborted.")
                    return
                }
            }

            print("Stripping \(files.count) file(s)...")

            let items = files.map { BatchItem(url: $0, operation: .strip) }
            let processor = BatchProcessor(maxConcurrency: concurrency)

            for await progress in processor.processWithProgress(items) {
                guard let result = progress.latestResult else { continue }
                let name = result.item.url.lastPathComponent
                if result.isSuccess {
                    print("  [\(progress.completed)/\(progress.total)] \(name): stripped")
                } else {
                    print("  [\(progress.completed)/\(progress.total)] \(name): ERROR")
                }
            }

            let summary = await processor.process(items)
            print()
            print("Done: \(summary.succeeded) stripped, \(summary.failed) failed.")
        }
    }
}
