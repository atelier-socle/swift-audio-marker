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

@Suite("ID3 Reader Coverage")
struct ID3ReaderCoverageTests {

    // MARK: - Helpers

    private func createTempFile(tagData: Data) throws -> URL {
        try ID3TestHelper.createTempFile(tagData: tagData)
    }

    // MARK: - Professional Text Fields

    @Test("Reads professional text fields")
    func readProfessionalFields() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildTextFrame(id: "TPE2", text: "Album Artist"),
                ID3TestHelper.buildTextFrame(id: "TCOM", text: "Composer"),
                ID3TestHelper.buildTextFrame(id: "TPUB", text: "Publisher"),
                ID3TestHelper.buildTextFrame(id: "TCOP", text: "2024 Copyright"),
                ID3TestHelper.buildTextFrame(id: "TENC", text: "Encoder"),
                ID3TestHelper.buildTextFrame(id: "TBPM", text: "120"),
                ID3TestHelper.buildTextFrame(id: "TKEY", text: "Cmaj"),
                ID3TestHelper.buildTextFrame(id: "TLAN", text: "eng"),
                ID3TestHelper.buildTextFrame(id: "TSRC", text: "US1234567890")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.albumArtist == "Album Artist")
        #expect(info.metadata.composer == "Composer")
        #expect(info.metadata.publisher == "Publisher")
        #expect(info.metadata.copyright == "2024 Copyright")
        #expect(info.metadata.encoder == "Encoder")
        #expect(info.metadata.bpm == 120)
        #expect(info.metadata.key == "Cmaj")
        #expect(info.metadata.language == "eng")
        #expect(info.metadata.isrc == "US1234567890")
    }

    // MARK: - URL Frames

    @Test("Reads URL frames")
    func readURLFrames() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildURLFrame(
                    id: "WOAR", url: "https://artist.example.com"),
                ID3TestHelper.buildURLFrame(
                    id: "WOAS", url: "https://source.example.com"),
                ID3TestHelper.buildURLFrame(
                    id: "WOAF", url: "https://file.example.com"),
                ID3TestHelper.buildURLFrame(
                    id: "WPUB", url: "https://publisher.example.com"),
                ID3TestHelper.buildURLFrame(
                    id: "WCOM", url: "https://commercial.example.com")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.artistURL?.absoluteString == "https://artist.example.com")
        #expect(info.metadata.audioSourceURL?.absoluteString == "https://source.example.com")
        #expect(info.metadata.audioFileURL?.absoluteString == "https://file.example.com")
        #expect(info.metadata.publisherURL?.absoluteString == "https://publisher.example.com")
        #expect(info.metadata.commercialURL?.absoluteString == "https://commercial.example.com")
    }

    // MARK: - WXXX Custom URL

    @Test("Reads WXXX custom URL")
    func readWXXX() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildWXXXFrame(
                    description: "PODCAST_URL", url: "https://podcast.example.com")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(
            info.metadata.customURLs["PODCAST_URL"]?.absoluteString
                == "https://podcast.example.com")
    }

    // MARK: - Comment Frame

    @Test("Reads comment frame")
    func readComment() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildCOMMFrame(text: "A great track")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.comment == "A great track")
    }

    // MARK: - USLT Frame

    @Test("Reads unsynchronized lyrics")
    func readUSLT() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildUSLTFrame(text: "These are the lyrics.")
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.unsynchronizedLyrics == "These are the lyrics.")
    }

    // MARK: - PCNT and POPM Through Reader

    @Test("Reads play counter through reader")
    func readPCNT() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildPCNTFrame(count: 42)
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.playCount == 42)
    }

    @Test("Reads popularimeter through reader")
    func readPOPM() throws {
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildPOPMFrame(
                    email: "user@test.com", rating: 196, playCount: 100)
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.rating == 196)
    }

    // MARK: - Chapter with URL and Artwork Subframes

    @Test("Reads chapter with URL subframe")
    func readChapterWithURL() throws {
        let titleSub = ID3TestHelper.buildTextFrame(id: "TIT2", text: "Chapter One")
        let urlSub = ID3TestHelper.buildURLFrame(
            id: "WOAR", url: "https://chapter.example.com")

        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildCHAPFrame(
                    elementID: "chp1", startTime: 0,
                    endTime: 30_000, subframes: [titleSub, urlSub])
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.chapters.count == 1)
        #expect(info.chapters[0].title == "Chapter One")
        #expect(info.chapters[0].url?.absoluteString == "https://chapter.example.com")
    }

    @Test("Reads chapter with artwork subframe")
    func readChapterWithArtwork() throws {
        let titleSub = ID3TestHelper.buildTextFrame(id: "TIT2", text: "Visual Chapter")
        let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x00, count: 50)
        let artSub = ID3TestHelper.buildAPICFrame(imageData: jpegData)

        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildCHAPFrame(
                    elementID: "chp1", startTime: 0,
                    endTime: 60_000, subframes: [titleSub, artSub])
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.chapters.count == 1)
        #expect(info.chapters[0].artwork != nil)
        #expect(info.chapters[0].artwork?.format == .jpeg)
    }

    // MARK: - Error Paths

    @Test("File too small throws invalidHeader")
    func fileTooSmall() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        try Data([0x01, 0x02]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        #expect(throws: ID3Error.self) {
            _ = try reader.read(from: url)
        }
    }

    @Test("Truncated tag data throws truncatedData")
    func truncatedTagData() throws {
        // Build a header claiming 1000 bytes, but file only has 20
        var writer = BinaryWriter()
        writer.writeData(Data([0x49, 0x44, 0x33]))  // "ID3"
        writer.writeUInt8(3)  // v2.3
        writer.writeUInt8(0)  // revision
        writer.writeUInt8(0)  // flags
        writer.writeSyncsafeUInt32(1000)  // tag size = 1000

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp3")
        var fileData = writer.data
        fileData.append(Data(repeating: 0x00, count: 10))
        try fileData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        #expect(throws: ID3Error.self) {
            _ = try reader.read(from: url)
        }
    }

    // MARK: - Non-front-cover Artwork Fallback

    @Test("Non-front-cover artwork used when no front cover exists")
    func nonFrontCoverArtwork() throws {
        let pngData = Data([0x89, 0x50, 0x4E, 0x47]) + Data(repeating: 0x00, count: 50)
        let tag = ID3TestHelper.buildTag(
            version: .v2_3,
            frames: [
                ID3TestHelper.buildAPICFrame(
                    mimeType: "image/png", pictureType: 0,
                    description: "", imageData: pngData)
            ])
        let url = try createTempFile(tagData: tag)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = ID3Reader()
        let info = try reader.read(from: url)
        #expect(info.metadata.artwork != nil)
        #expect(info.metadata.artwork?.format == .png)
    }
}
