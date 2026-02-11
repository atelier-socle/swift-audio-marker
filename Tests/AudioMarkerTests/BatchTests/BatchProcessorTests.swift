import Foundation
import Testing

@testable import AudioMarker

@Suite("Batch Processor")
struct BatchProcessorTests {

    let processor = BatchProcessor()

    // MARK: - Helpers

    private func createMP3(title: String? = nil) throws -> URL {
        var frames: [Data] = []
        if let title {
            frames.append(ID3TestHelper.buildTextFrame(id: "TIT2", text: title))
        }
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        return try ID3TestHelper.createTempFile(tagData: tag)
    }

    private func createM4A(title: String? = nil) throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)

        var moovChildren: [Data] = [mvhd]
        if let title {
            let items = [MP4TestHelper.buildILSTTextItem(type: "\u{00A9}nam", text: title)]
            let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: items)
            let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
            let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])
            moovChildren.append(udta)
        }
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: moovChildren)
        let mdat = MP4TestHelper.buildAtom(type: "mdat", data: Data(repeating: 0xFF, count: 128))

        var file = Data()
        file.append(ftyp)
        file.append(moov)
        file.append(mdat)

        return try MP4TestHelper.createTempFile(data: file)
    }

    // MARK: - Read Operations

    @Test("Process read operations returns AudioFileInfo")
    func processRead() async throws {
        let url1 = try createMP3(title: "One")
        let url2 = try createMP3(title: "Two")
        defer { try? FileManager.default.removeItem(at: url1) }
        defer { try? FileManager.default.removeItem(at: url2) }

        let items = [
            BatchItem(url: url1, operation: .read),
            BatchItem(url: url2, operation: .read)
        ]
        let summary = await processor.process(items)

        #expect(summary.total == 2)
        #expect(summary.allSucceeded)
        #expect(summary.readResults.count == 2)

        let titles = Set(summary.readResults.map(\.info.metadata.title))
        #expect(titles.contains("One"))
        #expect(titles.contains("Two"))
    }

    // MARK: - Write Operations

    @Test("Process write operations modifies files")
    func processWrite() async throws {
        let url = try createMP3()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.title = "Batch Written"
        let items = [BatchItem(url: url, operation: .write(info))]
        let summary = await processor.process(items)

        #expect(summary.allSucceeded)

        let readBack = try AudioMarkerEngine().read(from: url)
        #expect(readBack.metadata.title == "Batch Written")
    }

    // MARK: - Strip Operations

    @Test("Process strip operations removes metadata")
    func processStrip() async throws {
        let url = try createMP3(title: "To Remove")
        defer { try? FileManager.default.removeItem(at: url) }

        let items = [BatchItem(url: url, operation: .strip)]
        let summary = await processor.process(items)

        #expect(summary.allSucceeded)

        #expect(throws: AudioMarkerError.self) {
            try AudioMarkerEngine().read(from: url)
        }
    }

    // MARK: - Mixed Operations

    @Test("Process mixed operations returns correct results per type")
    func processMixed() async throws {
        let readURL = try createMP3(title: "Read Me")
        let stripURL = try createMP3(title: "Strip Me")
        defer { try? FileManager.default.removeItem(at: readURL) }
        defer { try? FileManager.default.removeItem(at: stripURL) }

        let items = [
            BatchItem(url: readURL, operation: .read),
            BatchItem(url: stripURL, operation: .strip)
        ]
        let summary = await processor.process(items)

        #expect(summary.total == 2)
        #expect(summary.allSucceeded)
        #expect(summary.readResults.count == 1)
    }

    // MARK: - Error Handling

    @Test("Invalid file produces failure without blocking others")
    func processWithInvalidFile() async throws {
        let goodURL = try createMP3(title: "Good")
        let badURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        try Data(repeating: 0x00, count: 32).write(to: badURL)
        defer { try? FileManager.default.removeItem(at: goodURL) }
        defer { try? FileManager.default.removeItem(at: badURL) }

        let items = [
            BatchItem(url: goodURL, operation: .read),
            BatchItem(url: badURL, operation: .read)
        ]
        let summary = await processor.process(items)

        #expect(summary.total == 2)
        #expect(summary.succeeded == 1)
        #expect(summary.failed == 1)
        #expect(summary.errors.count == 1)
        #expect(summary.errors[0].url == badURL)
    }

    // MARK: - Empty List

    @Test("Process empty list returns empty summary with allSucceeded")
    func processEmptyList() async {
        let summary = await processor.process([])

        #expect(summary.total == 0)
        #expect(summary.allSucceeded)
        #expect(summary.results.isEmpty)
    }

    // MARK: - Progress Reporting

    @Test("processWithProgress emits N+1 progress updates")
    func progressUpdates() async throws {
        let url1 = try createMP3(title: "A")
        let url2 = try createMP3(title: "B")
        defer { try? FileManager.default.removeItem(at: url1) }
        defer { try? FileManager.default.removeItem(at: url2) }

        let items = [
            BatchItem(url: url1, operation: .read),
            BatchItem(url: url2, operation: .read)
        ]

        var updates: [BatchProgress] = []
        for await progress in processor.processWithProgress(items) {
            updates.append(progress)
        }

        // N+1: 1 initial (0/2) + 2 completions.
        #expect(updates.count == 3)
        #expect(updates[0].completed == 0)
        #expect(updates[0].total == 2)
        #expect(updates[0].latestResult == nil)
        #expect(updates.last?.isFinished == true)
        #expect(updates.last?.completed == 2)
    }

    @Test("processWithProgress with empty list emits single finished progress")
    func progressEmptyList() async {
        var updates: [BatchProgress] = []
        for await progress in processor.processWithProgress([]) {
            updates.append(progress)
        }

        #expect(updates.count == 1)
        #expect(updates[0].isFinished)
        #expect(updates[0].total == 0)
    }

    // MARK: - Export Chapters

    @Test("Export chapters creates output file")
    func exportChapters() async throws {
        let chapFrame = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 0, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Intro")])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [chapFrame])
        let sourceURL = try ID3TestHelper.createTempFile(tagData: tag)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let items = [
            BatchItem(
                url: sourceURL,
                operation: .exportChapters(format: .podloveJSON, outputURL: outputURL)
            )
        ]
        let summary = await processor.process(items)

        #expect(summary.allSucceeded)
        let content = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(content.contains("Intro"))
    }

    // MARK: - Import Chapters

    @Test("Import chapters writes chapters to file")
    func importChapters() async throws {
        let url = try createMP3(title: "Import Target")
        defer { try? FileManager.default.removeItem(at: url) }

        let json = """
            {
              "version": "1.2",
              "chapters": [
                { "start": "00:00:00.000", "title": "Imported Chapter" }
              ]
            }
            """
        let items = [
            BatchItem(
                url: url,
                operation: .importChapters(json, format: .podloveJSON)
            )
        ]
        let summary = await processor.process(items)

        #expect(summary.allSucceeded)

        let chapters = try AudioMarkerEngine().readChapters(from: url)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Imported Chapter")
    }

    // MARK: - Default Configuration

    @Test("Default processor uses default engine and maxConcurrency 4")
    func defaultConfiguration() {
        let proc = BatchProcessor()
        #expect(proc.maxConcurrency == 4)
        #expect(proc.engine.configuration == .default)
    }

    @Test("Custom maxConcurrency is respected")
    func customMaxConcurrency() {
        let proc = BatchProcessor(maxConcurrency: 2)
        #expect(proc.maxConcurrency == 2)
    }

    @Test("maxConcurrency clamped to at least 1")
    func maxConcurrencyClamped() {
        let proc = BatchProcessor(maxConcurrency: 0)
        #expect(proc.maxConcurrency == 1)
    }
}
