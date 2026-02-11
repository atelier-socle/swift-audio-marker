import Foundation
import Testing

@testable import AudioMarker

@Suite("Error Descriptions")
struct ErrorDescriptionTests {

    // MARK: - StreamingError

    @Test("fileNotFound includes path")
    func streamingFileNotFound() {
        let error = StreamingError.fileNotFound("/tmp/missing.mp3")
        #expect(error.errorDescription?.contains("/tmp/missing.mp3") == true)
    }

    @Test("cannotOpenFile includes path")
    func streamingCannotOpen() {
        let error = StreamingError.cannotOpenFile("/tmp/locked.mp3")
        #expect(error.errorDescription?.contains("/tmp/locked.mp3") == true)
    }

    @Test("readFailed includes detail")
    func streamingReadFailed() {
        let error = StreamingError.readFailed("Unexpected EOF")
        #expect(error.errorDescription?.contains("Unexpected EOF") == true)
    }

    @Test("writeFailed includes detail")
    func streamingWriteFailed() {
        let error = StreamingError.writeFailed("Disk full")
        #expect(error.errorDescription?.contains("Disk full") == true)
    }

    @Test("outOfBounds includes offset and size")
    func streamingOutOfBounds() {
        let error = StreamingError.outOfBounds(offset: 999, fileSize: 100)
        #expect(error.errorDescription?.contains("999") == true)
        #expect(error.errorDescription?.contains("100") == true)
    }

    @Test("invalidBufferSize includes size")
    func streamingInvalidBuffer() {
        let error = StreamingError.invalidBufferSize(500)
        #expect(error.errorDescription?.contains("500") == true)
    }

    @Test("fileTooSmall includes sizes")
    func streamingFileTooSmall() {
        let error = StreamingError.fileTooSmall(expected: 1024, actual: 10)
        #expect(error.errorDescription?.contains("1024") == true)
        #expect(error.errorDescription?.contains("10") == true)
    }

    // MARK: - BinaryReaderError

    @Test("unexpectedEndOfData includes offset and counts")
    func binaryReaderEndOfData() {
        let error = BinaryReaderError.unexpectedEndOfData(
            offset: 10, requested: 4, available: 2)
        #expect(error.errorDescription?.contains("10") == true)
        #expect(error.errorDescription?.contains("4") == true)
    }

    @Test("invalidEncoding includes offset")
    func binaryReaderInvalidEncoding() {
        let error = BinaryReaderError.invalidEncoding(offset: 42)
        #expect(error.errorDescription?.contains("42") == true)
    }

    @Test("seekOutOfBounds includes offset and size")
    func binaryReaderSeekOutOfBounds() {
        let error = BinaryReaderError.seekOutOfBounds(offset: 100, dataSize: 50)
        #expect(error.errorDescription?.contains("100") == true)
        #expect(error.errorDescription?.contains("50") == true)
    }

    // MARK: - FileWriter.synchronize

    @Test("synchronize flushes without error")
    func fileWriterSynchronize() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try FileWriter(url: url)
        try writer.write(Data([0x01, 0x02, 0x03]))
        writer.synchronize()
        writer.close()

        let reader = try FileReader(url: url)
        defer { reader.close() }
        #expect(reader.fileSize == 3)
    }
}
