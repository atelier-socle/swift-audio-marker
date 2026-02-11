import Foundation
import Testing

@testable import AudioMarker

@Suite("ID3 Error Descriptions")
struct ID3ErrorTests {

    @Test("noTag has description")
    func noTagDescription() {
        let error = ID3Error.noTag
        #expect(error.errorDescription?.contains("ID3v2 tag") == true)
    }

    @Test("invalidHeader has description with reason")
    func invalidHeaderDescription() {
        let error = ID3Error.invalidHeader("Bad marker")
        #expect(error.errorDescription?.contains("Bad marker") == true)
    }

    @Test("unsupportedVersion has description with version numbers")
    func unsupportedVersionDescription() {
        let error = ID3Error.unsupportedVersion(major: 2, minor: 0)
        #expect(error.errorDescription?.contains("v2.2.0") == true)
    }

    @Test("invalidFrame has description with frame ID and reason")
    func invalidFrameDescription() {
        let error = ID3Error.invalidFrame(id: "APIC", reason: "Too short")
        #expect(error.errorDescription?.contains("APIC") == true)
        #expect(error.errorDescription?.contains("Too short") == true)
    }

    @Test("invalidEncoding has description with hex byte")
    func invalidEncodingDescription() {
        let error = ID3Error.invalidEncoding(0xAB)
        #expect(error.errorDescription?.contains("0xAB") == true)
    }

    @Test("truncatedData has description with sizes")
    func truncatedDataDescription() {
        let error = ID3Error.truncatedData(expected: 100, available: 50)
        #expect(error.errorDescription?.contains("100") == true)
        #expect(error.errorDescription?.contains("50") == true)
    }

    @Test("invalidSyncsafeInteger has description")
    func invalidSyncsafeDescription() {
        let error = ID3Error.invalidSyncsafeInteger
        #expect(error.errorDescription?.contains("syncsafe") == true)
    }

    @Test("writeFailed has description with reason")
    func writeFailedDescription() {
        let error = ID3Error.writeFailed("Disk full")
        #expect(error.errorDescription?.contains("Disk full") == true)
    }
}
