import ArgumentParser

/// Process multiple audio files in a directory.
struct Batch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Process multiple audio files in a directory.",
        subcommands: [
            BatchRead.self,
            BatchStrip.self
        ]
    )
}
