import ArgumentParser

/// Manage artwork in audio files.
struct ArtworkGroup: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "artwork",
        abstract: "Manage artwork in audio files.",
        subcommands: [Extract.self]
    )
}
