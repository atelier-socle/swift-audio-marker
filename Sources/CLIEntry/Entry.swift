import AudioMarkerCommands

@available(macOS 14, iOS 17, macCatalyst 17, visionOS 1, *)
@main
enum Entry {
    static func main() async {
        await AudioMarkerCLI.main()
    }
}
