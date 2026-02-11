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
        let newMoov = try moovBuilder.rebuildMoov(
            from: layout.moov, reader: reader,
            metadata: info.metadata, chapters: info.chapters)

        let oldMoovSize = Int64(layout.moov.size)
        let newMoovSize = Int64(newMoov.count)
        let delta = newMoovSize - oldMoovSize

        let adjustedMoov: Data
        if layout.moovBeforeMdat {
            adjustedMoov = try moovBuilder.adjustChunkOffsets(in: newMoov, delta: delta)
        } else {
            adjustedMoov = newMoov
        }

        try writeToTempFile(
            reader: reader, atoms: atoms, layout: layout,
            newMoov: adjustedMoov, source: url)
    }

    /// Strips all metadata and chapters from an MP4 file.
    ///
    /// Rebuilds the `moov` atom without the `udta` atom, preserving
    /// the audio data and track structure.
    /// - Parameter url: Source MP4 file URL.
    /// - Throws: ``MP4Error``, ``StreamingError``
    public func stripMetadata(from url: URL) throws {
        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atomParser = MP4AtomParser()
        let atoms = try atomParser.parseAtoms(from: reader)

        let layout = try analyzeLayout(atoms)

        let moovBuilder = MP4MoovBuilder()
        let newMoov = try moovBuilder.rebuildMoov(
            from: layout.moov, reader: reader,
            metadata: AudioMetadata(), chapters: ChapterList())

        let delta = Int64(newMoov.count) - Int64(layout.moov.size)

        let adjustedMoov: Data
        if layout.moovBeforeMdat {
            adjustedMoov = try moovBuilder.adjustChunkOffsets(in: newMoov, delta: delta)
        } else {
            adjustedMoov = newMoov
        }

        try writeToTempFile(
            reader: reader, atoms: atoms, layout: layout,
            newMoov: adjustedMoov, source: url)
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

    /// Writes the rebuilt file to a temporary path and atomically replaces the original.
    private func writeToTempFile(
        reader: FileReader,
        atoms: [MP4Atom],
        layout: FileLayout,
        newMoov: Data,
        source url: URL
    ) throws {
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent("." + UUID().uuidString + ".tmp")

        do {
            let writer = try FileWriter(url: tempURL)
            defer { writer.close() }

            if layout.moovBeforeMdat {
                try writeMoovFirst(
                    reader: reader, writer: writer, atoms: atoms,
                    layout: layout, newMoov: newMoov)
            } else {
                try writeMdatFirst(
                    reader: reader, writer: writer, atoms: atoms,
                    layout: layout, newMoov: newMoov)
            }

            writer.synchronize()
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }

        try atomicReplace(tempURL: tempURL, originalURL: url)
    }

    /// Writes ftyp → moov → mdat layout.
    private func writeMoovFirst(
        reader: FileReader,
        writer: FileWriter,
        atoms: [MP4Atom],
        layout: FileLayout,
        newMoov: Data
    ) throws {
        // Write ftyp.
        let ftypData = try reader.read(at: layout.ftyp.offset, count: Int(layout.ftyp.size))
        try writer.write(ftypData)

        // Write any atoms between ftyp and moov (free, skip, etc.).
        let excluded: Set<String> = [MP4AtomType.moov.rawValue, MP4AtomType.mdat.rawValue]
        for atom in atomsBetween(
            from: layout.ftyp.offset + layout.ftyp.size,
            to: layout.moov.offset, excluding: excluded, atoms: atoms)
        {
            let atomData = try reader.read(at: atom.offset, count: Int(atom.size))
            try writer.write(atomData)
        }

        // Write new moov.
        try writer.write(newMoov)

        // Stream mdat and any remaining atoms.
        try streamFromOffset(
            layout.mdat.offset,
            toEnd: reader.fileSize,
            reader: reader, writer: writer)
    }

    /// Writes ftyp → mdat → moov layout.
    private func writeMdatFirst(
        reader: FileReader,
        writer: FileWriter,
        atoms: [MP4Atom],
        layout: FileLayout,
        newMoov: Data
    ) throws {
        // Write ftyp.
        let ftypData = try reader.read(at: layout.ftyp.offset, count: Int(layout.ftyp.size))
        try writer.write(ftypData)

        // Write any atoms between ftyp and mdat.
        let excluded: Set<String> = [MP4AtomType.moov.rawValue, MP4AtomType.mdat.rawValue]
        for atom in atomsBetween(
            from: layout.ftyp.offset + layout.ftyp.size,
            to: layout.mdat.offset, excluding: excluded, atoms: atoms)
        {
            let atomData = try reader.read(at: atom.offset, count: Int(atom.size))
            try writer.write(atomData)
        }

        // Stream mdat.
        try writer.copyChunked(
            from: reader, offset: layout.mdat.offset, count: layout.mdat.size)

        // Write new moov.
        try writer.write(newMoov)
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
