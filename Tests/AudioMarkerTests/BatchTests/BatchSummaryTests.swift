import Foundation
import Testing

@testable import AudioMarker

@Suite("Batch Summary")
struct BatchSummaryTests {

    private let readItem = BatchItem(
        url: URL(fileURLWithPath: "/tmp/a.mp3"),
        operation: .read
    )

    private let stripItem = BatchItem(
        url: URL(fileURLWithPath: "/tmp/b.mp3"),
        operation: .strip
    )

    // MARK: - All Succeeded

    @Test("All succeeded summary")
    func allSucceeded() {
        let info = AudioFileInfo(metadata: AudioMetadata(title: "A"))
        let results = [
            BatchResult(item: readItem, outcome: .success(info)),
            BatchResult(item: stripItem, outcome: .success(nil))
        ]
        let summary = BatchSummary(results: results)

        #expect(summary.total == 2)
        #expect(summary.succeeded == 2)
        #expect(summary.failed == 0)
        #expect(summary.allSucceeded)
    }

    // MARK: - Mixed Results

    @Test("Mixed results have correct counts")
    func mixedResults() {
        let info = AudioFileInfo(metadata: AudioMetadata(title: "A"))
        let error = AudioMarkerError.readFailed("fail")
        let results = [
            BatchResult(item: readItem, outcome: .success(info)),
            BatchResult(item: stripItem, outcome: .failure(error))
        ]
        let summary = BatchSummary(results: results)

        #expect(summary.total == 2)
        #expect(summary.succeeded == 1)
        #expect(summary.failed == 1)
        #expect(!summary.allSucceeded)
    }

    // MARK: - All Failed

    @Test("All failed summary")
    func allFailed() {
        let error = AudioMarkerError.readFailed("fail")
        let results = [
            BatchResult(item: readItem, outcome: .failure(error)),
            BatchResult(item: stripItem, outcome: .failure(error))
        ]
        let summary = BatchSummary(results: results)

        #expect(summary.succeeded == 0)
        #expect(summary.failed == 2)
        #expect(!summary.allSucceeded)
    }

    // MARK: - Errors Extraction

    @Test("errors list contains failed items")
    func errorsExtraction() {
        let error = AudioMarkerError.readFailed("oops")
        let results = [
            BatchResult(item: readItem, outcome: .success(AudioFileInfo())),
            BatchResult(item: stripItem, outcome: .failure(error))
        ]
        let summary = BatchSummary(results: results)

        #expect(summary.errors.count == 1)
        #expect(summary.errors[0].url == stripItem.url)
    }

    // MARK: - Read Results Extraction

    @Test("readResults extracts successful reads with info")
    func readResultsExtraction() {
        let info = AudioFileInfo(metadata: AudioMetadata(title: "Found"))
        let results = [
            BatchResult(item: readItem, outcome: .success(info)),
            BatchResult(item: stripItem, outcome: .success(nil))
        ]
        let summary = BatchSummary(results: results)

        #expect(summary.readResults.count == 1)
        #expect(summary.readResults[0].url == readItem.url)
        #expect(summary.readResults[0].info.metadata.title == "Found")
    }

    // MARK: - Empty

    @Test("Empty results produce empty summary with allSucceeded")
    func emptyResults() {
        let summary = BatchSummary(results: [])

        #expect(summary.total == 0)
        #expect(summary.succeeded == 0)
        #expect(summary.failed == 0)
        #expect(summary.allSucceeded)
        #expect(summary.errors.isEmpty)
        #expect(summary.readResults.isEmpty)
    }
}
