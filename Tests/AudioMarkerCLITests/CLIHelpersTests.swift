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

@testable import AudioMarkerCommands

@Suite("CLI Helpers")
struct CLIHelpersTests {

    // MARK: - resolveURL

    @Test("Resolves absolute path to URL")
    func resolveAbsolutePath() {
        let url = CLIHelpers.resolveURL("/tmp/test.mp3")
        #expect(url.path == "/tmp/test.mp3")
    }

    @Test("Resolves relative path from current directory")
    func resolveRelativePath() {
        let url = CLIHelpers.resolveURL("song.mp3")
        let cwd = FileManager.default.currentDirectoryPath
        #expect(url.path == "\(cwd)/song.mp3")
    }

    @Test("Resolves tilde-prefixed path")
    func resolveTildePath() {
        let url = CLIHelpers.resolveURL("~/Music/test.mp3")
        let home = NSHomeDirectory()
        #expect(url.path == "\(home)/Music/test.mp3")
    }

    // MARK: - parseExportFormat

    @Test("Parses podlove-json format")
    func parsePodloveJSON() throws {
        let format = try CLIHelpers.parseExportFormat("podlove-json")
        #expect(format == .podloveJSON)
    }

    @Test("Parses podlove-xml format")
    func parsePodloveXML() throws {
        let format = try CLIHelpers.parseExportFormat("podlove-xml")
        #expect(format == .podloveXML)
    }

    @Test("Parses mp4chaps format")
    func parseMP4Chaps() throws {
        let format = try CLIHelpers.parseExportFormat("mp4chaps")
        #expect(format == .mp4chaps)
    }

    @Test("Parses ffmetadata format")
    func parseFFMetadata() throws {
        let format = try CLIHelpers.parseExportFormat("ffmetadata")
        #expect(format == .ffmetadata)
    }

    @Test("Parses markdown format")
    func parseMarkdown() throws {
        let format = try CLIHelpers.parseExportFormat("markdown")
        #expect(format == .markdown)
    }

    @Test("Parses lrc format")
    func parseLRC() throws {
        let format = try CLIHelpers.parseExportFormat("lrc")
        #expect(format == .lrc)
    }

    @Test("Parses ttml format")
    func parseTTML() throws {
        let format = try CLIHelpers.parseExportFormat("ttml")
        #expect(format == .ttml)
    }

    @Test("Parses podcast-ns format")
    func parsePodcastNS() throws {
        let format = try CLIHelpers.parseExportFormat("podcast-ns")
        #expect(format == .podcastNamespace)
    }

    @Test("Parses podcast-namespace format")
    func parsePodcastNamespace() throws {
        let format = try CLIHelpers.parseExportFormat("podcast-namespace")
        #expect(format == .podcastNamespace)
    }

    @Test("Invalid format throws error")
    func parseInvalidFormat() {
        #expect(throws: Error.self) {
            try CLIHelpers.parseExportFormat("invalid")
        }
    }

    // MARK: - findAudioFiles

    @Test("Finds audio files in directory")
    func findAudioFilesInDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let mp3 = dir.appendingPathComponent("song.mp3")
        let m4a = dir.appendingPathComponent("track.m4a")
        let txt = dir.appendingPathComponent("notes.txt")
        try Data().write(to: mp3)
        try Data().write(to: m4a)
        try Data().write(to: txt)

        let files = try CLIHelpers.findAudioFiles(in: dir.path, recursive: false)
        #expect(files.count == 2)

        let names = files.map(\.lastPathComponent)
        #expect(names.contains("song.mp3"))
        #expect(names.contains("track.m4a"))
    }

    @Test("Empty directory returns empty list")
    func findAudioFilesEmptyDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let files = try CLIHelpers.findAudioFiles(in: dir.path, recursive: false)
        #expect(files.isEmpty)
    }

    @Test("Recursive finds files in subdirectories")
    func findAudioFilesRecursive() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let subdir = dir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let rootFile = dir.appendingPathComponent("root.mp3")
        let subFile = subdir.appendingPathComponent("nested.m4a")
        try Data().write(to: rootFile)
        try Data().write(to: subFile)

        let files = try CLIHelpers.findAudioFiles(in: dir.path, recursive: true)
        #expect(files.count == 2)
    }

    @Test("Non-existent directory throws error")
    func findAudioFilesNonExistent() {
        #expect(throws: Error.self) {
            try CLIHelpers.findAudioFiles(in: "/nonexistent/path", recursive: false)
        }
    }

    // MARK: - formatFileSize

    @Test("Formats bytes")
    func formatBytes() {
        #expect(CLIHelpers.formatFileSize(500) == "500 bytes")
    }

    @Test("Formats kilobytes")
    func formatKB() {
        #expect(CLIHelpers.formatFileSize(1500) == "1.5 KB")
    }

    @Test("Formats megabytes")
    func formatMB() {
        #expect(CLIHelpers.formatFileSize(5_200_000) == "5.2 MB")
    }

    @Test("Formats gigabytes")
    func formatGB() {
        #expect(CLIHelpers.formatFileSize(2_500_000_000) == "2.5 GB")
    }

    @Test("Zero bytes")
    func formatZero() {
        #expect(CLIHelpers.formatFileSize(0) == "0 bytes")
    }
}
