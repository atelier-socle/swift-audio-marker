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

/// Parses individual ID3v2 frames from raw data.
public struct ID3FrameParser: Sendable {

    /// The tag version (affects frame size encoding and text encoding support).
    public let version: ID3Version

    /// Creates a frame parser for the given ID3v2 version.
    /// - Parameter version: The tag version.
    public init(version: ID3Version) {
        self.version = version
    }

    // MARK: - Public API

    /// Parses a single frame from the given binary reader.
    /// - Parameter reader: A `BinaryReader` positioned at the start of the frame.
    /// - Returns: The parsed frame, or `nil` if padding is reached.
    /// - Throws: ``ID3Error`` for malformed frames.
    public func parseFrame(_ reader: inout BinaryReader) throws -> ID3Frame? {
        guard reader.remainingCount >= 10 else { return nil }

        // Peek at first byte to detect padding
        let firstByte = reader.data[reader.data.startIndex + reader.offset]
        if firstByte == 0x00 { return nil }

        let frameID = try reader.readLatin1String(count: 4)

        guard isValidFrameID(frameID) else {
            return nil
        }

        let frameSize: UInt32
        if version == .v2_4 {
            frameSize = try reader.readSyncsafeUInt32()
        } else {
            frameSize = try reader.readUInt32()
        }

        let flags = try reader.readUInt16()

        guard reader.remainingCount >= Int(frameSize) else {
            throw ID3Error.truncatedData(
                expected: Int(frameSize), available: reader.remainingCount
            )
        }

        let frameData = try reader.readData(count: Int(frameSize))

        // Apply unsynchronization if v2.4 frame-level flag is set
        let processedData: Data
        if version == .v2_4, flags & 0x0002 != 0 {
            processedData = removeUnsynchronization(frameData)
        } else {
            processedData = frameData
        }

        return try parseFrameContent(id: frameID, data: processedData)
    }

    // MARK: - Frame Content Dispatch

    private func parseFrameContent(id: String, data: Data) throws -> ID3Frame {
        guard let knownID = ID3FrameID(rawValue: id) else {
            return .unknown(id: id, data: data)
        }

        if isTextFrameID(knownID) {
            return try parseTextFrame(id: id, data: data)
        }

        if isURLFrameID(knownID) {
            return try parseURLFrame(id: id, data: data)
        }

        return try parseSpecialFrame(knownID: knownID, data: data)
    }

    private func isTextFrameID(_ id: ID3FrameID) -> Bool {
        switch id {
        case .title, .artist, .album, .genre, .trackNumber, .yearV23,
            .recordingDate, .albumArtist, .composer, .publisher,
            .copyright, .encodedBy, .length, .bpm, .musicalKey,
            .language, .discNumber, .isrc:
            return true
        default:
            return false
        }
    }

    private func isURLFrameID(_ id: ID3FrameID) -> Bool {
        switch id {
        case .artistURL, .audioSourceURL, .audioFileURL, .publisherURL, .commercialURL:
            return true
        default:
            return false
        }
    }

    private func parseSpecialFrame(knownID: ID3FrameID, data: Data) throws -> ID3Frame {
        if let frame = try parseMediaFrame(knownID: knownID, data: data) {
            return frame
        }
        return try parseDataFrame(knownID: knownID, data: data)
    }

    private func parseMediaFrame(knownID: ID3FrameID, data: Data) throws -> ID3Frame? {
        switch knownID {
        case .userDefinedText: return try parseUserDefinedTextFrame(data: data)
        case .userDefinedURL: return try parseUserDefinedURLFrame(data: data)
        case .comment: return try parseCommentFrame(data: data)
        case .attachedPicture: return try parseAPICFrame(data: data)
        case .chapter: return try parseCHAPFrame(data: data)
        case .tableOfContents: return try parseCTOCFrame(data: data)
        default: return nil
        }
    }

    private func parseDataFrame(knownID: ID3FrameID, data: Data) throws -> ID3Frame {
        switch knownID {
        case .unsyncLyrics: return try parseUSLTFrame(data: data)
        case .syncLyrics: return try parseSYLTFrame(data: data)
        case .privateData: return try parsePRIVFrame(data: data)
        case .uniqueFileID: return try parseUFIDFrame(data: data)
        case .playCounter: return try parsePCNTFrame(data: data)
        case .popularimeter: return try parsePOPMFrame(data: data)
        default: return .unknown(id: knownID.rawValue, data: data)
        }
    }
}

// MARK: - Frame Parsers

extension ID3FrameParser {

    // MARK: - Text Frame (T***)

    private func parseTextFrame(id: String, data: Data) throws -> ID3Frame {
        guard !data.isEmpty else {
            return .text(id: id, text: "")
        }
        var reader = BinaryReader(data: data)
        let encoding = try readEncoding(&reader)
        let textData = try reader.readData(count: reader.remainingCount)
        let text = try encoding.decode(trimNullTerminator(textData, encoding: encoding))
        return .text(id: id, text: text)
    }

    // MARK: - User-Defined Text Frame (TXXX)

    private func parseUserDefinedTextFrame(data: Data) throws -> ID3Frame {
        guard !data.isEmpty else {
            throw ID3Error.invalidFrame(id: "TXXX", reason: "Empty frame data.")
        }
        var reader = BinaryReader(data: data)
        let encoding = try readEncoding(&reader)
        let description = try readNullTerminatedString(&reader, encoding: encoding)
        let valueData = try reader.readData(count: reader.remainingCount)
        let value = try encoding.decode(trimNullTerminator(valueData, encoding: encoding))
        return .userDefinedText(description: description, value: value)
    }

    // MARK: - URL Frame (W***)

    private func parseURLFrame(id: String, data: Data) throws -> ID3Frame {
        guard !data.isEmpty else {
            return .url(id: id, url: "")
        }
        let urlString = String(data: data, encoding: .isoLatin1) ?? ""
        return .url(id: id, url: trimTrailingNulls(urlString))
    }

    // MARK: - User-Defined URL Frame (WXXX)

    private func parseUserDefinedURLFrame(data: Data) throws -> ID3Frame {
        guard !data.isEmpty else {
            throw ID3Error.invalidFrame(id: "WXXX", reason: "Empty frame data.")
        }
        var reader = BinaryReader(data: data)
        let encoding = try readEncoding(&reader)
        let description = try readNullTerminatedString(&reader, encoding: encoding)
        let urlData = try reader.readData(count: reader.remainingCount)
        let urlString = String(data: urlData, encoding: .isoLatin1) ?? ""
        return .userDefinedURL(description: description, url: trimTrailingNulls(urlString))
    }

    // MARK: - Comment Frame (COMM)

    private func parseCommentFrame(data: Data) throws -> ID3Frame {
        guard data.count >= 4 else {
            throw ID3Error.invalidFrame(id: "COMM", reason: "Frame too short.")
        }
        var reader = BinaryReader(data: data)
        let encoding = try readEncoding(&reader)
        let language = try reader.readLatin1String(count: 3)
        let description = try readNullTerminatedString(&reader, encoding: encoding)
        let textData = try reader.readData(count: reader.remainingCount)
        let text = try encoding.decode(trimNullTerminator(textData, encoding: encoding))
        return .comment(language: language, description: description, text: text)
    }

    // MARK: - Attached Picture Frame (APIC)

    private func parseAPICFrame(data: Data) throws -> ID3Frame {
        guard data.count >= 4 else {
            throw ID3Error.invalidFrame(id: "APIC", reason: "Frame too short.")
        }
        var reader = BinaryReader(data: data)
        let encoding = try readEncoding(&reader)
        let mimeType = try reader.readNullTerminatedLatin1String()
        let pictureType = try reader.readUInt8()
        let description = try readNullTerminatedString(&reader, encoding: encoding)
        let imageData = try reader.readData(count: reader.remainingCount)
        return .attachedPicture(
            pictureType: pictureType, mimeType: mimeType,
            description: description, data: imageData
        )
    }

    // MARK: - Chapter Frame (CHAP)

    private func parseCHAPFrame(data: Data) throws -> ID3Frame {
        guard data.count >= 17 else {
            throw ID3Error.invalidFrame(id: "CHAP", reason: "Frame too short.")
        }
        var reader = BinaryReader(data: data)
        let elementID = try reader.readNullTerminatedLatin1String()
        let startTime = try reader.readUInt32()
        let endTime = try reader.readUInt32()
        try reader.skip(8)  // Start/end byte offsets (often 0xFFFFFFFF)

        let subframes = try parseSubframes(&reader)
        return .chapter(
            elementID: elementID, startTime: startTime,
            endTime: endTime, subframes: subframes
        )
    }

    // MARK: - Table of Contents Frame (CTOC)

    private func parseCTOCFrame(data: Data) throws -> ID3Frame {
        guard data.count >= 4 else {
            throw ID3Error.invalidFrame(id: "CTOC", reason: "Frame too short.")
        }
        var reader = BinaryReader(data: data)
        let elementID = try reader.readNullTerminatedLatin1String()

        let flagsByte = try reader.readUInt8()
        let isTopLevel = (flagsByte & 0x02) != 0
        let isOrdered = (flagsByte & 0x01) != 0

        let entryCount = try reader.readUInt8()
        var childElementIDs: [String] = []
        for _ in 0..<entryCount {
            let childID = try reader.readNullTerminatedLatin1String()
            childElementIDs.append(childID)
        }

        let subframes = try parseSubframes(&reader)
        return .tableOfContents(
            elementID: elementID, isTopLevel: isTopLevel,
            isOrdered: isOrdered, childElementIDs: childElementIDs,
            subframes: subframes
        )
    }

    // MARK: - Lyrics Frames

    private func parseUSLTFrame(data: Data) throws -> ID3Frame {
        guard data.count >= 4 else {
            throw ID3Error.invalidFrame(id: "USLT", reason: "Frame too short.")
        }
        var reader = BinaryReader(data: data)
        let encoding = try readEncoding(&reader)
        let language = try reader.readLatin1String(count: 3)
        let description = try readNullTerminatedString(&reader, encoding: encoding)
        let textData = try reader.readData(count: reader.remainingCount)
        let text = try encoding.decode(trimNullTerminator(textData, encoding: encoding))
        return .unsyncLyrics(language: language, description: description, text: text)
    }

    private func parseSYLTFrame(data: Data) throws -> ID3Frame {
        guard data.count >= 6 else {
            throw ID3Error.invalidFrame(id: "SYLT", reason: "Frame too short.")
        }
        var reader = BinaryReader(data: data)
        let encoding = try readEncoding(&reader)
        let language = try reader.readLatin1String(count: 3)
        _ = try reader.readUInt8()  // Timestamp format
        let contentType = try reader.readUInt8()
        let description = try readNullTerminatedString(&reader, encoding: encoding)

        var events: [SyncLyricEvent] = []
        while reader.hasRemaining {
            let text = try readNullTerminatedString(&reader, encoding: encoding)
            guard reader.remainingCount >= 4 else { break }
            let timestamp = try reader.readUInt32()
            events.append(SyncLyricEvent(text: text, timestamp: timestamp))
        }

        return .syncLyrics(
            language: language, contentType: contentType,
            description: description, events: events
        )
    }

    // MARK: - Simple Data Frames

    private func parsePRIVFrame(data: Data) throws -> ID3Frame {
        var reader = BinaryReader(data: data)
        let owner = try reader.readNullTerminatedLatin1String()
        let privateBytes = try reader.readData(count: reader.remainingCount)
        return .privateData(owner: owner, data: privateBytes)
    }

    private func parseUFIDFrame(data: Data) throws -> ID3Frame {
        var reader = BinaryReader(data: data)
        let owner = try reader.readNullTerminatedLatin1String()
        let identifier = try reader.readData(count: reader.remainingCount)
        return .uniqueFileID(owner: owner, identifier: identifier)
    }

    private func parsePCNTFrame(data: Data) throws -> ID3Frame {
        guard data.count >= 4 else {
            throw ID3Error.invalidFrame(id: "PCNT", reason: "Frame too short.")
        }
        var count: UInt64 = 0
        for byte in data {
            count = (count << 8) | UInt64(byte)
        }
        return .playCounter(count: count)
    }

    private func parsePOPMFrame(data: Data) throws -> ID3Frame {
        guard data.count >= 2 else {
            throw ID3Error.invalidFrame(id: "POPM", reason: "Frame too short.")
        }
        var reader = BinaryReader(data: data)
        let email = try reader.readNullTerminatedLatin1String()
        let rating = try reader.readUInt8()
        var playCount: UInt64 = 0
        if reader.hasRemaining {
            let counterData = try reader.readData(count: reader.remainingCount)
            for byte in counterData {
                playCount = (playCount << 8) | UInt64(byte)
            }
        }
        return .popularimeter(email: email, rating: rating, playCount: playCount)
    }
}

// MARK: - Helpers

extension ID3FrameParser {

    private func parseSubframes(_ reader: inout BinaryReader) throws -> [ID3Frame] {
        var subframes: [ID3Frame] = []
        while reader.hasRemaining {
            guard reader.remainingCount >= 10 else { break }
            let peek = reader.data[reader.data.startIndex + reader.offset]
            if peek == 0x00 { break }

            let subParser = ID3FrameParser(version: version)
            if let subframe = try subParser.parseFrame(&reader) {
                subframes.append(subframe)
            } else {
                break
            }
        }
        return subframes
    }

    private func readEncoding(_ reader: inout BinaryReader) throws -> ID3TextEncoding {
        let byte = try reader.readUInt8()
        guard let encoding = ID3TextEncoding(rawValue: byte) else {
            throw ID3Error.invalidEncoding(byte)
        }
        return encoding
    }

    private func readNullTerminatedString(
        _ reader: inout BinaryReader,
        encoding: ID3TextEncoding
    ) throws -> String {
        switch encoding {
        case .latin1, .utf8:
            let data = try reader.readNullTerminatedData()
            return try encoding.decode(data)

        case .utf16WithBOM, .utf16BigEndian:
            return try readUTF16NullTerminatedString(&reader, encoding: encoding)
        }
    }

    private func readUTF16NullTerminatedString(
        _ reader: inout BinaryReader,
        encoding: ID3TextEncoding
    ) throws -> String {
        let start = reader.offset
        let dataStart = reader.data.startIndex

        while reader.remainingCount >= 2 {
            let b0 = reader.data[dataStart + reader.offset]
            let b1 = reader.data[dataStart + reader.offset + 1]
            if b0 == 0x00, b1 == 0x00 {
                let stringData = Data(
                    reader.data[(dataStart + start)..<(dataStart + reader.offset)]
                )
                try reader.skip(2)
                return try encoding.decode(stringData)
            }
            try reader.skip(2)
        }

        let stringData = Data(reader.data[(dataStart + start)..<(dataStart + reader.offset)])
        return try encoding.decode(stringData)
    }

    private func trimNullTerminator(_ data: Data, encoding: ID3TextEncoding) -> Data {
        let termSize = encoding.nullTerminatorSize
        if termSize == 1, data.last == 0x00 {
            return data.dropLast()
        }
        if termSize == 2, data.count >= 2 {
            let s = data.startIndex
            if data[s + data.count - 2] == 0x00, data[s + data.count - 1] == 0x00 {
                return data.dropLast(2)
            }
        }
        return data
    }

    private func trimTrailingNulls(_ string: String) -> String {
        var result = string
        while result.hasSuffix("\0") {
            result = String(result.dropLast())
        }
        return result
    }

    private func isValidFrameID(_ id: String) -> Bool {
        guard id.count == 4 else { return false }
        return id.allSatisfy { char in
            (char >= "A" && char <= "Z") || (char >= "0" && char <= "9")
        }
    }

    private func removeUnsynchronization(_ data: Data) -> Data {
        var result = Data()
        result.reserveCapacity(data.count)
        var previous: UInt8?
        for byte in data {
            if previous == 0xFF, byte == 0x00 {
                previous = byte
                continue
            }
            result.append(byte)
            previous = byte
        }
        return result
    }
}
