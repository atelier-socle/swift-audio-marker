import Testing

@testable import AudioMarker

@Suite("Streaming Constants")
struct StreamingConstantsTests {

    @Test("Default buffer size is 64 KB")
    func defaultBufferSize() {
        #expect(StreamingConstants.defaultBufferSize == 65_536)
    }

    @Test("Minimum buffer size is 4 KB")
    func minimumBufferSize() {
        #expect(StreamingConstants.minimumBufferSize == 4_096)
    }

    @Test("Maximum buffer size is 1 MB")
    func maximumBufferSize() {
        #expect(StreamingConstants.maximumBufferSize == 1_048_576)
    }

    @Test("Minimum is less than default, default is less than maximum")
    func ordering() {
        #expect(StreamingConstants.minimumBufferSize < StreamingConstants.defaultBufferSize)
        #expect(StreamingConstants.defaultBufferSize < StreamingConstants.maximumBufferSize)
    }
}
