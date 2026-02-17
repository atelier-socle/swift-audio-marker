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

/// The main entry point for AudioMarker operations.
///
/// `AudioMarkerEngine` provides a unified API for reading, writing,
/// and manipulating audio file metadata and chapters across all
/// supported formats (MP3, M4A, M4B).
///
/// ```swift
/// let engine = AudioMarkerEngine()
///
/// // Read
/// let info = try engine.read(from: fileURL)
/// print(info.metadata.title ?? "Untitled")
///
/// // Modify and write
/// var modified = info
/// modified.metadata.title = "New Title"
/// try engine.write(modified, to: fileURL)
/// ```
public struct AudioMarkerEngine: Sendable {

    /// Configuration for the engine.
    public let configuration: Configuration

    /// Creates an engine with the given configuration.
    /// - Parameter configuration: Engine configuration. Defaults to `.default`.
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Reading

    /// Reads metadata, chapters, and duration from an audio file.
    ///
    /// Auto-detects the file format from magic bytes and extension.
    /// - Parameter url: File URL to read.
    /// - Returns: Parsed audio file info.
    /// - Throws: ``AudioMarkerError``
    public func read(from url: URL) throws -> AudioFileInfo {
        let format = try detectFormat(of: url)
        return try readWithFormat(format, from: url)
    }

    /// Detects the format of an audio file.
    /// - Parameter url: File URL to inspect.
    /// - Returns: The detected format.
    /// - Throws: ``AudioMarkerError/unknownFormat(_:)`` if detection fails.
    public func detectFormat(of url: URL) throws -> AudioFormat {
        do {
            guard let format = try AudioFormat.detect(from: url) else {
                throw AudioMarkerError.unknownFormat(url.lastPathComponent)
            }
            return format
        } catch let error as AudioMarkerError {
            throw error
        } catch {
            throw AudioMarkerError.readFailed(
                "\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    // MARK: - Writing

    /// Writes metadata and chapters to an audio file.
    ///
    /// Auto-detects the file format and uses the appropriate writer.
    /// - Parameters:
    ///   - info: The audio file info to write.
    ///   - url: Target file URL.
    /// - Throws: ``AudioMarkerError``
    public func write(_ info: AudioFileInfo, to url: URL) throws {
        if configuration.validateBeforeWriting {
            try validateOrThrow(info)
        }
        let format = try detectFormat(of: url)
        try performWrite(info, format: format, to: url)
    }

    /// Modifies an existing audio file's metadata and chapters.
    ///
    /// For MP3, preserves unknown frames when `preserveUnknownData` is enabled.
    /// - Parameters:
    ///   - info: The modified audio file info.
    ///   - url: File URL to modify.
    /// - Throws: ``AudioMarkerError``
    public func modify(_ info: AudioFileInfo, in url: URL) throws {
        if configuration.validateBeforeWriting {
            try validateOrThrow(info)
        }
        let format = try detectFormat(of: url)
        try performModify(info, format: format, in: url)
    }

    /// Strips all metadata and chapters from an audio file.
    /// - Parameter url: File URL to strip.
    /// - Throws: ``AudioMarkerError``
    public func strip(from url: URL) throws {
        let format = try detectFormat(of: url)
        try performStrip(format: format, from: url)
    }
}

// MARK: - Chapters

extension AudioMarkerEngine {

    /// Reads only the chapters from an audio file.
    /// - Parameter url: File URL to read.
    /// - Returns: The chapter list.
    /// - Throws: ``AudioMarkerError``
    public func readChapters(from url: URL) throws -> ChapterList {
        try read(from: url).chapters
    }

    /// Writes chapters to an audio file, preserving existing metadata.
    /// - Parameters:
    ///   - chapters: The chapter list to write.
    ///   - url: Target file URL.
    /// - Throws: ``AudioMarkerError``
    public func writeChapters(_ chapters: ChapterList, to url: URL) throws {
        var info: AudioFileInfo
        do {
            info = try read(from: url)
        } catch {
            info = AudioFileInfo()
        }
        info.chapters = chapters
        try modify(info, in: url)
    }

    /// Imports chapters from a text format and writes them to an audio file.
    /// - Parameters:
    ///   - string: Chapter data in the specified format.
    ///   - format: The import format.
    ///   - url: Target audio file URL.
    /// - Throws: ``AudioMarkerError``, ``ExportError``
    public func importChapters(
        from string: String,
        format: ExportFormat,
        to url: URL
    ) throws {
        let chapters = try ChapterExporter().importChapters(from: string, format: format)
        try writeChapters(chapters, to: url)
    }

    /// Exports chapters from an audio file to a text format.
    /// - Parameters:
    ///   - url: Source audio file URL.
    ///   - format: The export format.
    /// - Returns: Formatted chapter string.
    /// - Throws: ``AudioMarkerError``, ``ExportError``
    public func exportChapters(
        from url: URL,
        format: ExportFormat
    ) throws -> String {
        let info = try read(from: url)
        return try ChapterExporter().export(info.chapters, format: format)
    }
}

// MARK: - Validation

extension AudioMarkerEngine {

    /// Validates an audio file's metadata and chapters.
    /// - Parameter info: The audio file info to validate.
    /// - Returns: Validation result with any issues found.
    public func validate(_ info: AudioFileInfo) -> ValidationResult {
        AudioValidator().validate(info)
    }

    /// Validates an audio file's metadata and chapters, throwing on errors.
    /// - Parameter info: The audio file info to validate.
    /// - Throws: ``AudioMarkerError/validationFailed(_:)`` if there are error-level issues.
    public func validateOrThrow(_ info: AudioFileInfo) throws {
        let result = validate(info)
        guard result.isValid else {
            throw AudioMarkerError.validationFailed(result.errors)
        }
    }
}

// MARK: - Internal Dispatch

extension AudioMarkerEngine {

    private func readWithFormat(_ format: AudioFormat, from url: URL) throws -> AudioFileInfo {
        do {
            switch format {
            case .mp3:
                return try ID3Reader().read(from: url)
            case .m4a, .m4b:
                return try MP4Reader().read(from: url)
            }
        } catch {
            throw AudioMarkerError.readFailed(
                "\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func performWrite(
        _ info: AudioFileInfo, format: AudioFormat, to url: URL
    ) throws {
        do {
            switch format {
            case .mp3:
                try ID3Writer().write(info, to: url, version: configuration.id3Version)
            case .m4a, .m4b:
                try MP4Writer().write(info, to: url)
            }
        } catch {
            throw AudioMarkerError.writeFailed(
                "\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func performModify(
        _ info: AudioFileInfo, format: AudioFormat, in url: URL
    ) throws {
        do {
            switch format {
            case .mp3:
                if configuration.preserveUnknownData {
                    try ID3Writer().modify(info, in: url, version: configuration.id3Version)
                } else {
                    try ID3Writer().write(info, to: url, version: configuration.id3Version)
                }
            case .m4a, .m4b:
                try MP4Writer().write(info, to: url)
            }
        } catch {
            throw AudioMarkerError.writeFailed(
                "\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func performStrip(format: AudioFormat, from url: URL) throws {
        do {
            switch format {
            case .mp3:
                try ID3Writer().stripTag(from: url)
            case .m4a, .m4b:
                try MP4Writer().stripMetadata(from: url)
            }
        } catch {
            throw AudioMarkerError.writeFailed(
                "\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
