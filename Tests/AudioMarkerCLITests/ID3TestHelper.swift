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

@testable import AudioMarker

/// Helpers for building synthetic ID3v2 tags in tests.
enum ID3TestHelper {

    // MARK: - Tag Building

    /// Builds a complete ID3v2 tag with header and frames.
    /// - Parameters:
    ///   - version: The tag version (.v2_3 or .v2_4).
    ///   - frames: Pre-built frame data (header + content for each frame).
    /// - Returns: Raw tag data including the 10-byte header.
    static func buildTag(version: ID3Version, frames: [Data]) -> Data {
        var body = Data()
        for frame in frames {
            body.append(frame)
        }

        var writer = BinaryWriter()
        // "ID3" marker
        writer.writeData(Data([0x49, 0x44, 0x33]))
        // Version
        writer.writeUInt8(version.majorVersion)
        writer.writeUInt8(0x00)  // Revision
        // Flags
        writer.writeUInt8(0x00)
        // Tag size (syncsafe)
        writer.writeSyncsafeUInt32(UInt32(body.count))
        // Frame data
        writer.writeData(body)

        return writer.data
    }

    /// Builds a complete ID3v2 tag with header flags.
    static func buildTagWithFlags(
        version: ID3Version,
        flags: UInt8,
        frames: [Data],
        extendedHeader: Data? = nil
    ) -> Data {
        var body = Data()
        if let extHeader = extendedHeader {
            body.append(extHeader)
        }
        for frame in frames {
            body.append(frame)
        }

        var writer = BinaryWriter()
        writer.writeData(Data([0x49, 0x44, 0x33]))
        writer.writeUInt8(version.majorVersion)
        writer.writeUInt8(0x00)
        writer.writeUInt8(flags)
        writer.writeSyncsafeUInt32(UInt32(body.count))
        writer.writeData(body)

        return writer.data
    }

    // MARK: - Frame Building

    /// Builds a text frame (TIT2, TPE1, TALB, etc.).
    static func buildTextFrame(
        id: String,
        text: String,
        encoding: ID3TextEncoding = .latin1,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeData(encoding.encode(text))

        return buildRawFrame(id: id, content: content.data, version: version)
    }

    /// Builds a TXXX (user-defined text) frame.
    static func buildTXXXFrame(
        description: String,
        value: String,
        encoding: ID3TextEncoding = .latin1,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        content.writeData(encoding.encode(value))

        return buildRawFrame(id: "TXXX", content: content.data, version: version)
    }

    /// Builds a COMM (comment) frame.
    static func buildCOMMFrame(
        language: String = "eng",
        description: String = "",
        text: String,
        encoding: ID3TextEncoding = .latin1,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeLatin1String(language)
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        content.writeData(encoding.encode(text))

        return buildRawFrame(id: "COMM", content: content.data, version: version)
    }

    /// Builds a URL frame (WOAR, WOAS, etc.).
    static func buildURLFrame(
        id: String,
        url: String,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeLatin1String(url)

        return buildRawFrame(id: id, content: content.data, version: version)
    }

    /// Builds a WXXX (user-defined URL) frame.
    static func buildWXXXFrame(
        description: String,
        url: String,
        encoding: ID3TextEncoding = .latin1,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        content.writeLatin1String(url)

        return buildRawFrame(id: "WXXX", content: content.data, version: version)
    }

    /// Builds an APIC (attached picture) frame.
    static func buildAPICFrame(
        mimeType: String = "image/jpeg",
        pictureType: UInt8 = 3,
        description: String = "",
        imageData: Data,
        encoding: ID3TextEncoding = .latin1,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeNullTerminatedLatin1String(mimeType)
        content.writeUInt8(pictureType)
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        content.writeData(imageData)

        return buildRawFrame(id: "APIC", content: content.data, version: version)
    }

    /// Builds a CHAP (chapter) frame.
    static func buildCHAPFrame(
        elementID: String,
        startTime: UInt32,
        endTime: UInt32,
        subframes: [Data] = [],
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String(elementID)
        content.writeUInt32(startTime)
        content.writeUInt32(endTime)
        // Start/end byte offsets (0xFFFFFFFF = unused)
        content.writeUInt32(0xFFFF_FFFF)
        content.writeUInt32(0xFFFF_FFFF)
        for subframe in subframes {
            content.writeData(subframe)
        }

        return buildRawFrame(id: "CHAP", content: content.data, version: version)
    }

    /// Builds a CTOC (table of contents) frame.
    static func buildCTOCFrame(
        elementID: String = "toc1",
        isTopLevel: Bool = true,
        isOrdered: Bool = true,
        childElementIDs: [String],
        subframes: [Data] = [],
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String(elementID)

        var flags: UInt8 = 0
        if isTopLevel { flags |= 0x02 }
        if isOrdered { flags |= 0x01 }
        content.writeUInt8(flags)

        content.writeUInt8(UInt8(childElementIDs.count))
        for childID in childElementIDs {
            content.writeNullTerminatedLatin1String(childID)
        }
        for subframe in subframes {
            content.writeData(subframe)
        }

        return buildRawFrame(id: "CTOC", content: content.data, version: version)
    }

    /// Builds a USLT (unsynchronized lyrics) frame.
    static func buildUSLTFrame(
        language: String = "eng",
        description: String = "",
        text: String,
        encoding: ID3TextEncoding = .latin1,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeLatin1String(language)
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        content.writeData(encoding.encode(text))

        return buildRawFrame(id: "USLT", content: content.data, version: version)
    }

    /// Builds a SYLT (synchronized lyrics) frame.
    static func buildSYLTFrame(
        language: String = "eng",
        timestampFormat: UInt8 = 0x02,
        contentType: UInt8 = 1,
        description: String = "",
        events: [(text: String, timestamp: UInt32)],
        encoding: ID3TextEncoding = .latin1,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeLatin1String(language)
        content.writeUInt8(timestampFormat)
        content.writeUInt8(contentType)
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)

        for event in events {
            content.writeData(encoding.encode(event.text))
            content.writeData(encoding.nullTerminator)
            content.writeUInt32(event.timestamp)
        }

        return buildRawFrame(id: "SYLT", content: content.data, version: version)
    }

    /// Builds a PRIV (private data) frame.
    static func buildPRIVFrame(
        owner: String,
        data privateData: Data,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String(owner)
        content.writeData(privateData)

        return buildRawFrame(id: "PRIV", content: content.data, version: version)
    }

    /// Builds a UFID (unique file identifier) frame.
    static func buildUFIDFrame(
        owner: String,
        identifier: Data,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String(owner)
        content.writeData(identifier)

        return buildRawFrame(id: "UFID", content: content.data, version: version)
    }

    /// Builds a PCNT (play counter) frame.
    static func buildPCNTFrame(
        count: UInt32,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeUInt32(count)

        return buildRawFrame(id: "PCNT", content: content.data, version: version)
    }

    /// Builds a POPM (popularimeter) frame.
    static func buildPOPMFrame(
        email: String,
        rating: UInt8,
        playCount: UInt32 = 0,
        version: ID3Version = .v2_3
    ) -> Data {
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String(email)
        content.writeUInt8(rating)
        content.writeUInt32(playCount)

        return buildRawFrame(id: "POPM", content: content.data, version: version)
    }

    // MARK: - Raw Frame

    /// Builds a raw frame with header (ID + size + flags) and content.
    static func buildRawFrame(
        id: String,
        content: Data,
        version: ID3Version = .v2_3,
        flags: UInt16 = 0
    ) -> Data {
        var writer = BinaryWriter()
        writer.writeLatin1String(id)

        if version == .v2_4 {
            writer.writeSyncsafeUInt32(UInt32(content.count))
        } else {
            writer.writeUInt32(UInt32(content.count))
        }

        writer.writeUInt16(flags)
        writer.writeData(content)

        return writer.data
    }

    // MARK: - File Helpers

    /// Creates a temporary file with ID3 tag data followed by fake audio data.
    static func createTempFile(tagData: Data, audioBytes: Int = 128) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        var fileData = tagData
        fileData.append(Data(repeating: 0xFF, count: audioBytes))
        try fileData.write(to: url)
        return url
    }
}
