import Foundation
import Testing

@testable import AudioMarker

@Suite("Batch Result")
struct BatchResultTests {

    private let sampleItem = BatchItem(
        url: URL(fileURLWithPath: "/tmp/test.mp3"),
        operation: .read
    )

    // MARK: - Success with Info

    @Test("Success with info has correct properties")
    func successWithInfo() {
        let info = AudioFileInfo(metadata: AudioMetadata(title: "Test"))
        let result = BatchResult(item: sampleItem, outcome: .success(info))

        #expect(result.isSuccess)
        #expect(result.info?.metadata.title == "Test")
        #expect(result.error == nil)
    }

    // MARK: - Success without Info

    @Test("Success with nil info has correct properties")
    func successWithNilInfo() {
        let result = BatchResult(item: sampleItem, outcome: .success(nil))

        #expect(result.isSuccess)
        #expect(result.info == nil)
        #expect(result.error == nil)
    }

    // MARK: - Failure

    @Test("Failure has correct properties")
    func failureResult() {
        let error = AudioMarkerError.readFailed("test error")
        let result = BatchResult(item: sampleItem, outcome: .failure(error))

        #expect(!result.isSuccess)
        #expect(result.info == nil)
        #expect(result.error != nil)
    }

    @Test("Failure preserves original item")
    func failurePreservesItem() {
        let error = AudioMarkerError.readFailed("test")
        let result = BatchResult(item: sampleItem, outcome: .failure(error))

        #expect(result.item == sampleItem)
    }
}
