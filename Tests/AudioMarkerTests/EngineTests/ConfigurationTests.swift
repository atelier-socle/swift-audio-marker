import Testing

@testable import AudioMarker

@Suite("Configuration")
struct ConfigurationTests {

    @Test("Default configuration has expected values")
    func defaultValues() {
        let config = Configuration.default
        #expect(config.id3Version == .v2_3)
        #expect(config.validateBeforeWriting == true)
        #expect(config.preserveUnknownData == true)
        #expect(config.id3PaddingSize == 2048)
    }

    @Test("Custom configuration stores values")
    func customValues() {
        let config = Configuration(
            id3Version: .v2_4,
            validateBeforeWriting: false,
            preserveUnknownData: false,
            id3PaddingSize: 4096)
        #expect(config.id3Version == .v2_4)
        #expect(config.validateBeforeWriting == false)
        #expect(config.preserveUnknownData == false)
        #expect(config.id3PaddingSize == 4096)
    }

    @Test("Hashable conformance")
    func hashable() {
        let a = Configuration.default
        let b = Configuration.default
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)

        let c = Configuration(id3Version: .v2_4)
        #expect(a != c)
    }
}
