import ArgumentParser

/// Manage chapters in audio files.
struct Chapters: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage chapters in audio files.",
        subcommands: [
            List.self,
            Add.self,
            Remove.self,
            Import.self,
            Export.self,
            Clear.self
        ]
    )
}
