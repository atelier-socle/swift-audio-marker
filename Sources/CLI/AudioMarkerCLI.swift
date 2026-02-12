import ArgumentParser

/// Command-line tool for managing audio file metadata and chapters.
@available(macOS 14, iOS 17, macCatalyst 17, visionOS 1, *)
public struct AudioMarkerCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "audio-marker",
        abstract: "Manage audio file metadata, chapters, and artwork.",
        version: "0.1.0",
        subcommands: [
            Read.self,
            Write.self,
            Chapters.self,
            Lyrics.self,
            ArtworkGroup.self,
            Validate.self,
            Strip.self,
            Batch.self,
            Info.self
        ]
    )

    public init() {}
}
