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

/// Builds a video track (`trak` atom) for per-chapter artwork in MP4/M4A files.
///
/// Per-chapter artwork in QuickTime-style M4A files is stored as image samples
/// (JPEG or PNG) in a video track referenced by the audio track's `tref/chap`.
/// Each chapter with artwork gets one image sample; the sample duration matches
/// the chapter duration.
public struct MP4VideoTrackBuilder: Sendable {

    private let atomBuilder = MP4AtomBuilder()

    /// Creates a video track builder.
    public init() {}

    // MARK: - Supporting Types

    /// Groups the fields needed to describe an image sample in a video track.
    private struct SampleDescription: Sendable {
        /// The image format (JPEG or PNG).
        let format: ArtworkFormat
        /// The image width in pixels.
        let width: UInt16
        /// The image height in pixels.
        let height: UInt16
    }

    // MARK: - Result Type

    /// The result of building a chapter artwork video track.
    public struct VideoTrackResult: Sendable {
        /// Complete `trak` atom data for the video track.
        public let trak: Data
        /// Concatenated image sample data (not wrapped in mdat).
        public let sampleData: Data
        /// Per-sample sizes for each artwork image.
        public let sampleSizes: [UInt32]
        /// Byte positions of stco entry values within the trak data.
        public let stcoEntryOffsets: [Int]
    }

    // MARK: - Public API

    /// Builds a video track for per-chapter artwork.
    ///
    /// Returns `nil` if no chapters have artwork. Only chapters with artwork
    /// are included as samples; their durations are calculated based on the
    /// chapter timeline.
    /// - Parameters:
    ///   - chapters: The chapters (only those with artwork generate samples).
    ///   - trackID: The track ID to assign to this video track.
    ///   - movieTimescale: The movie-level timescale (from mvhd).
    ///   - movieDuration: The movie-level duration (from mvhd).
    /// - Returns: A ``VideoTrackResult`` or `nil` if no chapters have artwork.
    public func buildVideoTrack(
        chapters: ChapterList,
        trackID: UInt32,
        movieTimescale: UInt32,
        movieDuration: UInt64
    ) -> VideoTrackResult? {
        // Collect chapters that have artwork, with their indices.
        var artworkEntries: [(index: Int, artwork: Artwork)] = []
        for (index, chapter) in chapters.enumerated() {
            if let artwork = chapter.artwork {
                artworkEntries.append((index: index, artwork: artwork))
            }
        }
        guard !artworkEntries.isEmpty else { return nil }

        // Determine format from first artwork.
        let primaryFormat = artworkEntries[0].artwork.format

        // Build sample data and sizes.
        var sampleData = Data()
        var sampleSizes: [UInt32] = []
        for entry in artworkEntries {
            sampleSizes.append(UInt32(entry.artwork.data.count))
            sampleData.append(entry.artwork.data)
        }

        // Calculate durations for each artwork sample in movie timescale.
        let sampleDurations = buildArtworkSampleDurations(
            chapters: chapters,
            artworkEntries: artworkEntries,
            movieTimescale: movieTimescale,
            movieDuration: movieDuration)

        // Detect image dimensions from first artwork.
        let (width, height) = detectImageDimensions(from: artworkEntries[0].artwork.data)

        // Build tkhd (enabled track).
        let tkhd = buildTkhd(
            trackID: trackID, movieTimescale: movieTimescale,
            movieDuration: movieDuration, width: width, height: height)

        // Build mdia.
        let mdhd = buildMdhd(timescale: movieTimescale, duration: movieDuration)
        let hdlr = buildHdlr()
        let description = SampleDescription(
            format: primaryFormat, width: width, height: height)
        let minf = buildMinf(
            sampleDescription: description,
            sampleDurations: sampleDurations,
            sampleSizes: sampleSizes,
            sampleCount: artworkEntries.count)
        let mdia = atomBuilder.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])

        // Build trak.
        let trak = atomBuilder.buildContainerAtom(type: "trak", children: [tkhd, mdia])

        // Find stco entry offsets within trak data.
        let stcoEntryOffsets = findStcoEntryOffsets(
            in: trak, entryCount: artworkEntries.count)

        return VideoTrackResult(
            trak: trak, sampleData: sampleData,
            sampleSizes: sampleSizes, stcoEntryOffsets: stcoEntryOffsets)
    }
}

// MARK: - Track Header

extension MP4VideoTrackBuilder {

    /// Builds a `tkhd` atom for an enabled video track (version 0).
    private func buildTkhd(
        trackID: UInt32, movieTimescale: UInt32,
        movieDuration: UInt64, width: UInt16, height: UInt16
    ) -> Data {
        var payload = BinaryWriter(capacity: 84)
        payload.writeUInt8(0)  // version
        // flags: 0x000001 (track enabled)
        payload.writeUInt8(0x00)
        payload.writeUInt8(0x00)
        payload.writeUInt8(0x01)
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(trackID)
        payload.writeUInt32(0)  // reserved
        // Duration in movie timescale.
        payload.writeUInt32(UInt32(clamping: movieDuration))
        // Reserved (8 bytes) + layer (2) + alternate group (2) + volume (2) + reserved (2).
        payload.writeRepeating(0x00, count: 16)
        // Identity matrix (36 bytes).
        writeIdentityMatrix(to: &payload)
        // Width and height in 16.16 fixed-point.
        payload.writeUInt16(width)
        payload.writeUInt16(0)
        payload.writeUInt16(height)
        payload.writeUInt16(0)
        return atomBuilder.buildAtom(type: "tkhd", data: payload.data)
    }

    /// Writes a 3x3 identity matrix in fixed-point 16.16 / 2.30 format.
    private func writeIdentityMatrix(to writer: inout BinaryWriter) {
        writer.writeUInt32(0x0001_0000)  // 1.0 (16.16)
        writer.writeUInt32(0)
        writer.writeUInt32(0)
        writer.writeUInt32(0)
        writer.writeUInt32(0x0001_0000)  // 1.0 (16.16)
        writer.writeUInt32(0)
        writer.writeUInt32(0)
        writer.writeUInt32(0)
        writer.writeUInt32(0x4000_0000)  // 1.0 (2.30)
    }
}

// MARK: - Media Header & Handler

extension MP4VideoTrackBuilder {

    /// Builds an `mdhd` atom (version 0) with timescale and duration.
    private func buildMdhd(timescale: UInt32, duration: UInt64) -> Data {
        var payload = BinaryWriter(capacity: 24)
        payload.writeUInt8(0)  // version
        payload.writeRepeating(0x00, count: 3)  // flags
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt32(UInt32(clamping: duration))
        payload.writeUInt16(0x55C4)  // language: undetermined
        payload.writeUInt16(0)  // pre_defined
        return atomBuilder.buildAtom(type: "mdhd", data: payload.data)
    }

    /// Builds an `hdlr` atom for a video handler.
    private func buildHdlr() -> Data {
        var payload = BinaryWriter(capacity: 33)
        payload.writeUInt8(0)  // version
        payload.writeRepeating(0x00, count: 3)  // flags
        payload.writeUInt32(0)  // pre_defined
        payload.writeLatin1String("vide")  // handler_type
        payload.writeRepeating(0x00, count: 12)  // reserved
        payload.writeNullTerminatedLatin1String("ArtworkHandler")
        return atomBuilder.buildAtom(type: "hdlr", data: payload.data)
    }
}

// MARK: - Media Information

extension MP4VideoTrackBuilder {

    /// Builds the `minf` container (vmhd + dinf + stbl).
    private func buildMinf(
        sampleDescription: SampleDescription,
        sampleDurations: [(count: UInt32, duration: UInt32)],
        sampleSizes: [UInt32],
        sampleCount: Int
    ) -> Data {
        let vmhd = buildVmhd()
        let dinf = buildDinf()
        let stbl = buildStbl(
            sampleDescription: sampleDescription,
            sampleDurations: sampleDurations,
            sampleSizes: sampleSizes,
            sampleCount: sampleCount)
        return atomBuilder.buildContainerAtom(type: "minf", children: [vmhd, dinf, stbl])
    }

    /// Builds a `vmhd` (video media header) atom.
    private func buildVmhd() -> Data {
        var payload = BinaryWriter(capacity: 12)
        payload.writeUInt8(0)  // version
        // flags: 0x000001 (no lean ahead)
        payload.writeUInt8(0x00)
        payload.writeUInt8(0x00)
        payload.writeUInt8(0x01)
        payload.writeUInt16(0)  // graphicsmode
        payload.writeRepeating(0x00, count: 6)  // opcolor
        return atomBuilder.buildAtom(type: "vmhd", data: payload.data)
    }

    /// Builds a `dinf → dref → url` for self-contained data.
    private func buildDinf() -> Data {
        var urlPayload = BinaryWriter(capacity: 4)
        urlPayload.writeUInt8(0)  // version
        urlPayload.writeUInt8(0)
        urlPayload.writeUInt8(0)
        urlPayload.writeUInt8(0x01)  // flags: self-contained
        let urlAtom = atomBuilder.buildAtom(type: "url ", data: urlPayload.data)

        var drefPayload = BinaryWriter(capacity: 8 + urlAtom.count)
        drefPayload.writeUInt32(0)  // version + flags
        drefPayload.writeUInt32(1)  // entry count
        drefPayload.writeData(urlAtom)
        let dref = atomBuilder.buildAtom(type: "dref", data: drefPayload.data)

        return atomBuilder.buildContainerAtom(type: "dinf", children: [dref])
    }
}

// MARK: - Sample Table

extension MP4VideoTrackBuilder {

    /// Builds the `stbl` container with all sample table atoms.
    private func buildStbl(
        sampleDescription: SampleDescription,
        sampleDurations: [(count: UInt32, duration: UInt32)],
        sampleSizes: [UInt32],
        sampleCount: Int
    ) -> Data {
        let stsd = buildStsd(
            format: sampleDescription.format,
            width: sampleDescription.width,
            height: sampleDescription.height)
        let stts = buildStts(entries: sampleDurations)
        let stsc = buildStsc()
        let stsz = buildStsz(sizes: sampleSizes)
        let stco = buildStco(entryCount: sampleCount)
        return atomBuilder.buildContainerAtom(
            type: "stbl", children: [stsd, stts, stsc, stsz, stco])
    }

    /// Builds an `stsd` with a JPEG or PNG video sample description.
    ///
    /// Sample entry format (86 bytes):
    /// size(4) + format(4) + reserved(6) + dataRefIndex(2) + version(2) + revision(2)
    /// + vendor(4) + temporalQuality(4) + spatialQuality(4) + width(2) + height(2)
    /// + hRes(4) + vRes(4) + dataSize(4) + frameCount(2) + compressorName(32)
    /// + depth(2) + colorTableID(2)
    private func buildStsd(format: ArtworkFormat, width: UInt16, height: UInt16) -> Data {
        let formatCode = format == .jpeg ? "jpeg" : "png "
        var desc = BinaryWriter(capacity: 86)
        desc.writeUInt32(86)  // size of description
        desc.writeLatin1String(formatCode)  // format
        desc.writeRepeating(0x00, count: 6)  // reserved
        desc.writeUInt16(1)  // data reference index
        desc.writeUInt16(0)  // version
        desc.writeUInt16(0)  // revision
        desc.writeRepeating(0x00, count: 4)  // vendor
        desc.writeUInt32(0)  // temporal quality
        desc.writeUInt32(512)  // spatial quality
        desc.writeUInt16(width)
        desc.writeUInt16(height)
        desc.writeUInt32(0x0048_0000)  // hRes: 72 dpi (16.16)
        desc.writeUInt32(0x0048_0000)  // vRes: 72 dpi (16.16)
        desc.writeUInt32(0)  // data size
        desc.writeUInt16(1)  // frame count
        desc.writeRepeating(0x00, count: 32)  // compressor name
        desc.writeUInt16(24)  // depth
        desc.writeUInt16(0xFFFF)  // color table ID (-1 = no table)

        var stsdPayload = BinaryWriter(capacity: 8 + desc.count)
        stsdPayload.writeUInt32(0)  // version + flags
        stsdPayload.writeUInt32(1)  // entry count
        stsdPayload.writeData(desc.data)
        return atomBuilder.buildAtom(type: "stsd", data: stsdPayload.data)
    }

    /// Builds an `stts` atom from run-length encoded durations.
    private func buildStts(entries: [(count: UInt32, duration: UInt32)]) -> Data {
        var payload = BinaryWriter(capacity: 8 + entries.count * 8)
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(UInt32(entries.count))
        for entry in entries {
            payload.writeUInt32(entry.count)
            payload.writeUInt32(entry.duration)
        }
        return atomBuilder.buildAtom(type: "stts", data: payload.data)
    }

    /// Builds an `stsc` atom: one chunk per sample.
    private func buildStsc() -> Data {
        var payload = BinaryWriter(capacity: 20)
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(1)  // entry count
        payload.writeUInt32(1)  // first_chunk
        payload.writeUInt32(1)  // samples_per_chunk
        payload.writeUInt32(1)  // sample_description_index
        return atomBuilder.buildAtom(type: "stsc", data: payload.data)
    }

    /// Builds an `stsz` atom with per-sample sizes.
    private func buildStsz(sizes: [UInt32]) -> Data {
        var payload = BinaryWriter(capacity: 12 + sizes.count * 4)
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(0)  // default size (0 = per-sample)
        payload.writeUInt32(UInt32(sizes.count))
        for size in sizes {
            payload.writeUInt32(size)
        }
        return atomBuilder.buildAtom(type: "stsz", data: payload.data)
    }

    /// Builds an `stco` atom with placeholder zero offsets.
    private func buildStco(entryCount: Int) -> Data {
        var payload = BinaryWriter(capacity: 8 + entryCount * 4)
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(UInt32(entryCount))
        for _ in 0..<entryCount {
            payload.writeUInt32(0)  // placeholder
        }
        return atomBuilder.buildAtom(type: "stco", data: payload.data)
    }
}

// MARK: - Duration Calculation

extension MP4VideoTrackBuilder {

    /// Calculates per-sample durations for artwork samples.
    ///
    /// Each artwork sample covers the duration from its chapter start to the
    /// next chapter's start (or movie end for the last chapter).
    private func buildArtworkSampleDurations(
        chapters: ChapterList,
        artworkEntries: [(index: Int, artwork: Artwork)],
        movieTimescale: UInt32,
        movieDuration: UInt64
    ) -> [(count: UInt32, duration: UInt32)] {
        var entries: [(count: UInt32, duration: UInt32)] = []
        let totalDurationSec = Double(movieDuration) / Double(movieTimescale)

        for (entryIdx, entry) in artworkEntries.enumerated() {
            let chapterIndex = entry.index
            let startSec = chapters[chapterIndex].start.timeInterval
            let endSec: Double
            if chapterIndex + 1 < chapters.count {
                endSec = chapters[chapterIndex + 1].start.timeInterval
            } else {
                endSec = totalDurationSec
            }

            // If there's a next artwork entry, the sample duration extends to the
            // next artwork chapter's start — but for simplicity, use the chapter boundary.
            _ = entryIdx  // suppress unused warning
            let duration = UInt32(max(1, (endSec - startSec) * Double(movieTimescale)))
            entries.append((count: 1, duration: duration))
        }
        return entries
    }
}

// MARK: - Image Dimension Detection

extension MP4VideoTrackBuilder {

    /// Detects image width and height from JPEG or PNG data.
    ///
    /// Returns `(300, 300)` as fallback if detection fails.
    private func detectImageDimensions(from data: Data) -> (width: UInt16, height: UInt16) {
        if let dims = detectJPEGDimensions(from: data) { return dims }
        if let dims = detectPNGDimensions(from: data) { return dims }
        return (300, 300)
    }

    /// Reads width/height from a JPEG's SOF0 marker.
    private func detectJPEGDimensions(from data: Data) -> (width: UInt16, height: UInt16)? {
        guard data.count >= 4,
            data[0] == 0xFF, data[1] == 0xD8
        else { return nil }

        var offset = 2
        while offset + 4 < data.count {
            guard data[offset] == 0xFF else { break }
            let marker = data[offset + 1]
            offset += 2

            // SOF0 (0xC0) or SOF2 (0xC2) contain dimensions.
            if marker == 0xC0 || marker == 0xC2 {
                guard offset + 7 <= data.count else { return nil }
                let segLen = Int(data[offset]) << 8 | Int(data[offset + 1])
                guard segLen >= 7 else { return nil }
                let height = UInt16(data[offset + 3]) << 8 | UInt16(data[offset + 4])
                let width = UInt16(data[offset + 5]) << 8 | UInt16(data[offset + 6])
                return (width, height)
            }

            // Skip segment.
            guard offset + 2 <= data.count else { break }
            let segLength = Int(data[offset]) << 8 | Int(data[offset + 1])
            offset += segLength
        }
        return nil
    }

    /// Reads width/height from a PNG's IHDR chunk.
    private func detectPNGDimensions(from data: Data) -> (width: UInt16, height: UInt16)? {
        // PNG header (8) + IHDR length (4) + "IHDR" (4) + width (4) + height (4) = 24 bytes min.
        guard data.count >= 24,
            data[0] == 0x89, data[1] == 0x50, data[2] == 0x4E, data[3] == 0x47
        else { return nil }

        let width =
            UInt32(data[16]) << 24 | UInt32(data[17]) << 16
            | UInt32(data[18]) << 8 | UInt32(data[19])
        let height =
            UInt32(data[20]) << 24 | UInt32(data[21]) << 16
            | UInt32(data[22]) << 8 | UInt32(data[23])
        return (UInt16(clamping: width), UInt16(clamping: height))
    }
}

// MARK: - Stco Offset Finding

extension MP4VideoTrackBuilder {

    /// Finds the byte positions of stco entries within the trak data.
    private func findStcoEntryOffsets(in trakData: Data, entryCount: Int) -> [Int] {
        let stcoType = Data("stco".utf8)
        var position = 0

        while position + 8 <= trakData.count {
            if position + 4 <= trakData.count - 3,
                trakData[position + 4] == stcoType[0],
                trakData[position + 5] == stcoType[1],
                trakData[position + 6] == stcoType[2],
                trakData[position + 7] == stcoType[3]
            {
                let entriesStart = position + 16
                var offsets: [Int] = []
                for index in 0..<entryCount {
                    offsets.append(entriesStart + index * 4)
                }
                return offsets
            }
            position += 1
        }
        return []
    }
}
