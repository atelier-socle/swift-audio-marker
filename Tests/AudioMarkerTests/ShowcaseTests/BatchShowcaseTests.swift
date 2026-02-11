import Foundation
import Testing

@testable import AudioMarker

/// Demonstrates batch processing: parallel reads, progress tracking, mixed operations, error handling.
@Suite("Showcase: Batch Processing")
struct BatchShowcaseTests {

    // MARK: - Batch Read

    @Test("Batch read — process multiple files in parallel")
    func batchRead() async throws {
        // Create 5 synthetic files (3 MP3 + 2 M4A)
        let mp3URLs = try (1...3).map { i in
            try createMP3(title: "MP3 Track \(i)")
        }
        let m4aURLs = try (1...2).map { i in
            try createM4A(title: "M4A Track \(i)")
        }
        let allURLs = mp3URLs + m4aURLs
        defer { for url in allURLs { try? FileManager.default.removeItem(at: url) } }

        // Build batch items
        let items = allURLs.map { BatchItem(url: $0, operation: .read) }

        // Process with bounded concurrency
        let processor = BatchProcessor(maxConcurrency: 2)
        let summary = await processor.process(items)

        // Verify summary
        #expect(summary.total == 5)
        #expect(summary.succeeded == 5)
        #expect(summary.failed == 0)
        #expect(summary.allSucceeded)

        // Read results contain AudioFileInfo for each file
        #expect(summary.readResults.count == 5)
    }

    // MARK: - Progress Tracking

    @Test("Batch read with progress — track completion")
    func batchProgress() async throws {
        let urls = try (1...3).map { i in
            try createMP3(title: "Progress \(i)")
        }
        defer { for url in urls { try? FileManager.default.removeItem(at: url) } }

        let items = urls.map { BatchItem(url: $0, operation: .read) }
        let processor = BatchProcessor(maxConcurrency: 2)

        // Collect progress updates
        var updates: [BatchProgress] = []
        for await progress in processor.processWithProgress(items) {
            updates.append(progress)
        }

        // First update has completed=0 (initial), subsequent updates increment
        #expect(updates.first?.completed == 0)
        #expect(updates.first?.total == 3)

        // Last update is finished
        let last = try #require(updates.last)
        #expect(last.isFinished)
        #expect(last.completed == 3)
        #expect(last.fraction == 1.0)
    }

    // MARK: - Mixed Operations

    @Test("Batch mixed operations — read, write, strip")
    func batchMixed() async throws {
        // Create files for different operations
        let readURL = try createMP3(title: "Read Me")
        let writeURL = try createMP3(title: "Write Target")
        let stripURL = try createMP3(title: "Strip Me")
        defer {
            for url in [readURL, writeURL, stripURL] {
                try? FileManager.default.removeItem(at: url)
            }
        }

        // Prepare write data
        var writeInfo = AudioFileInfo()
        writeInfo.metadata.title = "Written Title"

        let items: [BatchItem] = [
            BatchItem(url: readURL, operation: .read),
            BatchItem(url: writeURL, operation: .write(writeInfo)),
            BatchItem(url: stripURL, operation: .strip)
        ]

        let processor = BatchProcessor()
        let summary = await processor.process(items)
        #expect(summary.total == 3)
        #expect(summary.succeeded == 3)

        // Verify write result
        let engine = AudioMarkerEngine()
        let written = try engine.read(from: writeURL)
        #expect(written.metadata.title == "Written Title")

        // Verify strip result — MP3 no longer has ID3 tag after strip
        #expect(throws: AudioMarkerError.self) {
            _ = try engine.read(from: stripURL)
        }
    }

    // MARK: - Error Handling

    @Test("Batch with errors — graceful failure handling")
    func batchErrors() async throws {
        // Mix of valid and invalid files
        let validURL = try createMP3(title: "Valid")
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        defer { try? FileManager.default.removeItem(at: validURL) }
        // invalidURL doesn't exist — will cause a read failure

        let items = [
            BatchItem(url: validURL, operation: .read),
            BatchItem(url: invalidURL, operation: .read)
        ]

        let processor = BatchProcessor()
        let summary = await processor.process(items)

        // The batch doesn't crash — valid files succeed, invalid fail
        #expect(summary.total == 2)
        #expect(summary.succeeded == 1)
        #expect(summary.failed == 1)
        #expect(!summary.allSucceeded)
        #expect(summary.errors.count == 1)
    }

    // MARK: - Batch Export Chapters

    @Test("Batch export chapters — bulk chapter export")
    func batchExportChapters() async throws {
        // Create files with chapters
        let chap = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 0, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chap")])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [chap])
        let url = try ID3TestHelper.createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let items = [
            BatchItem(
                url: url,
                operation: .exportChapters(format: .podloveJSON, outputURL: outputURL))
        ]

        let processor = BatchProcessor()
        let summary = await processor.process(items)
        #expect(summary.allSucceeded)

        // Verify output file was created
        let content = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(content.contains("Chap"))
    }

    // MARK: - Helpers

    private func createMP3(title: String) throws -> URL {
        let frames = [ID3TestHelper.buildTextFrame(id: "TIT2", text: title)]
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        return try ID3TestHelper.createTempFile(tagData: tag)
    }

    private func createM4A(title: String) throws -> URL {
        let ilstItems = [MP4TestHelper.buildILSTTextItem(type: "\u{00A9}nam", text: title)]
        let fileData = MP4TestHelper.buildMP4WithMetadata(ilstItems: ilstItems)
        return try MP4TestHelper.createTempFile(data: fileData)
    }
}
