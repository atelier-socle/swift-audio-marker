import Foundation

/// Converts `ID3Frame` values to their raw binary representation.
///
/// Each frame is serialized as a 10-byte header (4-byte ID + 4-byte size + 2-byte flags)
/// followed by the frame content. Frame sizes use regular big-endian `UInt32` for v2.3
/// and syncsafe `UInt32` for v2.4.
public struct ID3FrameBuilder: Sendable {

    /// The tag version (affects frame size encoding and text encoding choices).
    public let version: ID3Version

    /// Creates a frame builder for the given ID3v2 version.
    /// - Parameter version: The tag version.
    public init(version: ID3Version) {
        self.version = version
    }

    // MARK: - Public API

    /// Builds the raw binary data for a single ID3v2 frame.
    /// - Parameter frame: The frame to serialize.
    /// - Returns: Complete frame data including header.
    public func buildFrame(_ frame: ID3Frame) -> Data {
        switch frame {
        case .text, .userDefinedText, .comment, .url, .userDefinedURL,
            .attachedPicture, .unsyncLyrics:
            return buildContentFrame(frame)
        default:
            return buildStructuredFrame(frame)
        }
    }
}

// MARK: - Frame Dispatch

extension ID3FrameBuilder {

    private func buildContentFrame(_ frame: ID3Frame) -> Data {
        switch frame {
        case .text(let id, let text):
            return buildTextFrame(id: id, text: text)
        case .userDefinedText(let description, let value):
            return buildUserDefinedTextFrame(description: description, value: value)
        case .comment(let language, let description, let text):
            return buildCommentFrame(language: language, description: description, text: text)
        case .url(let id, let url):
            return buildURLFrame(id: id, url: url)
        case .userDefinedURL(let description, let url):
            return buildUserDefinedURLFrame(description: description, url: url)
        case .attachedPicture(let pictureType, let mimeType, let description, let data):
            return buildAPICFrame(
                pictureType: pictureType, mimeType: mimeType,
                description: description, data: data)
        case .unsyncLyrics(let language, let description, let text):
            return buildUSLTFrame(language: language, description: description, text: text)
        default:
            return Data()
        }
    }

    private func buildStructuredFrame(_ frame: ID3Frame) -> Data {
        switch frame {
        case .chapter(let elementID, let startTime, let endTime, let subframes):
            return buildCHAPFrame(
                elementID: elementID, startTime: startTime,
                endTime: endTime, subframes: subframes)
        case .tableOfContents(let elementID, let isTopLevel, let isOrdered, let childIDs, let subframes):
            return buildCTOCFrame(
                elementID: elementID, isTopLevel: isTopLevel,
                isOrdered: isOrdered, childIDs: childIDs, subframes: subframes)
        case .syncLyrics(let language, let contentType, let description, let events):
            return buildSYLTFrame(
                language: language, contentType: contentType,
                description: description, events: events)
        case .privateData(let owner, let data):
            return buildPRIVFrame(owner: owner, data: data)
        case .uniqueFileID(let owner, let identifier):
            return buildUFIDFrame(owner: owner, identifier: identifier)
        case .playCounter(let count):
            return buildPCNTFrame(count: count)
        case .popularimeter(let email, let rating, let playCount):
            return buildPOPMFrame(email: email, rating: rating, playCount: playCount)
        case .unknown(let id, let data):
            return buildUnknownFrame(id: id, data: data)
        default:
            return Data()
        }
    }
}

// MARK: - Text & URL Frames

extension ID3FrameBuilder {

    private func buildTextFrame(id: String, text: String) -> Data {
        let encoding = chooseEncoding(for: text)
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeData(encoding.encode(text))
        return wrapFrame(id: id, content: content.data)
    }

    private func buildUserDefinedTextFrame(description: String, value: String) -> Data {
        let encoding = chooseEncoding(for: description + value)
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        content.writeData(encoding.encode(value))
        return wrapFrame(id: "TXXX", content: content.data)
    }

    private func buildURLFrame(id: String, url: String) -> Data {
        var content = BinaryWriter()
        content.writeLatin1String(url)
        return wrapFrame(id: id, content: content.data)
    }

    private func buildUserDefinedURLFrame(description: String, url: String) -> Data {
        let encoding = chooseEncoding(for: description)
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        content.writeLatin1String(url)
        return wrapFrame(id: "WXXX", content: content.data)
    }

    private func buildCommentFrame(language: String, description: String, text: String) -> Data {
        let encoding = chooseEncoding(for: description + text)
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeLatin1String(sanitizeLanguage(language))
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        content.writeData(encoding.encode(text))
        return wrapFrame(id: "COMM", content: content.data)
    }
}

// MARK: - Media Frames

extension ID3FrameBuilder {

    private func buildAPICFrame(
        pictureType: UInt8, mimeType: String, description: String, data: Data
    ) -> Data {
        let encoding = chooseEncoding(for: description)
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeNullTerminatedLatin1String(mimeType)
        content.writeUInt8(pictureType)
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        content.writeData(data)
        return wrapFrame(id: "APIC", content: content.data)
    }

    private func buildUSLTFrame(language: String, description: String, text: String) -> Data {
        let encoding = chooseEncoding(for: description + text)
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeLatin1String(sanitizeLanguage(language))
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        content.writeData(encoding.encode(text))
        return wrapFrame(id: "USLT", content: content.data)
    }

    private func buildSYLTFrame(
        language: String, contentType: UInt8, description: String, events: [SyncLyricEvent]
    ) -> Data {
        let encoding = chooseEncoding(for: description)
        var content = BinaryWriter()
        content.writeUInt8(encoding.rawValue)
        content.writeLatin1String(sanitizeLanguage(language))
        content.writeUInt8(0x02)  // Timestamp format: milliseconds
        content.writeUInt8(contentType)
        content.writeData(encoding.encode(description))
        content.writeData(encoding.nullTerminator)
        for event in events {
            content.writeData(encoding.encode(event.text))
            content.writeData(encoding.nullTerminator)
            content.writeUInt32(event.timestamp)
        }
        return wrapFrame(id: "SYLT", content: content.data)
    }
}

// MARK: - Chapter Frames

extension ID3FrameBuilder {

    private func buildCHAPFrame(
        elementID: String, startTime: UInt32, endTime: UInt32, subframes: [ID3Frame]
    ) -> Data {
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String(elementID)
        content.writeUInt32(startTime)
        content.writeUInt32(endTime)
        content.writeUInt32(0xFFFF_FFFF)  // Start byte offset (unused)
        content.writeUInt32(0xFFFF_FFFF)  // End byte offset (unused)
        for subframe in subframes {
            content.writeData(buildFrame(subframe))
        }
        return wrapFrame(id: "CHAP", content: content.data)
    }

    private func buildCTOCFrame(
        elementID: String, isTopLevel: Bool, isOrdered: Bool,
        childIDs: [String], subframes: [ID3Frame]
    ) -> Data {
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String(elementID)
        var flags: UInt8 = 0
        if isTopLevel { flags |= 0x02 }
        if isOrdered { flags |= 0x01 }
        content.writeUInt8(flags)
        content.writeUInt8(UInt8(min(childIDs.count, 255)))
        for childID in childIDs {
            content.writeNullTerminatedLatin1String(childID)
        }
        for subframe in subframes {
            content.writeData(buildFrame(subframe))
        }
        return wrapFrame(id: "CTOC", content: content.data)
    }
}

// MARK: - Data Frames

extension ID3FrameBuilder {

    private func buildPRIVFrame(owner: String, data: Data) -> Data {
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String(owner)
        content.writeData(data)
        return wrapFrame(id: "PRIV", content: content.data)
    }

    private func buildUFIDFrame(owner: String, identifier: Data) -> Data {
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String(owner)
        content.writeData(identifier)
        return wrapFrame(id: "UFID", content: content.data)
    }

    private func buildPCNTFrame(count: UInt64) -> Data {
        var content = BinaryWriter()
        content.writeUInt32(UInt32(min(count, UInt64(UInt32.max))))
        return wrapFrame(id: "PCNT", content: content.data)
    }

    private func buildPOPMFrame(email: String, rating: UInt8, playCount: UInt64) -> Data {
        var content = BinaryWriter()
        content.writeNullTerminatedLatin1String(email)
        content.writeUInt8(rating)
        content.writeUInt32(UInt32(min(playCount, UInt64(UInt32.max))))
        return wrapFrame(id: "POPM", content: content.data)
    }

    private func buildUnknownFrame(id: String, data: Data) -> Data {
        wrapFrame(id: id, content: data)
    }
}

// MARK: - Helpers

extension ID3FrameBuilder {

    private func wrapFrame(id: String, content: Data) -> Data {
        var writer = BinaryWriter()
        writer.writeLatin1String(id)
        if version == .v2_4 {
            writer.writeSyncsafeUInt32(UInt32(content.count))
        } else {
            writer.writeUInt32(UInt32(content.count))
        }
        writer.writeUInt16(0x0000)  // Frame flags
        writer.writeData(content)
        return writer.data
    }

    private func chooseEncoding(for text: String) -> ID3TextEncoding {
        if version == .v2_4 {
            return .utf8
        }
        if canEncodeLatin1(text) {
            return .latin1
        }
        return .utf16WithBOM
    }

    private func canEncodeLatin1(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { $0.value <= 0xFF }
    }

    private func sanitizeLanguage(_ language: String) -> String {
        let padded = language.padding(toLength: 3, withPad: " ", startingAt: 0)
        return String(padded.prefix(3))
    }
}
