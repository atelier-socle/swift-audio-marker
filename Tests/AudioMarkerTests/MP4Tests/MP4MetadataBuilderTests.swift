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

@Suite("MP4 Metadata Builder")
struct MP4MetadataBuilderTests {

    let metadataBuilder = MP4MetadataBuilder()
    let metadataParser = MP4MetadataParser()

    // MARK: - Text Metadata

    @Test("Builds ilst with title, artist, and album")
    func buildTextMetadata() throws {
        var metadata = AudioMetadata()
        metadata.title = "Test Song"
        metadata.artist = "Test Artist"
        metadata.album = "Test Album"

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        #expect(parsed.title == "Test Song")
        #expect(parsed.artist == "Test Artist")
        #expect(parsed.album == "Test Album")
    }

    @Test("Builds ilst with genre, year, and composer")
    func buildExtendedText() throws {
        var metadata = AudioMetadata()
        metadata.genre = "Rock"
        metadata.year = 2024
        metadata.composer = "John Doe"

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        #expect(parsed.genre == "Rock")
        #expect(parsed.year == 2024)
        #expect(parsed.composer == "John Doe")
    }

    @Test("Builds ilst with comment, encoder, and lyrics")
    func buildCommentAndLyrics() throws {
        var metadata = AudioMetadata()
        metadata.comment = "Great song"
        metadata.encoder = "AudioMarker"
        metadata.unsynchronizedLyrics = "La la la"

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        #expect(parsed.comment == "Great song")
        #expect(parsed.encoder == "AudioMarker")
        #expect(parsed.unsynchronizedLyrics == "La la la")
    }

    // MARK: - Structured Metadata

    @Test("Builds ilst with track number")
    func buildTrackNumber() throws {
        var metadata = AudioMetadata()
        metadata.trackNumber = 5

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        #expect(parsed.trackNumber == 5)
    }

    @Test("Builds ilst with disc number")
    func buildDiscNumber() throws {
        var metadata = AudioMetadata()
        metadata.discNumber = 2

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        #expect(parsed.discNumber == 2)
    }

    @Test("Builds ilst with BPM")
    func buildBPM() throws {
        var metadata = AudioMetadata()
        metadata.bpm = 120

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        #expect(parsed.bpm == 120)
    }

    @Test("Builds ilst with JPEG artwork")
    func buildJPEGArtwork() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0] + Array(repeating: UInt8(0x00), count: 100))
        var metadata = AudioMetadata()
        metadata.artwork = Artwork(data: imageData, format: .jpeg)

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        let artwork = try #require(parsed.artwork)
        #expect(artwork.format == .jpeg)
        #expect(artwork.data == imageData)
    }

    @Test("Builds ilst with PNG artwork")
    func buildPNGArtwork() throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47] + Array(repeating: UInt8(0x00), count: 100))
        var metadata = AudioMetadata()
        metadata.artwork = Artwork(data: imageData, format: .png)

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        let artwork = try #require(parsed.artwork)
        #expect(artwork.format == .png)
        #expect(artwork.data == imageData)
    }

    @Test("Builds ilst with album artist and copyright")
    func buildAlbumArtistAndCopyright() throws {
        var metadata = AudioMetadata()
        metadata.albumArtist = "Various Artists"
        metadata.copyright = "2024 Atelier Socle"

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        #expect(parsed.albumArtist == "Various Artists")
        #expect(parsed.copyright == "2024 Atelier Socle")
    }

    // MARK: - Custom Fields (Reverse DNS)

    @Test("Builds ilst with custom text fields")
    func buildCustomTextFields() throws {
        var metadata = AudioMetadata()
        metadata.customTextFields["com.apple.iTunes:ISRC"] = "US1234567890"

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        #expect(parsed.customTextFields["com.apple.iTunes:ISRC"] == "US1234567890")
    }

    // MARK: - Empty Metadata

    @Test("Empty metadata produces minimal ilst")
    func emptyMetadata() {
        let metadata = AudioMetadata()
        let ilstData = metadataBuilder.buildIlst(from: metadata)

        // Just the ilst container header (8 bytes), no items.
        #expect(ilstData.count == 8)
    }

    // MARK: - Udta Hierarchy

    @Test("Builds udta with meta and ilst inside")
    func buildUdta() throws {
        var metadata = AudioMetadata()
        metadata.title = "Podcast"

        let udtaData = metadataBuilder.buildUdta(from: metadata, chapters: nil)

        // Parse udta to verify structure.
        let url = try MP4TestHelper.createTempFile(data: udtaData)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)

        #expect(atoms.count == 1)
        #expect(atoms[0].type == "udta")
        let metaAtom = try #require(atoms[0].child(ofType: "meta"))
        let ilstAtom = try #require(metaAtom.child(ofType: "ilst"))
        #expect(!ilstAtom.children.isEmpty)
    }

    // MARK: - Round-Trip

    @Test("Round-trip: build then parse produces identical metadata")
    func roundTrip() throws {
        var metadata = AudioMetadata()
        metadata.title = "Round Trip Song"
        metadata.artist = "Test Artist"
        metadata.album = "Test Album"
        metadata.genre = "Electronic"
        metadata.year = 2025
        metadata.trackNumber = 3
        metadata.discNumber = 1
        metadata.comment = "Test comment"
        metadata.bpm = 128

        let ilstData = metadataBuilder.buildIlst(from: metadata)
        let parsed = try parseIlstMetadata(ilstData)

        #expect(parsed.title == metadata.title)
        #expect(parsed.artist == metadata.artist)
        #expect(parsed.album == metadata.album)
        #expect(parsed.genre == metadata.genre)
        #expect(parsed.year == metadata.year)
        #expect(parsed.trackNumber == metadata.trackNumber)
        #expect(parsed.discNumber == metadata.discNumber)
        #expect(parsed.comment == metadata.comment)
        #expect(parsed.bpm == metadata.bpm)
    }

    // MARK: - Test Helper

    /// Parses ilst data back into AudioMetadata via MP4MetadataParser.
    private func parseIlstMetadata(_ ilstData: Data) throws -> AudioMetadata {
        // Wrap ilst in moov -> udta -> meta -> ilst to create a parseable file.
        let atomBuilder = MP4AtomBuilder()
        let meta = atomBuilder.buildMetaAtom(children: [ilstData])
        let udta = atomBuilder.buildContainerAtom(type: "udta", children: [meta])
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let moov = atomBuilder.buildContainerAtom(type: "moov", children: [mvhd, udta])

        let ftyp = MP4TestHelper.buildFtyp()
        var file = Data()
        file.append(ftyp)
        file.append(moov)

        let url = try MP4TestHelper.createTempFile(data: file)
        defer { try? FileManager.default.removeItem(at: url) }

        let reader = try FileReader(url: url)
        defer { reader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: reader)
        return try metadataParser.parseMetadata(from: atoms, reader: reader)
    }
}

// MARK: - Synchronized Lyrics

extension MP4MetadataBuilderTests {

    @Test("Builds synchronized lyrics as LRC in ©lyr atom")
    func buildSynchronizedLyrics() throws {
        var metadata = AudioMetadata()
        let syncLyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .zero, text: "Hello"),
                LyricLine(time: .seconds(5), text: "World")
            ])
        metadata.synchronizedLyrics = [syncLyrics]

        let ilst = metadataBuilder.buildIlst(from: metadata)
        let roundTripped = try parseIlstMetadata(ilst)
        // Should be stored as unsynchronized lyrics (LRC text in ©lyr).
        #expect(roundTripped.unsynchronizedLyrics != nil)
        #expect(roundTripped.unsynchronizedLyrics?.contains("[00:00.00]") == true)
        // Should also be parsed back as synchronized lyrics.
        #expect(roundTripped.synchronizedLyrics.count == 1)
        #expect(roundTripped.synchronizedLyrics[0].lines.count == 2)
        #expect(roundTripped.synchronizedLyrics[0].lines[0].text == "Hello")
        #expect(roundTripped.synchronizedLyrics[0].lines[1].text == "World")
    }

    @Test("Stores karaoke lyrics as TTML in ©lyr atom")
    func buildKaraokeLyricsAsTTML() throws {
        var metadata = AudioMetadata()
        let segments = [
            LyricSegment(startTime: .zero, endTime: .seconds(2), text: "Hello"),
            LyricSegment(startTime: .seconds(2), endTime: .seconds(5), text: "world")
        ]
        let syncLyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(
                    time: .zero, text: "Hello world", segments: segments)
            ])
        metadata.synchronizedLyrics = [syncLyrics]

        let ilst = metadataBuilder.buildIlst(from: metadata)
        let roundTripped = try parseIlstMetadata(ilst)

        // Stored as TTML (not LRC) because of karaoke segments.
        #expect(roundTripped.unsynchronizedLyrics?.contains("<tt") == true)
        #expect(roundTripped.synchronizedLyrics.count == 1)
        #expect(roundTripped.synchronizedLyrics[0].lines.count == 1)
        #expect(roundTripped.synchronizedLyrics[0].lines[0].text == "Hello world")
        // Karaoke segments survive the round-trip.
        #expect(roundTripped.synchronizedLyrics[0].lines[0].segments.count == 2)
        #expect(roundTripped.synchronizedLyrics[0].lines[0].segments[0].text == "Hello")
        #expect(roundTripped.synchronizedLyrics[0].lines[0].segments[1].text == "world")
    }

    @Test("Stores simple mono-language lyrics as LRC in ©lyr atom")
    func buildSimpleLyricsAsLRC() throws {
        var metadata = AudioMetadata()
        let syncLyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .zero, text: "Simple line"),
                LyricLine(time: .seconds(5), text: "Another line")
            ])
        metadata.synchronizedLyrics = [syncLyrics]

        let ilst = metadataBuilder.buildIlst(from: metadata)
        let roundTripped = try parseIlstMetadata(ilst)

        // Simple content → LRC (no XML).
        #expect(roundTripped.unsynchronizedLyrics?.contains("[00:00.00]") == true)
        #expect(roundTripped.unsynchronizedLyrics?.contains("<tt") != true)
        #expect(roundTripped.synchronizedLyrics.count == 1)
        #expect(roundTripped.synchronizedLyrics[0].lines.count == 2)
    }

    @Test("Karaoke round-trip preserves segment timing")
    func karaokeRoundTripPreservesSegmentTiming() throws {
        var metadata = AudioMetadata()
        let segments = [
            LyricSegment(
                startTime: .seconds(1), endTime: .seconds(3), text: "Feel"),
            LyricSegment(
                startTime: .seconds(3), endTime: .seconds(5), text: "the"),
            LyricSegment(
                startTime: .seconds(5), endTime: .seconds(8), text: "music")
        ]
        let syncLyrics = SynchronizedLyrics(
            language: "fra",
            lines: [
                LyricLine(
                    time: .seconds(1), text: "Feel the music",
                    segments: segments)
            ])
        metadata.synchronizedLyrics = [syncLyrics]

        let ilst = metadataBuilder.buildIlst(from: metadata)
        let roundTripped = try parseIlstMetadata(ilst)

        let line = try #require(roundTripped.synchronizedLyrics.first?.lines.first)
        #expect(line.segments.count == 3)
        #expect(line.segments[0].startTime == .seconds(1))
        #expect(line.segments[0].endTime == .seconds(3))
        #expect(line.segments[1].text == "the")
        #expect(line.segments[2].endTime == .seconds(8))
        // Language preserved.
        #expect(roundTripped.synchronizedLyrics[0].language == "fra")
    }

    @Test("Stores mono-language lyrics with speakers as TTML")
    func buildSpeakerLyricsAsTTML() throws {
        var metadata = AudioMetadata()
        let syncLyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .zero, text: "Hello", speaker: "Alice"),
                LyricLine(time: .seconds(5), text: "World", speaker: "Bob")
            ])
        metadata.synchronizedLyrics = [syncLyrics]

        let ilst = metadataBuilder.buildIlst(from: metadata)
        let roundTripped = try parseIlstMetadata(ilst)

        // Should be stored as TTML (not LRC) because of speakers.
        #expect(roundTripped.unsynchronizedLyrics?.contains("<tt") == true)
        #expect(roundTripped.synchronizedLyrics.count == 1)
        #expect(roundTripped.synchronizedLyrics[0].lines.count == 2)
        // Speakers survive the round-trip.
        #expect(roundTripped.synchronizedLyrics[0].lines[0].speaker == "Alice")
        #expect(roundTripped.synchronizedLyrics[0].lines[1].speaker == "Bob")
    }

    @Test("Prefers synchronized lyrics over unsynchronized in ©lyr")
    func prefersSynchronizedOverUnsynchronized() throws {
        var metadata = AudioMetadata()
        let syncLyrics = SynchronizedLyrics(
            language: "eng",
            lines: [
                LyricLine(time: .zero, text: "Sync line")
            ])
        metadata.synchronizedLyrics = [syncLyrics]
        metadata.unsynchronizedLyrics = "Plain text lyrics"

        let ilst = metadataBuilder.buildIlst(from: metadata)
        let roundTripped = try parseIlstMetadata(ilst)
        // Synchronized should win (written as LRC).
        #expect(roundTripped.unsynchronizedLyrics?.contains("[00:00.00]") == true)
        #expect(roundTripped.synchronizedLyrics.count == 1)
    }
}
