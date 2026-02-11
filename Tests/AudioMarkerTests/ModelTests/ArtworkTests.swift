import Foundation
import Testing

@testable import AudioMarker

@Suite("Artwork")
struct ArtworkTests {

    // MARK: - ArtworkFormat detection

    @Test("ArtworkFormat detects JPEG from magic bytes")
    func detectJPEG() {
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        #expect(ArtworkFormat.detect(from: jpegData) == .jpeg)
    }

    @Test("ArtworkFormat detects PNG from magic bytes")
    func detectPNG() {
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])
        #expect(ArtworkFormat.detect(from: pngData) == .png)
    }

    @Test("ArtworkFormat returns nil for unrecognized data")
    func detectUnrecognized() {
        let randomData = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        #expect(ArtworkFormat.detect(from: randomData) == nil)
    }

    @Test("ArtworkFormat returns nil for data shorter than 4 bytes")
    func detectTooShort() {
        let shortData = Data([0xFF, 0xD8])
        #expect(ArtworkFormat.detect(from: shortData) == nil)
    }

    @Test("ArtworkFormat returns nil for empty data")
    func detectEmpty() {
        #expect(ArtworkFormat.detect(from: Data()) == nil)
    }

    // MARK: - MIME types

    @Test("ArtworkFormat.jpeg has correct MIME type")
    func jpegMimeType() {
        #expect(ArtworkFormat.jpeg.mimeType == "image/jpeg")
    }

    @Test("ArtworkFormat.png has correct MIME type")
    func pngMimeType() {
        #expect(ArtworkFormat.png.mimeType == "image/png")
    }

    // MARK: - Artwork init with explicit format

    @Test("Init with explicit data and format")
    func initExplicit() {
        let data = Data([0x01, 0x02, 0x03])
        let artwork = Artwork(data: data, format: .jpeg)
        #expect(artwork.data == data)
        #expect(artwork.format == .jpeg)
    }

    // MARK: - Artwork auto-detection

    @Test("Auto-detects JPEG format")
    func autoDetectJPEG() throws {
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        let artwork = try Artwork(data: jpegData)
        #expect(artwork.format == .jpeg)
    }

    @Test("Auto-detects PNG format")
    func autoDetectPNG() throws {
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])
        let artwork = try Artwork(data: pngData)
        #expect(artwork.format == .png)
    }

    @Test("Auto-detection throws on unrecognized data")
    func autoDetectFailure() {
        let randomData = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        #expect(throws: ArtworkError.unrecognizedFormat) {
            try Artwork(data: randomData)
        }
    }

    // MARK: - Artwork from file URL

    @Test("Init from non-existent file throws fileNotFound")
    func initFromNonExistentFile() {
        let url = URL(fileURLWithPath: "/nonexistent/image.jpg")
        #expect(throws: ArtworkError.self) {
            try Artwork(contentsOf: url)
        }
    }

    // MARK: - Artwork from valid file

    @Test("Init from valid JPEG file")
    func initFromValidFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".jpg")
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 100)
        try jpegData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let artwork = try Artwork(contentsOf: url)
        #expect(artwork.format == .jpeg)
        #expect(artwork.data == jpegData)
    }

    @Test("Init from valid PNG file")
    func initFromPNGFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".png")
        let pngData = Data([0x89, 0x50, 0x4E, 0x47]) + Data(repeating: 0x00, count: 100)
        try pngData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let artwork = try Artwork(contentsOf: url)
        #expect(artwork.format == .png)
    }

    @Test("Init from file with unrecognized format throws")
    func initFromFileUnrecognizedFormat() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".dat")
        try Data([0x00, 0x01, 0x02, 0x03, 0x04]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: ArtworkError.unrecognizedFormat) {
            _ = try Artwork(contentsOf: url)
        }
    }

    // MARK: - Error descriptions

    @Test("unrecognizedFormat error provides meaningful description")
    func unrecognizedFormatDescription() {
        let error = ArtworkError.unrecognizedFormat
        #expect(error.errorDescription?.contains("JPEG") == true)
    }

    @Test("fileNotFound error includes path in description")
    func fileNotFoundDescription() {
        let error = ArtworkError.fileNotFound("/some/path.jpg")
        #expect(error.errorDescription?.contains("/some/path.jpg") == true)
    }
}
