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

/// Assembles a complete ID3v2 tag from an ``AudioFileInfo`` model.
///
/// Converts metadata, chapters, and optional unknown frames into a valid binary tag
/// with header, frame data, and padding.
public struct ID3TagBuilder: Sendable {

    /// Default padding appended after frame data (bytes).
    public static let defaultPadding: Int = 2048

    /// The tag version to write.
    public let version: ID3Version

    /// Creates a tag builder for the given ID3v2 version.
    /// - Parameter version: The tag version.
    public init(version: ID3Version) {
        self.version = version
    }

    // MARK: - Public API

    /// Builds a complete binary ID3v2 tag from the given audio file info.
    /// - Parameters:
    ///   - info: The audio file metadata and chapters.
    ///   - unknownFrames: Unknown frames to preserve for round-trip fidelity.
    ///   - padding: Padding bytes after frame data. Defaults to ``defaultPadding``.
    /// - Returns: Complete tag data including the 10-byte header.
    public func buildTag(
        from info: AudioFileInfo,
        unknownFrames: [ID3Frame] = [],
        padding: Int = defaultPadding
    ) -> Data {
        let frames = buildFrames(from: info, unknownFrames: unknownFrames)
        let frameBuilder = ID3FrameBuilder(version: version)

        var frameData = Data()
        for frame in frames {
            frameData.append(frameBuilder.buildFrame(frame))
        }

        let tagSize = frameData.count + padding

        var writer = BinaryWriter()
        // "ID3" marker
        writer.writeData(Data([0x49, 0x44, 0x33]))
        // Version
        writer.writeUInt8(version.majorVersion)
        writer.writeUInt8(0x00)  // Revision
        // Flags
        writer.writeUInt8(0x00)
        // Tag size (syncsafe)
        writer.writeSyncsafeUInt32(UInt32(tagSize))
        // Frame data
        writer.writeData(frameData)
        // Padding
        writer.writeRepeating(0x00, count: padding)

        return writer.data
    }
}

// MARK: - Frame Assembly

extension ID3TagBuilder {

    private func buildFrames(
        from info: AudioFileInfo,
        unknownFrames: [ID3Frame]
    ) -> [ID3Frame] {
        var frames: [ID3Frame] = []
        frames.append(contentsOf: buildMetadataTextFrames(info.metadata))
        frames.append(contentsOf: buildMetadataURLFrames(info.metadata))
        frames.append(contentsOf: buildMediaFrames(info.metadata))
        frames.append(contentsOf: buildChapterFrames(info.chapters))
        frames.append(contentsOf: buildDataFrames(info.metadata))
        frames.append(contentsOf: unknownFrames)
        return frames
    }
}

// MARK: - Metadata Text Frames

extension ID3TagBuilder {

    private func buildMetadataTextFrames(_ metadata: AudioMetadata) -> [ID3Frame] {
        var frames: [ID3Frame] = []
        appendCoreTextFrames(from: metadata, to: &frames)
        appendProfessionalTextFrames(from: metadata, to: &frames)
        for (description, value) in metadata.customTextFields.sorted(by: { $0.key < $1.key }) {
            frames.append(.userDefinedText(description: description, value: value))
        }
        return frames
    }

    private func appendCoreTextFrames(from metadata: AudioMetadata, to frames: inout [ID3Frame]) {
        if let title = metadata.title {
            frames.append(.text(id: "TIT2", text: title))
        }
        if let artist = metadata.artist {
            frames.append(.text(id: "TPE1", text: artist))
        }
        if let album = metadata.album {
            frames.append(.text(id: "TALB", text: album))
        }
        if let genre = metadata.genre {
            frames.append(.text(id: "TCON", text: genre))
        }
        if let year = metadata.year {
            let frameID = version == .v2_4 ? "TDRC" : "TYER"
            frames.append(.text(id: frameID, text: "\(year)"))
        }
        if let trackNumber = metadata.trackNumber {
            frames.append(.text(id: "TRCK", text: "\(trackNumber)"))
        }
        if let discNumber = metadata.discNumber {
            frames.append(.text(id: "TPOS", text: "\(discNumber)"))
        }
    }

    private func appendProfessionalTextFrames(
        from metadata: AudioMetadata, to frames: inout [ID3Frame]
    ) {
        if let albumArtist = metadata.albumArtist {
            frames.append(.text(id: "TPE2", text: albumArtist))
        }
        if let composer = metadata.composer {
            frames.append(.text(id: "TCOM", text: composer))
        }
        if let publisher = metadata.publisher {
            frames.append(.text(id: "TPUB", text: publisher))
        }
        if let copyright = metadata.copyright {
            frames.append(.text(id: "TCOP", text: copyright))
        }
        if let encoder = metadata.encoder {
            frames.append(.text(id: "TENC", text: encoder))
        }
        if let bpm = metadata.bpm {
            frames.append(.text(id: "TBPM", text: "\(bpm)"))
        }
        if let key = metadata.key {
            frames.append(.text(id: "TKEY", text: key))
        }
        if let language = metadata.language {
            frames.append(.text(id: "TLAN", text: language))
        }
        if let isrc = metadata.isrc {
            frames.append(.text(id: "TSRC", text: isrc))
        }
    }
}

// MARK: - Metadata URL Frames

extension ID3TagBuilder {

    private func buildMetadataURLFrames(_ metadata: AudioMetadata) -> [ID3Frame] {
        var frames: [ID3Frame] = []
        if let url = metadata.artistURL {
            frames.append(.url(id: "WOAR", url: url.absoluteString))
        }
        if let url = metadata.audioSourceURL {
            frames.append(.url(id: "WOAS", url: url.absoluteString))
        }
        if let url = metadata.audioFileURL {
            frames.append(.url(id: "WOAF", url: url.absoluteString))
        }
        if let url = metadata.publisherURL {
            frames.append(.url(id: "WPUB", url: url.absoluteString))
        }
        if let url = metadata.commercialURL {
            frames.append(.url(id: "WCOM", url: url.absoluteString))
        }
        for (description, url) in metadata.customURLs.sorted(by: { $0.key < $1.key }) {
            frames.append(.userDefinedURL(description: description, url: url.absoluteString))
        }
        return frames
    }
}

// MARK: - Media Frames

extension ID3TagBuilder {

    private func buildMediaFrames(_ metadata: AudioMetadata) -> [ID3Frame] {
        var frames: [ID3Frame] = []
        if let artwork = metadata.artwork {
            frames.append(
                .attachedPicture(
                    pictureType: 3, mimeType: artwork.format.mimeType,
                    description: "", data: artwork.data))
        }
        if let comment = metadata.comment {
            frames.append(.comment(language: "eng", description: "", text: comment))
        }
        if let lyrics = metadata.unsynchronizedLyrics {
            frames.append(.unsyncLyrics(language: "eng", description: "", text: lyrics))
        }
        for syncLyrics in metadata.synchronizedLyrics {
            let events = syncLyrics.lines.map { line in
                SyncLyricEvent(
                    text: line.text,
                    timestamp: UInt32(line.time.timeInterval * 1000))
            }
            frames.append(
                .syncLyrics(
                    language: syncLyrics.language,
                    contentType: syncLyrics.contentType.rawValue,
                    description: syncLyrics.descriptor, events: events))
        }
        return frames
    }
}

// MARK: - Chapter Frames

extension ID3TagBuilder {

    private func buildChapterFrames(_ chapters: ChapterList) -> [ID3Frame] {
        guard !chapters.isEmpty else { return [] }

        var frames: [ID3Frame] = []
        var childIDs: [String] = []

        for index in chapters.indices {
            let chapter = chapters[index]
            let elementID = "chp\(index)"
            childIDs.append(elementID)

            var subframes: [ID3Frame] = [.text(id: "TIT2", text: chapter.title)]
            if let url = chapter.url {
                subframes.append(.url(id: "WOAR", url: url.absoluteString))
            }
            if let artwork = chapter.artwork {
                subframes.append(
                    .attachedPicture(
                        pictureType: 3, mimeType: artwork.format.mimeType,
                        description: "", data: artwork.data))
            }

            let startMs = UInt32(chapter.start.timeInterval * 1000)
            let endMs: UInt32
            if let end = chapter.end {
                endMs = UInt32(end.timeInterval * 1000)
            } else if index + 1 < chapters.count {
                endMs = UInt32(chapters[index + 1].start.timeInterval * 1000)
            } else {
                endMs = startMs + 1
            }
            frames.append(
                .chapter(
                    elementID: elementID, startTime: startMs,
                    endTime: endMs, subframes: subframes))
        }

        frames.insert(
            .tableOfContents(
                elementID: "toc1", isTopLevel: true, isOrdered: true,
                childElementIDs: childIDs, subframes: []),
            at: 0)

        return frames
    }
}

// MARK: - Data Frames

extension ID3TagBuilder {

    private func buildDataFrames(_ metadata: AudioMetadata) -> [ID3Frame] {
        var frames: [ID3Frame] = []
        for priv in metadata.privateData {
            frames.append(.privateData(owner: priv.owner, data: priv.data))
        }
        for ufid in metadata.uniqueFileIdentifiers {
            frames.append(.uniqueFileID(owner: ufid.owner, identifier: ufid.identifier))
        }
        if let playCount = metadata.playCount {
            frames.append(.playCounter(count: UInt64(playCount)))
        }
        if let rating = metadata.rating {
            frames.append(.popularimeter(email: "", rating: rating, playCount: 0))
        }
        return frames
    }
}
