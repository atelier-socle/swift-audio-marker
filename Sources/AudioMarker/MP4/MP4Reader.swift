import Foundation

/// Reads and parses MP4/M4A/M4B files into the domain model.
///
/// Orchestrates atom parsing, file type validation, metadata extraction,
/// and chapter extraction using streaming I/O. Audio data (`mdat`) is
/// never loaded into memory.
public struct MP4Reader: Sendable {

    /// Creates an MP4 reader.
    public init() {}

    // MARK: - Public API

    /// Reads all metadata, chapters, and duration from an MP4/M4A/M4B file.
    /// - Parameter url: URL of the file to read.
    /// - Returns: Parsed audio file info.
    /// - Throws: ``MP4Error``, ``StreamingError``
    public func read(from url: URL) throws -> AudioFileInfo {
        let reader = try FileReader(url: url)
        defer { reader.close() }

        let atoms = try parseAndValidate(reader: reader)

        let metadataParser = MP4MetadataParser()
        let chapterParser = MP4ChapterParser()

        let metadata = try metadataParser.parseMetadata(from: atoms, reader: reader)
        let duration = try metadataParser.parseDuration(from: atoms, reader: reader)
        let chapters = try chapterParser.parseChapters(from: atoms, reader: reader)

        return AudioFileInfo(metadata: metadata, chapters: chapters, duration: duration)
    }

    /// Reads only the raw atom tree without extracting metadata.
    ///
    /// Useful for inspection or debugging.
    /// - Parameter url: URL of the file to read.
    /// - Returns: The top-level atom tree.
    /// - Throws: ``MP4Error``, ``StreamingError``
    public func readAtoms(from url: URL) throws -> [MP4Atom] {
        let reader = try FileReader(url: url)
        defer { reader.close() }

        return try parseAndValidate(reader: reader)
    }

    // MARK: - Validation

    /// Parses the atom tree and validates the file type.
    private func parseAndValidate(reader: FileReader) throws -> [MP4Atom] {
        guard reader.fileSize >= 8 else {
            throw MP4Error.invalidFile("File too small: \(reader.fileSize) bytes.")
        }

        let atomParser = MP4AtomParser()
        let atoms = try atomParser.parseAtoms(from: reader)

        try validateFileType(atoms, reader: reader)

        return atoms
    }

    /// Validates that the file has a valid ftyp atom with a supported brand.
    private func validateFileType(_ atoms: [MP4Atom], reader: FileReader) throws {
        guard let ftyp = atoms.first(where: { $0.type == MP4AtomType.ftyp.rawValue }) else {
            throw MP4Error.invalidFile("Missing ftyp atom.")
        }

        let dataSize = ftyp.dataSize
        guard dataSize >= 4 else {
            throw MP4Error.invalidAtom(type: "ftyp", reason: "Payload too small.")
        }

        let brandData = try reader.read(at: ftyp.dataOffset, count: 4)
        guard let majorBrand = String(data: brandData, encoding: .isoLatin1) else {
            throw MP4Error.invalidAtom(type: "ftyp", reason: "Cannot read major brand.")
        }

        guard Self.supportedBrands.contains(majorBrand) || hasCompatibleBrand(ftyp, reader: reader)
        else {
            throw MP4Error.unsupportedFileType(majorBrand)
        }
    }

    /// Checks if any compatible brand in the ftyp atom is supported.
    private func hasCompatibleBrand(_ ftyp: MP4Atom, reader: FileReader) -> Bool {
        let dataSize = ftyp.dataSize
        // ftyp: 4 bytes major brand + 4 bytes minor version + N×4 bytes compatible brands.
        guard dataSize > 8 else { return false }

        let compatibleOffset = ftyp.dataOffset + 8
        let compatibleSize = Int(dataSize) - 8
        guard compatibleSize >= 4,
            let data = try? reader.read(at: compatibleOffset, count: compatibleSize)
        else {
            return false
        }

        for index in stride(from: 0, to: data.count - 3, by: 4) {
            let brand = String(data: data[index..<(index + 4)], encoding: .isoLatin1)
            if let brand, Self.supportedBrands.contains(brand) {
                return true
            }
        }

        return false
    }

    /// Supported MP4 major/compatible brands.
    private static let supportedBrands: Set<String> = [
        "M4A ", "M4B ", "mp41", "mp42", "isom", "iso2", "aax "
    ]
}
