import Foundation

/// Reconstructs the `moov` atom with updated metadata and chapters.
///
/// Preserves the existing track structure and sample tables while
/// replacing the `udta` atom with new metadata and chapters.
/// After rebuilding, chunk offsets (`stco`/`co64`) must be adjusted
/// for any size change using ``adjustChunkOffsets(in:delta:)``.
public struct MP4MoovBuilder: Sendable {

    private let metadataBuilder = MP4MetadataBuilder()
    private let atomBuilder = MP4AtomBuilder()

    /// Creates an MP4 moov builder.
    public init() {}

    // MARK: - Public API

    /// Rebuilds the `moov` atom with new metadata and chapters.
    ///
    /// Preserves all existing children (mvhd, trak, etc.) except `udta`,
    /// which is replaced with a new one containing the provided metadata
    /// and chapters.
    /// - Parameters:
    ///   - existingMoov: The existing moov atom from the original file.
    ///   - reader: File reader for reading existing atom data.
    ///   - metadata: New metadata to write.
    ///   - chapters: New chapters to write.
    /// - Returns: Complete moov atom data.
    /// - Throws: ``MP4Error``, ``StreamingError``
    public func rebuildMoov(
        from existingMoov: MP4Atom,
        reader: FileReader,
        metadata: AudioMetadata,
        chapters: ChapterList
    ) throws -> Data {
        var children: [Data] = []

        // Copy all existing children except udta.
        for child in existingMoov.children {
            if child.type == MP4AtomType.udta.rawValue { continue }
            let childData = try reader.read(at: child.offset, count: Int(child.size))
            children.append(childData)
        }

        // Build and append new udta with metadata + chapters.
        let chaptersOrNil: ChapterList? = chapters.isEmpty ? nil : chapters
        let udta = metadataBuilder.buildUdta(from: metadata, chapters: chaptersOrNil)
        children.append(udta)

        return atomBuilder.buildContainerAtom(type: "moov", children: children)
    }

    /// Adjusts chunk offsets (`stco`/`co64`) in moov data by a delta.
    ///
    /// Scans the moov data for `stco` and `co64` atoms and adjusts
    /// each offset entry by the given delta value.
    /// - Parameters:
    ///   - moovData: The raw moov atom data.
    ///   - delta: The offset adjustment (positive = mdat moved forward,
    ///     negative = mdat moved backward).
    /// - Returns: Moov data with adjusted offsets.
    public func adjustChunkOffsets(in moovData: Data, delta: Int64) throws -> Data {
        guard delta != 0 else { return moovData }

        var adjusted = moovData
        adjustSTCO(in: &adjusted, delta: delta)
        adjustCO64(in: &adjusted, delta: delta)
        return adjusted
    }
}

// MARK: - Offset Adjustment

extension MP4MoovBuilder {

    /// Scans for `stco` atoms and adjusts 32-bit chunk offsets.
    private func adjustSTCO(in data: inout Data, delta: Int64) {
        var position = 0
        let stcoType = Data("stco".utf8)

        while position + 8 <= data.count {
            guard let atomStart = findAtomType(stcoType, in: data, from: position) else {
                break
            }

            let sizeOffset = atomStart - 4
            guard sizeOffset >= 0 else {
                position = atomStart + 4
                continue
            }

            let atomSize = readUInt32(from: data, at: sizeOffset)
            let payloadStart = atomStart + 4  // after type
            let entryCountOffset = payloadStart + 4  // skip version+flags

            guard entryCountOffset + 4 <= data.count else {
                position = atomStart + 4
                continue
            }

            let entryCount = readUInt32(from: data, at: entryCountOffset)
            adjustSTCOEntries(
                in: &data,
                entriesStart: entryCountOffset + 4,
                count: Int(entryCount),
                delta: delta
            )

            position = sizeOffset + Int(atomSize)
        }
    }

    /// Adjusts individual stco offset entries.
    private func adjustSTCOEntries(
        in data: inout Data,
        entriesStart: Int,
        count: Int,
        delta: Int64
    ) {
        for index in 0..<count {
            let offset = entriesStart + index * 4
            guard offset + 4 <= data.count else { break }
            let original = Int64(readUInt32(from: data, at: offset))
            let adjusted = UInt32(clamping: max(0, original + delta))
            writeUInt32(adjusted, to: &data, at: offset)
        }
    }

    /// Scans for `co64` atoms and adjusts 64-bit chunk offsets.
    private func adjustCO64(in data: inout Data, delta: Int64) {
        var position = 0
        let co64Type = Data("co64".utf8)

        while position + 8 <= data.count {
            guard let atomStart = findAtomType(co64Type, in: data, from: position) else {
                break
            }

            let sizeOffset = atomStart - 4
            guard sizeOffset >= 0 else {
                position = atomStart + 4
                continue
            }

            let atomSize = readUInt32(from: data, at: sizeOffset)
            let payloadStart = atomStart + 4
            let entryCountOffset = payloadStart + 4

            guard entryCountOffset + 4 <= data.count else {
                position = atomStart + 4
                continue
            }

            let entryCount = readUInt32(from: data, at: entryCountOffset)
            adjustCO64Entries(
                in: &data,
                entriesStart: entryCountOffset + 4,
                count: Int(entryCount),
                delta: delta
            )

            position = sizeOffset + Int(atomSize)
        }
    }

    /// Adjusts individual co64 offset entries.
    private func adjustCO64Entries(
        in data: inout Data,
        entriesStart: Int,
        count: Int,
        delta: Int64
    ) {
        for index in 0..<count {
            let offset = entriesStart + index * 8
            guard offset + 8 <= data.count else { break }
            let original = Int64(bitPattern: readUInt64(from: data, at: offset))
            let adjusted = UInt64(clamping: max(0, original + delta))
            writeUInt64(adjusted, to: &data, at: offset)
        }
    }
}

// MARK: - Binary Helpers

extension MP4MoovBuilder {

    /// Finds the next occurrence of a 4-byte atom type in data starting from position.
    private func findAtomType(_ type: Data, in data: Data, from start: Int) -> Int? {
        guard type.count == 4 else { return nil }
        let end = data.count - 3
        for position in start..<end {
            if data[position] == type[0],
                data[position + 1] == type[1],
                data[position + 2] == type[2],
                data[position + 3] == type[3]
            {
                return position
            }
        }
        return nil
    }

    /// Reads a big-endian UInt32 from data at the given offset.
    private func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    /// Reads a big-endian UInt64 from data at the given offset.
    private func readUInt64(from data: Data, at offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<8 {
            value = (value << 8) | UInt64(data[offset + index])
        }
        return value
    }

    /// Writes a big-endian UInt32 to data at the given offset.
    private func writeUInt32(_ value: UInt32, to data: inout Data, at offset: Int) {
        data[offset] = UInt8((value >> 24) & 0xFF)
        data[offset + 1] = UInt8((value >> 16) & 0xFF)
        data[offset + 2] = UInt8((value >> 8) & 0xFF)
        data[offset + 3] = UInt8(value & 0xFF)
    }

    /// Writes a big-endian UInt64 to data at the given offset.
    private func writeUInt64(_ value: UInt64, to data: inout Data, at offset: Int) {
        for index in 0..<8 {
            data[offset + index] = UInt8((value >> ((7 - index) * 8)) & 0xFF)
        }
    }
}
