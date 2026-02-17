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

/// Demonstrates M4A synchronized lyrics write/read, smart storage routing, and TTML agent round-trip.
@Suite("Showcase: Lyrics I/O (M4A)")
struct ShowcaseLyricsIOTests {

    let engine = AudioMarkerEngine()

    // MARK: - Synchronized Lyrics Write/Read

    @Test("Write and read synchronized lyrics in M4A — LRC storage")
    func syncLyricsRoundTrip() throws {
        let url = try buildM4A()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.synchronizedLyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "Hello world"),
                    LyricLine(time: .seconds(5), text: "Second line"),
                    LyricLine(time: .seconds(10), text: "Final line")
                ])
        ]
        try engine.write(info, to: url)

        let readBack = try engine.read(from: url)
        #expect(readBack.metadata.synchronizedLyrics.count == 1)
        #expect(readBack.metadata.synchronizedLyrics[0].lines.count == 3)
        #expect(readBack.metadata.synchronizedLyrics[0].lines[0].text == "Hello world")
        #expect(readBack.metadata.synchronizedLyrics[0].lines[2].text == "Final line")
    }

    // MARK: - Smart Storage: Mono → LRC

    @Test("Smart storage — mono-language simple lyrics stored as LRC")
    func smartStorageLRC() throws {
        let url = try buildM4A()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.synchronizedLyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "Simple line"),
                    LyricLine(time: .seconds(5), text: "Another line")
                ])
        ]
        try engine.write(info, to: url)

        // The raw ©lyr text should be LRC (starts with "[")
        let readBack = try engine.read(from: url)
        let rawText = readBack.metadata.unsynchronizedLyrics ?? ""
        #expect(rawText.hasPrefix("["))
        #expect(!rawText.contains("<?xml"))
    }

    // MARK: - Smart Storage: Multi-Language → TTML

    @Test("Smart storage — multi-language lyrics stored as TTML")
    func smartStorageTTMLMultiLang() throws {
        let url = try buildM4A()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.synchronizedLyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [LyricLine(time: .zero, text: "Hello")]),
            SynchronizedLyrics(
                language: "fra",
                lines: [LyricLine(time: .zero, text: "Bonjour")])
        ]
        try engine.write(info, to: url)

        // Raw text should be TTML (multi-language)
        let readBack = try engine.read(from: url)
        let rawText = readBack.metadata.unsynchronizedLyrics ?? ""
        #expect(rawText.contains("<?xml") || rawText.contains("<tt"))

        // Both languages round-trip
        #expect(readBack.metadata.synchronizedLyrics.count == 2)
    }

    // MARK: - Smart Storage: Karaoke → TTML

    @Test("Smart storage — karaoke lyrics stored as TTML")
    func smartStorageTTMLKaraoke() throws {
        let url = try buildM4A()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.synchronizedLyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(
                        time: .zero,
                        text: "Never gonna give",
                        segments: [
                            LyricSegment(
                                startTime: .zero, endTime: .milliseconds(1500),
                                text: "Never"),
                            LyricSegment(
                                startTime: .milliseconds(1500),
                                endTime: .milliseconds(3000), text: "gonna"),
                            LyricSegment(
                                startTime: .milliseconds(3000),
                                endTime: .milliseconds(5000), text: "give")
                        ])
                ])
        ]
        try engine.write(info, to: url)

        // Raw text should be TTML (karaoke)
        let readBack = try engine.read(from: url)
        let rawText = readBack.metadata.unsynchronizedLyrics ?? ""
        #expect(rawText.contains("<?xml") || rawText.contains("<tt"))

        // Karaoke segments round-trip
        let line = readBack.metadata.synchronizedLyrics[0].lines[0]
        #expect(line.isKaraoke)
        #expect(line.segments.count == 3)
        #expect(line.segments[0].text == "Never")
    }

    // MARK: - Smart Storage: Speakers → TTML

    @Test("Smart storage — lyrics with speakers stored as TTML")
    func smartStorageTTMLSpeakers() throws {
        let url = try buildM4A()
        defer { try? FileManager.default.removeItem(at: url) }

        var info = AudioFileInfo()
        info.metadata.synchronizedLyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "Hello!", speaker: "Alice"),
                    LyricLine(time: .seconds(3), text: "Hi there!", speaker: "Bob")
                ])
        ]
        try engine.write(info, to: url)

        // Raw text should be TTML (speakers trigger it)
        let readBack = try engine.read(from: url)
        let rawText = readBack.metadata.unsynchronizedLyrics ?? ""
        #expect(rawText.contains("<?xml") || rawText.contains("<tt"))

        // Speakers round-trip through M4A
        let lines = readBack.metadata.synchronizedLyrics[0].lines
        #expect(lines.count == 2)
        #expect(lines[0].speaker == "Alice")
        #expect(lines[1].speaker == "Bob")
    }

    // MARK: - TTML Agents Full Round-Trip

    @Test("TTML agents round-trip through M4A file — speakers preserved")
    func ttmlAgentsRoundTrip() throws {
        let url = try buildM4A()
        defer { try? FileManager.default.removeItem(at: url) }

        // Write lyrics with multiple speakers
        var info = AudioFileInfo()
        info.metadata.synchronizedLyrics = [
            SynchronizedLyrics(
                language: "eng",
                lines: [
                    LyricLine(time: .zero, text: "Welcome!", speaker: "Host"),
                    LyricLine(
                        time: .seconds(3), text: "Thanks for having me.",
                        speaker: "Guest"),
                    LyricLine(
                        time: .seconds(6), text: "Let's begin.", speaker: "Host")
                ])
        ]
        try engine.write(info, to: url)

        // Read back and verify full agent preservation
        let readBack = try engine.read(from: url)
        let lyrics = readBack.metadata.synchronizedLyrics
        #expect(lyrics.count == 1)

        let lines = lyrics[0].lines
        #expect(lines.count == 3)
        #expect(lines[0].text == "Welcome!")
        #expect(lines[0].speaker == "Host")
        #expect(lines[1].text == "Thanks for having me.")
        #expect(lines[1].speaker == "Guest")
        #expect(lines[2].text == "Let's begin.")
        #expect(lines[2].speaker == "Host")
    }

    // MARK: - Helpers

    /// Builds a minimal M4A file with audio track and mdat (required for write).
    private func buildM4A() throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: [])
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])

        let mdatContent = Data(repeating: 0xFF, count: 128)
        let stco = MP4TestHelper.buildStcoAtom(offsets: [0])
        let stsz = MP4TestHelper.buildStszAtom(
            defaultSize: UInt32(mdatContent.count), sizes: [])
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 441_000)])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 44100)
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [mdhd, hdlr, minf])
        let audioTrak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])

        let moov = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, audioTrak, udta])
        let mdat = MP4TestHelper.buildAtom(type: "mdat", data: mdatContent)

        var file = Data()
        file.append(ftyp)
        file.append(moov)
        file.append(mdat)

        return try MP4TestHelper.createTempFile(data: file)
    }
}
