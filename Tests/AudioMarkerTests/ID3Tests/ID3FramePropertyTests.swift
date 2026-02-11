import Foundation
import Testing

@testable import AudioMarker

@Suite("ID3 Frame Properties")
struct ID3FramePropertyTests {

    // MARK: - frameID

    @Test("text frame returns its ID")
    func textFrameID() {
        let frame = ID3Frame.text(id: "TIT2", text: "Title")
        #expect(frame.frameID == "TIT2")
    }

    @Test("userDefinedText returns TXXX")
    func userDefinedTextFrameID() {
        let frame = ID3Frame.userDefinedText(description: "key", value: "val")
        #expect(frame.frameID == "TXXX")
    }

    @Test("url frame returns its ID")
    func urlFrameID() {
        let frame = ID3Frame.url(id: "WOAR", url: "https://example.com")
        #expect(frame.frameID == "WOAR")
    }

    @Test("userDefinedURL returns WXXX")
    func userDefinedURLFrameID() {
        let frame = ID3Frame.userDefinedURL(description: "key", url: "https://example.com")
        #expect(frame.frameID == "WXXX")
    }

    @Test("comment returns COMM")
    func commentFrameID() {
        let frame = ID3Frame.comment(language: "eng", description: "", text: "hi")
        #expect(frame.frameID == "COMM")
    }

    @Test("attachedPicture returns APIC")
    func attachedPictureFrameID() {
        let frame = ID3Frame.attachedPicture(
            pictureType: 3, mimeType: "image/jpeg", description: "", data: Data())
        #expect(frame.frameID == "APIC")
    }

    @Test("chapter returns CHAP")
    func chapterFrameID() {
        let frame = ID3Frame.chapter(
            elementID: "ch1", startTime: 0, endTime: 1000, subframes: [])
        #expect(frame.frameID == "CHAP")
    }

    @Test("tableOfContents returns CTOC")
    func tableOfContentsFrameID() {
        let frame = ID3Frame.tableOfContents(
            elementID: "toc1", isTopLevel: true, isOrdered: true,
            childElementIDs: [], subframes: [])
        #expect(frame.frameID == "CTOC")
    }

    @Test("unsyncLyrics returns USLT")
    func unsyncLyricsFrameID() {
        let frame = ID3Frame.unsyncLyrics(language: "eng", description: "", text: "lyrics")
        #expect(frame.frameID == "USLT")
    }

    @Test("syncLyrics returns SYLT")
    func syncLyricsFrameID() {
        let frame = ID3Frame.syncLyrics(
            language: "eng", contentType: 1, description: "", events: [])
        #expect(frame.frameID == "SYLT")
    }

    @Test("privateData returns PRIV")
    func privateDataFrameID() {
        let frame = ID3Frame.privateData(owner: "com.test", data: Data())
        #expect(frame.frameID == "PRIV")
    }

    @Test("uniqueFileID returns UFID")
    func uniqueFileIDFrameID() {
        let frame = ID3Frame.uniqueFileID(owner: "com.test", identifier: Data())
        #expect(frame.frameID == "UFID")
    }

    @Test("playCounter returns PCNT")
    func playCounterFrameID() {
        let frame = ID3Frame.playCounter(count: 42)
        #expect(frame.frameID == "PCNT")
    }

    @Test("popularimeter returns POPM")
    func popularimeterFrameID() {
        let frame = ID3Frame.popularimeter(email: "a@b.c", rating: 128, playCount: 0)
        #expect(frame.frameID == "POPM")
    }

    @Test("unknown returns its ID")
    func unknownFrameID() {
        let frame = ID3Frame.unknown(id: "ZZZZ", data: Data())
        #expect(frame.frameID == "ZZZZ")
    }

    // MARK: - ID3Version.displayName

    @Test("v2.3 display name")
    func v23DisplayName() {
        #expect(ID3Version.v2_3.displayName == "ID3v2.3")
    }

    @Test("v2.4 display name")
    func v24DisplayName() {
        #expect(ID3Version.v2_4.displayName == "ID3v2.4")
    }
}
