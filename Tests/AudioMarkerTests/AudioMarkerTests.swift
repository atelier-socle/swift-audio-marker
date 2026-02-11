import Testing

@testable import AudioMarker

@Suite("AudioMarker")
struct AudioMarkerTests {

    @Test("AudioMarker struct can be instantiated")
    func instantiation() {
        _ = AudioMarker()
    }
}
