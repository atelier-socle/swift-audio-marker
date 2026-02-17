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

/// Writes metadata and chapters to MP4/M4A/M4B files.
///
/// Uses a rebuild strategy: writes to a temporary file and performs
/// an atomic rename. Audio data (`mdat`) is never loaded into memory —
/// it is streamed via ``FileReader`` and ``FileWriter``.
///
/// Preserves the original file layout (moov before/after mdat).
public struct MP4Writer: Sendable {

    /// Creates an MP4 writer.
    public init() {}

    // MARK: - Public API

    /// Writes metadata and chapters to an MP4 file.
    ///
    /// Rebuilds the `moov` atom with the provided metadata and chapters,
    /// adjusts chunk offsets, and writes the result to a new file.
    /// Chapters are written in both Nero (`chpl`) and QuickTime text track
    /// formats for maximum player compatibility.
    /// - Parameters:
    ///   - info: The audio file info to write.
    ///   - url: Source MP4 file URL.
    /// - Throws: ``MP4Error``, ``StreamingError``
    public func write(_ info: AudioFileInfo, to url: URL) throws {
        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atomParser = MP4AtomParser()
        let atoms = try atomParser.parseAtoms(from: reader)

        let layout = try analyzeLayout(atoms)

        let moovBuilder = MP4MoovBuilder()
        let buildResult = try moovBuilder.rebuildMoov(
            from: layout.moov, reader: reader,
            metadata: info.metadata, chapters: info.chapters)

        let adjustedMoov = try adjustMoovForLayout(
            moovBuilder: moovBuilder, buildResult: buildResult,
            layout: layout, atoms: atoms, reader: reader)

        let context = WriteContext(
            reader: reader, atoms: atoms, layout: layout,
            newMoov: adjustedMoov,
            chapterSampleData: buildResult.chapterSampleData,
            artworkSampleData: buildResult.artworkSampleData)
        try writeToTempFile(context, source: url)
    }

    /// Strips metadata from an MP4 file while preserving chapters.
    ///
    /// Rebuilds the `moov` atom with empty metadata but retains the
    /// existing chapter structure. Chapters are structural data, not
    /// metadata — use ``AudioMarkerEngine/writeChapters(_:to:)`` with
    /// an empty ``ChapterList`` to remove them explicitly.
    /// - Parameter url: Source MP4 file URL.
    /// - Throws: ``MP4Error``, ``StreamingError``
    public func stripMetadata(from url: URL) throws {
        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atomParser = MP4AtomParser()
        let atoms = try atomParser.parseAtoms(from: reader)

        let layout = try analyzeLayout(atoms)

        // Preserve existing chapters — they are structural, not metadata.
        let chapterParser = MP4ChapterParser()
        let existingChapters = try chapterParser.parseChapters(from: atoms, reader: reader)

        let moovBuilder = MP4MoovBuilder()
        let buildResult = try moovBuilder.rebuildMoov(
            from: layout.moov, reader: reader,
            metadata: AudioMetadata(), chapters: existingChapters)

        let adjustedMoov = try adjustMoovForLayout(
            moovBuilder: moovBuilder, buildResult: buildResult,
            layout: layout, atoms: atoms, reader: reader)

        let context = WriteContext(
            reader: reader, atoms: atoms, layout: layout,
            newMoov: adjustedMoov,
            chapterSampleData: buildResult.chapterSampleData,
            artworkSampleData: buildResult.artworkSampleData)
        try writeToTempFile(context, source: url)
    }
}

// MARK: - Moov Adjustment

extension MP4Writer {

    /// Adjusts moov chunk offsets for the new layout and patches text/video track stco.
    private func adjustMoovForLayout(
        moovBuilder: MP4MoovBuilder,
        buildResult: MP4MoovBuilder.MoovBuildResult,
        layout: FileLayout,
        atoms: [MP4Atom],
        reader: FileReader
    ) throws -> Data {
        var moovData = buildResult.moov
        let hasChapterMdat =
            !buildResult.chapterSampleData.isEmpty
            || !buildResult.artworkSampleData.isEmpty

        if layout.moovBeforeMdat {
            // moov-first: delta = (new moov size) - (original moov→mdat span)
            let originalSpan = Int64(layout.mdat.offset - layout.moov.offset)
            let delta = Int64(moovData.count) - originalSpan
            moovData = try moovBuilder.adjustChunkOffsets(in: moovData, delta: delta)

            // Patch chapter track stco entries: chapter mdat is after the original mdat.
            if hasChapterMdat {
                let originalMdatEnd = layout.mdat.offset + layout.mdat.size
                let newMdatEnd = Int64(originalMdatEnd) + delta
                let chapterMdatDataStart = UInt32(newMdatEnd + 8)  // after chapter mdat header
                patchChapterTrackStco(
                    in: &moovData, builder: moovBuilder,
                    buildResult: buildResult,
                    chapterMdatDataStart: chapterMdatDataStart)
            }
        } else {
            // mdat-first: moov comes after mdat. Audio stco is already correct.
            // Patch chapter track stco: chapter mdat is placed after original mdat.
            if hasChapterMdat {
                let originalMdatEnd = layout.mdat.offset + layout.mdat.size
                let chapterMdatDataStart = UInt32(originalMdatEnd + 8)
                patchChapterTrackStco(
                    in: &moovData, builder: moovBuilder,
                    buildResult: buildResult,
                    chapterMdatDataStart: chapterMdatDataStart)
            }
        }

        return moovData
    }

    /// Patches both text track and video track stco entries.
    private func patchChapterTrackStco(
        in moovData: inout Data,
        builder: MP4MoovBuilder,
        buildResult: MP4MoovBuilder.MoovBuildResult,
        chapterMdatDataStart: UInt32
    ) {
        // Patch text track stco.
        if !buildResult.chapterSampleData.isEmpty {
            let textOffsets = calculateSampleOffsets(
                sampleSizes: buildResult.textSampleSizes,
                mdatDataStart: chapterMdatDataStart)
            builder.patchStcoEntries(
                in: &moovData,
                offsets: textOffsets,
                positions: buildResult.textTrackStcoOffsets)
        }

        // Patch video track stco: artwork samples start after text samples.
        if !buildResult.artworkSampleData.isEmpty,
            !buildResult.videoTrackStcoOffsets.isEmpty
        {
            let videoMdatDataStart =
                chapterMdatDataStart + UInt32(buildResult.chapterSampleData.count)
            let videoOffsets = calculateArtworkSampleOffsets(
                sampleSizes: buildResult.artworkSampleSizes,
                mdatDataStart: videoMdatDataStart)
            builder.patchStcoEntries(
                in: &moovData,
                offsets: videoOffsets,
                positions: buildResult.videoTrackStcoOffsets)
        }
    }

    /// Calculates absolute offsets for text samples in the chapter mdat.
    private func calculateSampleOffsets(
        sampleSizes: [UInt32], mdatDataStart: UInt32
    ) -> [UInt32] {
        var offsets: [UInt32] = []
        var currentOffset = mdatDataStart
        for size in sampleSizes {
            offsets.append(currentOffset)
            currentOffset += size
        }
        return offsets
    }

    /// Calculates absolute offsets for artwork samples using stored sample sizes.
    private func calculateArtworkSampleOffsets(
        sampleSizes: [UInt32],
        mdatDataStart: UInt32
    ) -> [UInt32] {
        var offsets: [UInt32] = []
        var currentOffset = mdatDataStart
        for size in sampleSizes {
            offsets.append(currentOffset)
            currentOffset += size
        }
        return offsets
    }
}

// MARK: - Layout Analysis

extension MP4Writer {

    /// Describes the file layout and key atom positions.
    struct FileLayout {
        let moov: MP4Atom
        let mdat: MP4Atom
        let ftyp: MP4Atom
        let moovBeforeMdat: Bool
    }

    /// Analyzes the file layout to find moov, mdat, and ftyp positions.
    private func analyzeLayout(_ atoms: [MP4Atom]) throws -> FileLayout {
        guard let ftyp = atoms.first(where: { $0.type == MP4AtomType.ftyp.rawValue }) else {
            throw MP4Error.invalidFile("Missing ftyp atom.")
        }
        guard let moov = atoms.first(where: { $0.type == MP4AtomType.moov.rawValue }) else {
            throw MP4Error.atomNotFound("moov")
        }
        guard let mdat = atoms.first(where: { $0.type == MP4AtomType.mdat.rawValue }) else {
            throw MP4Error.atomNotFound("mdat")
        }

        return FileLayout(
            moov: moov, mdat: mdat, ftyp: ftyp,
            moovBeforeMdat: moov.offset < mdat.offset)
    }
}

// MARK: - Write Strategy

extension MP4Writer {

    /// Bundles the data needed for writing the rebuilt file.
    private struct WriteContext {
        let reader: FileReader
        let atoms: [MP4Atom]
        let layout: FileLayout
        let newMoov: Data
        let chapterSampleData: Data
        let artworkSampleData: Data
    }

    /// Writes the rebuilt file to a temporary path and atomically replaces the original.
    private func writeToTempFile(_ context: WriteContext, source url: URL) throws {
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent("." + UUID().uuidString + ".tmp")

        do {
            let writer = try FileWriter(url: tempURL)
            defer { writer.close() }

            if context.layout.moovBeforeMdat {
                try writeMoovFirst(context, writer: writer)
            } else {
                try writeMdatFirst(context, writer: writer)
            }

            writer.synchronize()
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }

        try atomicReplace(tempURL: tempURL, originalURL: url)
    }

    /// Writes ftyp → moov → mdat → chapter mdat layout.
    private func writeMoovFirst(_ context: WriteContext, writer: FileWriter) throws {
        // Write ftyp.
        let ftypData = try context.reader.read(
            at: context.layout.ftyp.offset, count: Int(context.layout.ftyp.size))
        try writer.write(ftypData)

        // Write any atoms between ftyp and moov (free, skip, etc.).
        let excluded: Set<String> = [MP4AtomType.moov.rawValue, MP4AtomType.mdat.rawValue]
        for atom in atomsBetween(
            from: context.layout.ftyp.offset + context.layout.ftyp.size,
            to: context.layout.moov.offset, excluding: excluded, atoms: context.atoms)
        {
            let atomData = try context.reader.read(at: atom.offset, count: Int(atom.size))
            try writer.write(atomData)
        }

        // Write new moov.
        try writer.write(context.newMoov)

        // Stream original mdat only (excludes any old chapter mdat from prior writes).
        try writer.copyChunked(
            from: context.reader, offset: context.layout.mdat.offset,
            count: context.layout.mdat.size)

        // Write chapter mdat (if any).
        if !context.chapterSampleData.isEmpty || !context.artworkSampleData.isEmpty {
            try writeChapterMdat(
                textSamples: context.chapterSampleData,
                artworkSamples: context.artworkSampleData, writer: writer)
        }
    }

    /// Writes ftyp → mdat → chapter mdat → moov layout.
    private func writeMdatFirst(_ context: WriteContext, writer: FileWriter) throws {
        // Write ftyp.
        let ftypData = try context.reader.read(
            at: context.layout.ftyp.offset, count: Int(context.layout.ftyp.size))
        try writer.write(ftypData)

        // Write any atoms between ftyp and mdat.
        let excluded: Set<String> = [MP4AtomType.moov.rawValue, MP4AtomType.mdat.rawValue]
        for atom in atomsBetween(
            from: context.layout.ftyp.offset + context.layout.ftyp.size,
            to: context.layout.mdat.offset, excluding: excluded, atoms: context.atoms)
        {
            let atomData = try context.reader.read(at: atom.offset, count: Int(atom.size))
            try writer.write(atomData)
        }

        // Stream original mdat.
        try writer.copyChunked(
            from: context.reader, offset: context.layout.mdat.offset,
            count: context.layout.mdat.size)

        // Write chapter mdat (if any).
        if !context.chapterSampleData.isEmpty || !context.artworkSampleData.isEmpty {
            try writeChapterMdat(
                textSamples: context.chapterSampleData,
                artworkSamples: context.artworkSampleData, writer: writer)
        }

        // Write new moov.
        try writer.write(context.newMoov)
    }

    /// Writes a chapter mdat atom containing text samples and optional artwork samples.
    private func writeChapterMdat(
        textSamples: Data, artworkSamples: Data, writer: FileWriter
    ) throws {
        let totalSize = textSamples.count + artworkSamples.count
        var mdatHeader = BinaryWriter(capacity: 8)
        mdatHeader.writeUInt32(UInt32(8 + totalSize))
        mdatHeader.writeLatin1String("mdat")
        try writer.write(mdatHeader.data)
        try writer.write(textSamples)
        if !artworkSamples.isEmpty {
            try writer.write(artworkSamples)
        }
    }

    /// Returns atoms in a range, excluding specified types.
    private func atomsBetween(
        from start: UInt64,
        to end: UInt64,
        excluding: Set<String>,
        atoms: [MP4Atom]
    ) -> [MP4Atom] {
        atoms.filter { $0.offset >= start && $0.offset < end && !excluding.contains($0.type) }
    }

    /// Streams raw bytes from an offset to the end.
    private func streamFromOffset(
        _ offset: UInt64,
        toEnd end: UInt64,
        reader: FileReader,
        writer: FileWriter
    ) throws {
        guard offset < end else { return }
        let count = end - offset
        try writer.copyChunked(from: reader, offset: offset, count: count)
    }

    /// Atomically replaces the original file with the temporary file.
    private func atomicReplace(tempURL: URL, originalURL: URL) throws {
        do {
            _ = try FileManager.default.replaceItemAt(originalURL, withItemAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw MP4Error.writeFailed(
                "Failed to replace \(originalURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
    }
}
