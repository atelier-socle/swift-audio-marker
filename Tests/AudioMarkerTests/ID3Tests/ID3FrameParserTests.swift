// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation
import Testing

@testable import AudioMarker

@Suite("ID3 Frame Parser")
struct ID3FrameParserTests {

    // MARK: - Text Frames

    @Test("Parses Latin-1 text frame (TIT2)")
    func parseTextFrameLatin1() throws {
        let frameData = ID3TestHelper.buildTextFrame(
            id: "TIT2", text: "Hello World"
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .text(id: "TIT2", text: "Hello World"))
    }

    @Test("Parses UTF-8 text frame (v2.4)")
    func parseTextFrameUTF8() throws {
        let frameData = ID3TestHelper.buildTextFrame(
            id: "TIT2", text: "Caf\u{00E9}",
            encoding: .utf8, version: .v2_4
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_4)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .text(id: "TIT2", text: "Caf\u{00E9}"))
    }

    @Test("Parses UTF-16 with BOM text frame")
    func parseTextFrameUTF16BOM() throws {
        let frameData = ID3TestHelper.buildTextFrame(
            id: "TIT2", text: "Hello", encoding: .utf16WithBOM
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .text(id: "TIT2", text: "Hello"))
    }

    // MARK: - User-Defined Text Frame (TXXX)

    @Test("Parses TXXX frame")
    func parseTXXX() throws {
        let frameData = ID3TestHelper.buildTXXXFrame(
            description: "REPLAYGAIN_TRACK_GAIN", value: "-6.5 dB"
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(
            frame
                == .userDefinedText(
                    description: "REPLAYGAIN_TRACK_GAIN", value: "-6.5 dB"
                ))
    }

    // MARK: - Comment Frame (COMM)

    @Test("Parses COMM frame with language")
    func parseCOMM() throws {
        let frameData = ID3TestHelper.buildCOMMFrame(
            language: "eng", description: "", text: "A great track"
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(
            frame
                == .comment(
                    language: "eng", description: "", text: "A great track"
                ))
    }

    // MARK: - URL Frames

    @Test("Parses URL frame (WOAR)")
    func parseURLFrame() throws {
        let frameData = ID3TestHelper.buildURLFrame(
            id: "WOAR", url: "https://example.com/artist"
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .url(id: "WOAR", url: "https://example.com/artist"))
    }

    @Test("Parses WXXX frame")
    func parseWXXX() throws {
        let frameData = ID3TestHelper.buildWXXXFrame(
            description: "podcast", url: "https://example.com/podcast"
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(
            frame
                == .userDefinedURL(
                    description: "podcast", url: "https://example.com/podcast"
                ))
    }

    // MARK: - Attached Picture Frame (APIC)

    @Test("Parses APIC frame")
    func parseAPIC() throws {
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        let frameData = ID3TestHelper.buildAPICFrame(
            mimeType: "image/jpeg", pictureType: 3,
            description: "Cover", imageData: jpegData
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(
            frame
                == .attachedPicture(
                    pictureType: 3, mimeType: "image/jpeg",
                    description: "Cover", data: jpegData
                ))
    }

    // MARK: - Chapter Frame (CHAP)

    @Test("Parses CHAP frame with sub-frames")
    func parseCHAP() throws {
        let titleSubframe = ID3TestHelper.buildTextFrame(
            id: "TIT2", text: "Chapter 1"
        )
        let frameData = ID3TestHelper.buildCHAPFrame(
            elementID: "chp1", startTime: 0,
            endTime: 60_000, subframes: [titleSubframe]
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)

        guard case .chapter(let elementID, let startTime, let endTime, let subframes) = frame else {
            Issue.record("Expected chapter frame")
            return
        }
        #expect(elementID == "chp1")
        #expect(startTime == 0)
        #expect(endTime == 60_000)
        #expect(subframes.count == 1)
        #expect(subframes.first == .text(id: "TIT2", text: "Chapter 1"))
    }

    // MARK: - Table of Contents (CTOC)

    @Test("Parses CTOC frame")
    func parseCTOC() throws {
        let frameData = ID3TestHelper.buildCTOCFrame(
            elementID: "toc1", isTopLevel: true,
            isOrdered: true, childElementIDs: ["chp1", "chp2"]
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)

        guard
            case .tableOfContents(
                let elementID, let isTopLevel,
                let isOrdered, let childElementIDs, _
            ) = frame
        else {
            Issue.record("Expected CTOC frame")
            return
        }
        #expect(elementID == "toc1")
        #expect(isTopLevel)
        #expect(isOrdered)
        #expect(childElementIDs == ["chp1", "chp2"])
    }

    // MARK: - USLT

    @Test("Parses USLT frame")
    func parseUSLT() throws {
        let frameData = ID3TestHelper.buildUSLTFrame(
            language: "eng", text: "These are the lyrics."
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(
            frame
                == .unsyncLyrics(
                    language: "eng", description: "", text: "These are the lyrics."
                ))
    }

    // MARK: - SYLT

    @Test("Parses SYLT frame")
    func parseSYLT() throws {
        let events: [(text: String, timestamp: UInt32)] = [
            (text: "Line one", timestamp: 0),
            (text: "Line two", timestamp: 5000)
        ]
        let frameData = ID3TestHelper.buildSYLTFrame(
            language: "eng", contentType: 1, events: events
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)

        guard case .syncLyrics(let lang, let ct, _, let parsedEvents) = frame else {
            Issue.record("Expected SYLT frame")
            return
        }
        #expect(lang == "eng")
        #expect(ct == 1)
        #expect(parsedEvents.count == 2)
        #expect(parsedEvents[0].text == "Line one")
        #expect(parsedEvents[0].timestamp == 0)
        #expect(parsedEvents[1].text == "Line two")
        #expect(parsedEvents[1].timestamp == 5000)
    }

    // MARK: - PRIV

    @Test("Parses PRIV frame")
    func parsePRIV() throws {
        let privateBytes = Data([0x01, 0x02, 0x03])
        let frameData = ID3TestHelper.buildPRIVFrame(
            owner: "com.example.test", data: privateBytes
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .privateData(owner: "com.example.test", data: privateBytes))
    }

    // MARK: - UFID

    @Test("Parses UFID frame")
    func parseUFID() throws {
        let identifier = Data([0xAA, 0xBB, 0xCC])
        let frameData = ID3TestHelper.buildUFIDFrame(
            owner: "http://www.id3.org/dummy", identifier: identifier
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(
            frame
                == .uniqueFileID(
                    owner: "http://www.id3.org/dummy", identifier: identifier
                ))
    }

    // MARK: - PCNT

    @Test("Parses PCNT frame")
    func parsePCNT() throws {
        let frameData = ID3TestHelper.buildPCNTFrame(count: 42)
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .playCounter(count: 42))
    }

    // MARK: - POPM

    @Test("Parses POPM frame")
    func parsePOPM() throws {
        let frameData = ID3TestHelper.buildPOPMFrame(
            email: "user@example.com", rating: 196, playCount: 100
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(
            frame
                == .popularimeter(
                    email: "user@example.com", rating: 196, playCount: 100
                ))
    }

    // MARK: - Unknown Frame

    @Test("Unknown frame ID returns .unknown")
    func unknownFrame() throws {
        let content = Data([0x01, 0x02, 0x03])
        let frameData = ID3TestHelper.buildRawFrame(
            id: "ZZZZ", content: content
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .unknown(id: "ZZZZ", data: content))
    }

    // MARK: - Frame Size Encoding

    @Test("Frame size v2.3 uses regular UInt32")
    func frameSizeV23() throws {
        let frameData = ID3TestHelper.buildTextFrame(
            id: "TIT2", text: "Test", version: .v2_3
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .text(id: "TIT2", text: "Test"))
    }

    @Test("Frame size v2.4 uses syncsafe UInt32")
    func frameSizeV24() throws {
        let frameData = ID3TestHelper.buildTextFrame(
            id: "TIT2", text: "Test", encoding: .utf8, version: .v2_4
        )
        var reader = BinaryReader(data: frameData)
        let parser = ID3FrameParser(version: .v2_4)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == .text(id: "TIT2", text: "Test"))
    }

    // MARK: - Padding Detection

    @Test("Padding bytes return nil")
    func paddingDetection() throws {
        let data = Data(repeating: 0x00, count: 20)
        var reader = BinaryReader(data: data)
        let parser = ID3FrameParser(version: .v2_3)
        let frame = try parser.parseFrame(&reader)
        #expect(frame == nil)
    }

    // MARK: - Truncated Frame

    @Test("Truncated frame data throws error")
    func truncatedFrame() {
        // Frame header says 1000 bytes but only 5 available
        var writer = BinaryWriter()
        writer.writeLatin1String("TIT2")
        writer.writeUInt32(1000)
        writer.writeUInt16(0)
        writer.writeData(Data([0x00, 0x01, 0x02, 0x03, 0x04]))

        var reader = BinaryReader(data: writer.data)
        let parser = ID3FrameParser(version: .v2_3)
        #expect(throws: ID3Error.self) {
            _ = try parser.parseFrame(&reader)
        }
    }
}
