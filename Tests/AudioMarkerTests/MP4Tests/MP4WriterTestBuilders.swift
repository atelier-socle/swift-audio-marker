import Foundation

@testable import AudioMarker

// MARK: - Test File Builders

extension MP4WriterTests {

    /// Creates a test MP4 with ftyp + moov + mdat.
    func createTestMP4WithMdat(
        mdatContent: Data = Data(repeating: 0xFF, count: 64)
    ) throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)

        // Build stco with a placeholder offset pointing into mdat.
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
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trak])

        // Build mdat.
        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        // Calculate actual stco offset.
        let mdatDataOffset = UInt32(ftyp.count + moov.count + 8)

        // Rebuild with correct offset.
        let stcoFixed = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stblFixed = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = MP4TestHelper.buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trakFixed])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        file.append(mdatWriter.data)

        return try MP4TestHelper.createTempFile(data: file)
    }

    /// Creates a test MP4 with metadata and mdat.
    func createTestMP4WithMetadataAndMdat() throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)

        let mdatContent = Data(repeating: 0xFF, count: 64)

        let titleItem = MP4TestHelper.buildILSTTextItem(
            type: "\u{00A9}nam", text: "Original Title")
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: [titleItem])
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])

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
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, trak, udta])

        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        // Calculate actual stco offset.
        let mdatDataOffset = UInt32(ftyp.count + moov.count + 8)

        // Rebuild with correct offset.
        let stcoFixed = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stblFixed = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = MP4TestHelper.buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, trakFixed, udta])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        file.append(mdatWriter.data)

        return try MP4TestHelper.createTempFile(data: file)
    }

    /// Creates a test MP4 with ftyp + moov(metadata + Nero chapters) + mdat.
    func createTestMP4WithMetadataChaptersAndMdat() throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let mdatContent = Data(repeating: 0xFF, count: 64)

        let titleItem = MP4TestHelper.buildILSTTextItem(
            type: "\u{00A9}nam", text: "Album Title")
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: [titleItem])
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let chpl = MP4TestHelper.buildChplAtom(chapters: [
            (startTime100ns: 0, title: "First Chapter"),
            (startTime100ns: 300_000_000_00, title: "Second Chapter")
        ])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta, chpl])

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
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, trak, udta])

        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        let mdatDataOffset = UInt32(ftyp.count + moov.count + 8)

        let stcoFixed = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stblFixed = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = MP4TestHelper.buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, trakFixed, udta])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        file.append(mdatWriter.data)

        return try MP4TestHelper.createTempFile(data: file)
    }

    /// Creates a test MP4 with ftyp + mdat + moov layout (mdat first).
    func createTestMP4MdatFirst() throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let mdatContent = Data(repeating: 0xAA, count: 64)

        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        // stco offset points to mdat data (after ftyp + mdat header).
        let mdatDataOffset = UInt32(ftyp.count + 8)
        let stco = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stsz = MP4TestHelper.buildStszAtom(
            defaultSize: UInt32(mdatContent.count), sizes: [])
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 441_000)])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 44100)
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trak])

        // Layout: ftyp | mdat | moov.
        var file = Data()
        file.append(ftyp)
        file.append(mdatWriter.data)
        file.append(moov)
        return try MP4TestHelper.createTempFile(data: file)
    }

    /// Creates a test MP4 with ftyp + moov + free(256) + mdat.
    func createTestMP4WithFreeBeforeMdat(
        mdatContent: Data = Data(repeating: 0xFF, count: 64)
    ) throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let freeAtom = MP4TestHelper.buildAtom(type: "free", data: Data(repeating: 0, count: 256))

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
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trak])

        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        // stco offset: ftyp + moov + free + mdat header (8 bytes).
        let mdatDataOffset = UInt32(ftyp.count + moov.count + freeAtom.count + 8)

        let stcoFixed = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stblFixed = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = MP4TestHelper.buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = MP4TestHelper.buildContainerAtom(type: "moov", children: [mvhd, trakFixed])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        file.append(freeAtom)
        file.append(mdatWriter.data)

        return try MP4TestHelper.createTempFile(data: file)
    }

    /// Creates a test MP4 with ftyp + moov(metadata) + free(256) + mdat.
    func createTestMP4WithFreeBeforeMdatAndMetadata(
        mdatContent: Data = Data(repeating: 0xFF, count: 64)
    ) throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let freeAtom = MP4TestHelper.buildAtom(type: "free", data: Data(repeating: 0, count: 256))

        let titleItem = MP4TestHelper.buildILSTTextItem(
            type: "\u{00A9}nam", text: "Gap Title")
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: [titleItem])
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])

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
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, trak, udta])

        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        let mdatDataOffset = UInt32(ftyp.count + moov.count + freeAtom.count + 8)

        let stcoFixed = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stblFixed = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = MP4TestHelper.buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, trakFixed, udta])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        file.append(freeAtom)
        file.append(mdatWriter.data)

        return try MP4TestHelper.createTempFile(data: file)
    }

    /// Checks if the moov atom contains at least one text track.
    func hasTextTrackInMoov(at url: URL) throws -> Bool {
        try countTextTracksInMoov(at: url) > 0
    }

    /// Counts the number of text tracks (handler "text") in the moov atom.
    func countTextTracksInMoov(at url: URL) throws -> Int {
        let fileReader = try FileReader(url: url)
        defer { fileReader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: fileReader)
        guard let moov = atoms.first(where: { $0.type == "moov" }) else {
            return 0
        }

        var count = 0
        for trak in moov.children(ofType: "trak") {
            if let hdlr = trak.find(path: "mdia.hdlr"),
                let data = try? fileReader.read(at: hdlr.dataOffset, count: 12),
                String(data: data[8..<12], encoding: .isoLatin1) == "text"
            {
                count += 1
            }
        }
        return count
    }

    /// Counts text or subtitle tracks (handler "text" or "sbtl") in the moov atom.
    func countTextOrSbtlTracksInMoov(at url: URL) throws -> Int {
        let fileReader = try FileReader(url: url)
        defer { fileReader.close() }

        let parser = MP4AtomParser()
        let atoms = try parser.parseAtoms(from: fileReader)
        guard let moov = atoms.first(where: { $0.type == "moov" }) else {
            return 0
        }

        var count = 0
        for trak in moov.children(ofType: "trak") {
            if let hdlr = trak.find(path: "mdia.hdlr"),
                let data = try? fileReader.read(at: hdlr.dataOffset, count: 12)
            {
                let handler = String(data: data[8..<12], encoding: .isoLatin1)
                if handler == "text" || handler == "sbtl" {
                    count += 1
                }
            }
        }
        return count
    }

    /// Creates a test MP4 with an sbtl (subtitle) text track and no tref/chap reference.
    func createTestMP4WithSbtlTrack() throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let mdatContent = Data(repeating: 0xFF, count: 64)

        // Build audio track.
        let stco = MP4TestHelper.buildStcoAtom(offsets: [0])
        let stsz = MP4TestHelper.buildStszAtom(
            defaultSize: UInt32(mdatContent.count), sizes: [])
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 441_000)])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 44100)
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])

        // Audio trak with tkhd (track ID 1).
        let audioTkhd = buildTkhd(trackID: 1)
        let audioTrak = MP4TestHelper.buildContainerAtom(
            type: "trak", children: [audioTkhd, mdia])

        // Build sbtl text track (track ID 2, no tref/chap reference).
        let sbtlHdlr = MP4TestHelper.buildHdlrAtom(handlerType: "sbtl")
        let sbtlMdhd = MP4TestHelper.buildMdhdAtom(timescale: 1000)
        let sbtlStts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 10_000)])
        let sbtlStco = MP4TestHelper.buildStcoAtom(offsets: [0])
        let sbtlStsz = MP4TestHelper.buildStszAtom(defaultSize: 10, sizes: [])
        let sbtlStsc = MP4TestHelper.buildStscAtom()
        let sbtlStbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [sbtlStts, sbtlStco, sbtlStsz, sbtlStsc])
        let sbtlMinf = MP4TestHelper.buildContainerAtom(type: "minf", children: [sbtlStbl])
        let sbtlMdia = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [sbtlMdhd, sbtlHdlr, sbtlMinf])
        let sbtlTkhd = buildTkhd(trackID: 2)
        let sbtlTrak = MP4TestHelper.buildContainerAtom(
            type: "trak", children: [sbtlTkhd, sbtlMdia])

        let moov = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, audioTrak, sbtlTrak])

        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        // Rebuild with correct stco offset.
        let mdatDataOffset = UInt32(ftyp.count + moov.count + 8)
        let stcoFixed = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stblFixed = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = MP4TestHelper.buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = MP4TestHelper.buildContainerAtom(
            type: "mdia", children: [mdhd, hdlr, minfFixed])
        let audioTrakFixed = MP4TestHelper.buildContainerAtom(
            type: "trak", children: [audioTkhd, mdiaFixed])
        let moovFixed = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, audioTrakFixed, sbtlTrak])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        file.append(mdatWriter.data)

        return try MP4TestHelper.createTempFile(data: file)
    }

    /// Builds a minimal tkhd atom (version 0) with the given track ID.
    private func buildTkhd(trackID: UInt32) -> Data {
        var payload = BinaryWriter(capacity: 84)
        payload.writeUInt8(0)  // version
        payload.writeRepeating(0x00, count: 3)  // flags
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(trackID)
        payload.writeUInt32(0)  // reserved
        payload.writeUInt32(441_000)  // duration
        payload.writeRepeating(0x00, count: 60)  // remaining fields
        return MP4TestHelper.buildAtom(type: "tkhd", data: payload.data)
    }

    /// Finds the first stco offset value inside a moov atom.
    func findStcoFirstOffset(in moov: MP4Atom, reader: FileReader) throws -> UInt64 {
        let moovData = try reader.read(at: moov.offset, count: Int(moov.size))

        // Walk moov data looking for "stco" atom.
        var index = 8
        while index + 8 <= moovData.count {
            let atomSize = Int(readUInt32BE(moovData, at: index))
            let atomType =
                String(
                    bytes: moovData[index + 4..<index + 8], encoding: .ascii) ?? ""

            if atomType == "stco" && atomSize >= 16 {
                // stco: 4-size, 4-type, 1-version, 3-flags, 4-count, then 4-byte offsets.
                let offsetStart = index + 12 + 4
                guard offsetStart + 4 <= moovData.count else { break }
                return UInt64(readUInt32BE(moovData, at: offsetStart))
            }

            guard atomSize >= 8 else { break }

            // Descend into container atoms.
            let containers: Set<String> = [
                "moov", "trak", "mdia", "minf", "stbl", "udta"
            ]
            if containers.contains(atomType) {
                index += 8
            } else {
                index += atomSize
            }
        }

        throw MP4Error.atomNotFound("stco")
    }

    /// Reads a big-endian UInt32 from data at the given offset (alignment-safe).
    func readUInt32BE(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    /// Creates a test MP4 with mdat-first layout and metadata.
    func createTestMP4MdatFirstWithMetadata() throws -> URL {
        let ftyp = MP4TestHelper.buildFtyp()
        let mvhd = MP4TestHelper.buildMVHD(timescale: 44100, duration: 441_000)
        let mdatContent = Data(repeating: 0xBB, count: 64)

        var mdatWriter = BinaryWriter()
        mdatWriter.writeUInt32(UInt32(8 + mdatContent.count))
        mdatWriter.writeLatin1String("mdat")
        mdatWriter.writeData(mdatContent)

        let titleItem = MP4TestHelper.buildILSTTextItem(
            type: "\u{00A9}nam", text: "Original")
        let ilst = MP4TestHelper.buildContainerAtom(type: "ilst", children: [titleItem])
        let meta = MP4TestHelper.buildMetaAtom(children: [ilst])
        let udta = MP4TestHelper.buildContainerAtom(type: "udta", children: [meta])

        let mdatDataOffset = UInt32(ftyp.count + 8)
        let stco = MP4TestHelper.buildStcoAtom(offsets: [mdatDataOffset])
        let stsz = MP4TestHelper.buildStszAtom(
            defaultSize: UInt32(mdatContent.count), sizes: [])
        let stts = MP4TestHelper.buildSttsAtom(entries: [(count: 1, duration: 441_000)])
        let stsc = MP4TestHelper.buildStscAtom()
        let stbl = MP4TestHelper.buildContainerAtom(
            type: "stbl", children: [stts, stco, stsz, stsc])
        let hdlr = MP4TestHelper.buildHdlrAtom(handlerType: "soun")
        let mdhd = MP4TestHelper.buildMdhdAtom(timescale: 44100)
        let minf = MP4TestHelper.buildContainerAtom(type: "minf", children: [stbl])
        let mdia = MP4TestHelper.buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = MP4TestHelper.buildContainerAtom(type: "trak", children: [mdia])
        let moov = MP4TestHelper.buildContainerAtom(
            type: "moov", children: [mvhd, trak, udta])

        var file = Data()
        file.append(ftyp)
        file.append(mdatWriter.data)
        file.append(moov)
        return try MP4TestHelper.createTempFile(data: file)
    }
}
