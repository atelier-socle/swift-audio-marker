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
@testable import AudioMarkerCommands

@Suite("CLI Artwork Commands")
struct ArtworkCommandTests {

    // MARK: - Extract

    @Test("Extract artwork from MP3 with JPEG artwork")
    func extractJPEGFromMP3() throws {
        let url = try CLITestHelper.createMP3WithArtwork()
        defer { try? FileManager.default.removeItem(at: url) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let outputPath = outputDir.appendingPathComponent("extracted.jpg").path
        var cmd = try ArtworkGroup.Extract.parse([url.path, "--output", outputPath])
        try cmd.run()

        let outputURL = URL(fileURLWithPath: outputPath)
        let data = try Data(contentsOf: outputURL)
        #expect(data.count > 0)
        // Verify JPEG magic bytes.
        #expect(data[0] == 0xFF)
        #expect(data[1] == 0xD8)
    }

    @Test("Extract artwork from M4A with PNG artwork")
    func extractPNGFromM4A() throws {
        let url = try createM4AWithPNGArtwork()
        defer { try? FileManager.default.removeItem(at: url) }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDir) }

        let outputPath = outputDir.appendingPathComponent("extracted.png").path
        var cmd = try ArtworkGroup.Extract.parse([url.path, "--output", outputPath])
        try cmd.run()

        let outputURL = URL(fileURLWithPath: outputPath)
        let data = try Data(contentsOf: outputURL)
        #expect(data.count > 0)
        // Verify PNG magic bytes.
        #expect(data[0] == 0x89)
        #expect(data[1] == 0x50)
    }

    @Test("Extract artwork with default output path")
    func extractDefaultOutput() throws {
        let url = try CLITestHelper.createMP3WithArtwork()
        defer { try? FileManager.default.removeItem(at: url) }

        // Change to a temp directory so default output goes there.
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var cmd = try ArtworkGroup.Extract.parse([url.path])
        try cmd.run()

        let defaultOutput = tempDir.appendingPathComponent("cover.jpg")
        #expect(FileManager.default.fileExists(atPath: defaultOutput.path))
    }

    @Test("Extract artwork from file without artwork fails")
    func extractNoArtwork() throws {
        let url = try CLITestHelper.createMP3(title: "No Art")
        defer { try? FileManager.default.removeItem(at: url) }

        var cmd = try ArtworkGroup.Extract.parse([url.path, "--output", "/tmp/should-not-exist.jpg"])
        #expect(throws: (any Error).self) {
            try cmd.run()
        }
        #expect(!FileManager.default.fileExists(atPath: "/tmp/should-not-exist.jpg"))
    }

    // MARK: - Helpers

    private func createM4AWithPNGArtwork() throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)

        let mdatContent = Data(repeating: 0xFF, count: 128)
        let stco = MP4TestHelper.buildStcoAtom(offsets: [0])
        let stsz = MP4TestHelper.buildStszAtom(defaultSize: UInt32(mdatContent.count), sizes: [])
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 441_000)])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 44100)
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let audioTrak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])

        // PNG artwork (magic bytes + padding).
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let imageData = pngHeader + Data(repeating: 0x00, count: 64)
        let covrAtom = MP4TestHelper.buildILSTArtwork(typeIndicator: 14, imageData: imageData)

        let titleItem = MP4TestHelper.buildILSTTextItem(type: "\u{00A9}nam", text: "PNG Art Test")
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: [titleItem, covrAtom])
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])

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
