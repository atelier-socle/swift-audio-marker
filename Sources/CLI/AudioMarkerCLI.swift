import ArgumentParser

@main
struct AudioMarkerCLI: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "audiomarker",
    abstract: "Enrich audio files with chapters, metadata, and artwork."
  )

  func run() throws {}
}
