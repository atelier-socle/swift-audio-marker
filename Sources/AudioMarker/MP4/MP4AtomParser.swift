import Foundation

/// Parses the atom (box) tree from an MP4/M4A/M4B file using streaming I/O.
///
/// The parser reads atom headers sequentially and recurses into known container
/// atoms (`moov`, `trak`, `mdia`, etc.) to build a complete tree. The `mdat`
/// atom (raw audio data) is never loaded into memory.
public struct MP4AtomParser: Sendable {

    /// Creates an MP4 atom parser.
    public init() {}

    // MARK: - Public API

    /// Parses all top-level atoms from the given file.
    /// - Parameter reader: An open file reader.
    /// - Returns: An array of parsed atoms forming the tree.
    /// - Throws: ``MP4Error`` if the file structure is invalid.
    public func parseAtoms(from reader: FileReader) throws -> [MP4Atom] {
        try parseAtoms(from: reader, startOffset: 0, endOffset: reader.fileSize, parentType: nil)
    }

    // MARK: - Recursive Parsing

    /// Parses atoms within a byte range of the file.
    private func parseAtoms(
        from reader: FileReader,
        startOffset: UInt64,
        endOffset: UInt64,
        parentType: String?
    ) throws -> [MP4Atom] {
        var atoms: [MP4Atom] = []
        var offset = startOffset

        while offset < endOffset {
            let remaining = endOffset - offset
            guard remaining >= 8 else { break }

            let atom = try parseAtomHeader(
                from: reader, at: offset, containerEnd: endOffset, parentType: parentType
            )
            atoms.append(atom)

            guard atom.size > 0 else { break }
            offset += atom.size
        }

        return atoms
    }

    /// Parses a single atom header and recursively parses children for containers.
    private func parseAtomHeader(
        from reader: FileReader,
        at offset: UInt64,
        containerEnd: UInt64,
        parentType: String?
    ) throws -> MP4Atom {
        let headerData = try reader.read(at: offset, count: 8)
        var headerReader = BinaryReader(data: headerData)

        let rawSize = try headerReader.readUInt32()
        let typeBytes = try headerReader.readData(count: 4)
        let type = String(data: typeBytes, encoding: .isoLatin1) ?? "????"

        let (size, dataOffset) = try resolveSize(
            rawSize: rawSize, type: type, offset: offset,
            containerEnd: containerEnd, reader: reader
        )

        let children = try parseChildrenIfContainer(
            type: type, reader: reader, dataOffset: dataOffset,
            atomEnd: offset + size, parentType: parentType
        )

        return MP4Atom(
            type: type, offset: offset, size: size,
            dataOffset: dataOffset, children: children
        )
    }

    // MARK: - Size Resolution

    /// Resolves the actual atom size and data offset, handling standard,
    /// extended (64-bit), and rest-of-file cases.
    private func resolveSize(
        rawSize: UInt32,
        type: String,
        offset: UInt64,
        containerEnd: UInt64,
        reader: FileReader
    ) throws -> (size: UInt64, dataOffset: UInt64) {
        switch rawSize {
        case 1:
            // Extended size: 8-byte size follows the type field.
            guard offset + 16 <= reader.fileSize else {
                throw MP4Error.invalidAtom(
                    type: type, reason: "Extended size header truncated."
                )
            }
            let extData = try reader.read(at: offset + 8, count: 8)
            var extReader = BinaryReader(data: extData)
            let extendedSize = try extReader.readUInt64()
            return (extendedSize, offset + 16)

        case 0:
            // Size 0 means the atom extends to the end of the container.
            let size = containerEnd - offset
            return (size, offset + 8)

        default:
            return (UInt64(rawSize), offset + 8)
        }
    }

    // MARK: - Container Detection & Child Parsing

    /// Parses children if the atom is a known container type.
    private func parseChildrenIfContainer(
        type: String,
        reader: FileReader,
        dataOffset: UInt64,
        atomEnd: UInt64,
        parentType: String?
    ) throws -> [MP4Atom] {
        let shouldRecurse = isContainer(type) || isILSTChild(parentType: parentType)
        guard shouldRecurse else { return [] }

        // The meta atom has 4 bytes of version/flags before its children.
        let childStart: UInt64
        if type == MP4AtomType.meta.rawValue {
            childStart = dataOffset + 4
        } else {
            childStart = dataOffset
        }

        guard childStart < atomEnd else { return [] }
        return try parseAtoms(
            from: reader, startOffset: childStart, endOffset: atomEnd, parentType: type
        )
    }

    /// Whether the given atom type is a known container that holds children.
    private func isContainer(_ type: String) -> Bool {
        guard let atomType = MP4AtomType(rawValue: type) else {
            return false
        }
        // The meta atom is a special container (has version/flags prefix).
        return atomType.isContainer || atomType == .meta
    }

    /// Whether the atom is a child of an ilst atom.
    ///
    /// All ilst children (e.g., `©nam`, `covr`, `trkn`, `----`) act as
    /// containers holding `data` sub-atoms, even though they don't appear
    /// in ``MP4AtomType``.
    private func isILSTChild(parentType: String?) -> Bool {
        parentType == MP4AtomType.ilst.rawValue
    }
}
