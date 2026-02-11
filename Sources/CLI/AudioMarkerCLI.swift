import ArgumentParser

/// Command-line tool for managing audio file metadata and chapters.
@main
struct AudioMarkerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "audiomarker",
        abstract: "Manage audio file metadata, chapters, and artwork.",
        version: "0.1.0",
        subcommands: [
            Read.self,
            Write.self,
            Chapters.self,
            Lyrics.self,
            Strip.self,
            Batch.self,
            Info.self
        ]
    )
}
