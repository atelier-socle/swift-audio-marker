import Foundation

@testable import AudioMarker

/// Shared helpers for building synthetic audio files in CLI tests.
enum CLITestHelper {

    static func createMP3(title: String? = nil) throws -> URL {
        var frames: [Data] = []
        if let title {
            frames.append(ID3TestHelper.buildTextFrame(id: "TIT2", text: title))
        }
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: frames)
        return try ID3TestHelper.createTempFile(tagData: tag)
    }

    static func createMP3WithChapters() throws -> URL {
        let titleFrame = ID3TestHelper.buildTextFrame(id: "TIT2", text: "With Chapters")
        let chap1 = ID3TestHelper.buildCHAPFrame(
            elementID: "ch1", startTime: 0, endTime: 60_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Intro")])
        let chap2 = ID3TestHelper.buildCHAPFrame(
            elementID: "ch2", startTime: 60_000, endTime: 120_000,
            subframes: [ID3TestHelper.buildTextFrame(id: "TIT2", text: "Verse")])
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [titleFrame, chap1, chap2])
        return try ID3TestHelper.createTempFile(tagData: tag)
    }

    static func createMP3WithArtwork() throws -> URL {
        let titleFrame = ID3TestHelper.buildTextFrame(id: "TIT2", text: "Art Test")
        let jpegHeader = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let imageData = jpegHeader + Data(repeating: 0x00, count: 64)
        let artFrame = ID3TestHelper.buildAPICFrame(
            mimeType: "image/jpeg", pictureType: 3, description: "",
            imageData: imageData)
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [titleFrame, artFrame])
        return try ID3TestHelper.createTempFile(tagData: tag)
    }

    static func createM4A(title: String? = nil) throws -> URL {
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

    static func createMP3WithUnsyncLyrics(lyrics: String) throws -> URL {
        let titleFrame = ID3TestHelper.buildTextFrame(id: "TIT2", text: "Lyrics Test")
        let usltFrame = ID3TestHelper.buildUSLTFrame(text: lyrics)
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [titleFrame, usltFrame])
        return try ID3TestHelper.createTempFile(tagData: tag)
    }

    static func createMP3WithSyncLyrics(
        events: [(text: String, timestamp: UInt32)]
    ) throws -> URL {
        let titleFrame = ID3TestHelper.buildTextFrame(id: "TIT2", text: "Sync Lyrics Test")
        let syltFrame = ID3TestHelper.buildSYLTFrame(events: events)
        let tag = ID3TestHelper.buildTag(version: .v2_3, frames: [titleFrame, syltFrame])
        return try ID3TestHelper.createTempFile(tagData: tag)
    }

    static func createTempDirectory(files: [String]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in files {
            let fileURL = dir.appendingPathComponent(name)
            if name.hasSuffix(".mp3") {
                let tag = ID3TestHelper.buildTag(
                    version: .v2_3,
                    frames: [ID3TestHelper.buildTextFrame(id: "TIT2", text: name)])
                var data = tag
                data.append(Data(repeating: 0xFF, count: 128))
                try data.write(to: fileURL)
            } else {
                try Data().write(to: fileURL)
            }
        }
        return dir
    }
}
