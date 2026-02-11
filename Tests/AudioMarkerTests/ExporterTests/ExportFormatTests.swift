import Testing

@testable import AudioMarker

@Suite("Export Format")
struct ExportFormatTests {

    @Test("Has five cases")
    func caseCount() {
        #expect(ExportFormat.allCases.count == 5)
    }

    @Test("Podlove JSON has json extension")
    func podloveJSONExtension() {
        #expect(ExportFormat.podloveJSON.fileExtension == "json")
    }

    @Test("Podlove XML has xml extension")
    func podloveXMLExtension() {
        #expect(ExportFormat.podloveXML.fileExtension == "xml")
    }

    @Test("MP4Chaps has txt extension")
    func mp4chapsExtension() {
        #expect(ExportFormat.mp4chaps.fileExtension == "txt")
    }

    @Test("FFMetadata has ini extension")
    func ffmetadataExtension() {
        #expect(ExportFormat.ffmetadata.fileExtension == "ini")
    }

    @Test("Markdown has md extension")
    func markdownExtension() {
        #expect(ExportFormat.markdown.fileExtension == "md")
    }

    @Test("All formats except markdown support import")
    func supportsImport() {
        #expect(ExportFormat.podloveJSON.supportsImport)
        #expect(ExportFormat.podloveXML.supportsImport)
        #expect(ExportFormat.mp4chaps.supportsImport)
        #expect(ExportFormat.ffmetadata.supportsImport)
        #expect(!ExportFormat.markdown.supportsImport)
    }

    // MARK: - ExportError Descriptions

    @Test("importNotSupported has description")
    func importNotSupportedDescription() {
        let error = ExportError.importNotSupported("markdown")
        #expect(error.errorDescription?.contains("markdown") == true)
    }

    @Test("invalidData has description")
    func invalidDataDescription() {
        let error = ExportError.invalidData("bad bytes")
        #expect(error.errorDescription?.contains("bad bytes") == true)
    }

    @Test("invalidFormat has description")
    func invalidFormatDescription() {
        let error = ExportError.invalidFormat("missing field")
        #expect(error.errorDescription?.contains("missing field") == true)
    }

    @Test("ioError has description")
    func ioErrorDescription() {
        let error = ExportError.ioError("disk full")
        #expect(error.errorDescription?.contains("disk full") == true)
    }
}
