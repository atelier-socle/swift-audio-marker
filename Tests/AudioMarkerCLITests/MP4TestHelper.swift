import Foundation

@testable import AudioMarker

/// Helpers for building synthetic MP4 files in tests.
enum MP4TestHelper {

    // MARK: - Atom Building

    /// Builds a minimal atom with type and optional data payload.
    static func buildAtom(type: String, data: Data = Data()) -> Data {
        let size = UInt32(8 + data.count)
        var writer = BinaryWriter()
        writer.writeUInt32(size)
        writer.writeLatin1String(type)
        writer.writeData(data)
        return writer.data
    }

    /// Builds a container atom with child atom data.
    static func buildContainerAtom(type: String, children: [Data]) -> Data {
        var body = Data()
        for child in children {
            body.append(child)
        }
        let size = UInt32(8 + body.count)
        var writer = BinaryWriter()
        writer.writeUInt32(size)
        writer.writeLatin1String(type)
        writer.writeData(body)
        return writer.data
    }

    /// Builds a meta atom (container with 4-byte version/flags prefix).
    static func buildMetaAtom(children: [Data]) -> Data {
        var body = Data()
        // 4-byte version/flags.
        body.append(Data(repeating: 0x00, count: 4))
        for child in children {
            body.append(child)
        }
        let size = UInt32(8 + body.count)
        var writer = BinaryWriter()
        writer.writeUInt32(size)
        writer.writeLatin1String("meta")
        writer.writeData(body)
        return writer.data
    }

    /// Builds an ftyp atom with the given major brand.
    static func buildFtyp(majorBrand: String = "M4A ", minorVersion: UInt32 = 0) -> Data {
        var payload = BinaryWriter()
        payload.writeLatin1String(majorBrand)
        payload.writeUInt32(minorVersion)
        return buildAtom(type: "ftyp", data: payload.data)
    }

    /// Builds an ftyp atom with compatible brands.
    static func buildFtypWithCompatible(
        majorBrand: String,
        compatibleBrands: [String]
    ) -> Data {
        var payload = BinaryWriter()
        payload.writeLatin1String(majorBrand)
        payload.writeUInt32(0)  // minor version
        for brand in compatibleBrands {
            payload.writeLatin1String(brand)
        }
        return buildAtom(type: "ftyp", data: payload.data)
    }

    // MARK: - mvhd (Duration)

    /// Builds an mvhd atom (version 0) with the given timescale and duration.
    static func buildMVHD(
        timescale: UInt32,
        duration: UInt32
    ) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt8(0)  // version
        payload.writeRepeating(0x00, count: 3)  // flags
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt32(duration)
        // Remaining mvhd fields (rate, volume, reserved, matrix, pre-defined, next-track-id).
        payload.writeRepeating(0x00, count: 80)
        return buildAtom(type: "mvhd", data: payload.data)
    }

    /// Builds an mvhd atom (version 1) with 64-bit duration.
    static func buildMVHDv1(
        timescale: UInt32,
        duration: UInt64
    ) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt8(1)  // version
        payload.writeRepeating(0x00, count: 3)  // flags
        payload.writeUInt64(0)  // creation time
        payload.writeUInt64(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt64(duration)
        payload.writeRepeating(0x00, count: 80)
        return buildAtom(type: "mvhd", data: payload.data)
    }

    // MARK: - iTunes Metadata (ilst items)

    /// Builds an ilst item with a text data sub-atom.
    static func buildILSTTextItem(type: String, text: String) -> Data {
        let dataPayload = buildDataPayload(typeIndicator: 1, value: Data(text.utf8))
        let dataAtom = buildAtom(type: "data", data: dataPayload)
        return buildContainerAtom(type: type, children: [dataAtom])
    }

    /// Builds an ilst item with binary integer data (e.g., trkn, disk).
    static func buildILSTIntegerPair(type: String, value: UInt16, total: UInt16 = 0) -> Data {
        var valueData = BinaryWriter()
        valueData.writeUInt16(0)  // padding
        valueData.writeUInt16(value)
        valueData.writeUInt16(total)
        let dataPayload = buildDataPayload(typeIndicator: 0, value: valueData.data)
        let dataAtom = buildAtom(type: "data", data: dataPayload)
        return buildContainerAtom(type: type, children: [dataAtom])
    }

    /// Builds an ilst item with UInt16 data (e.g., tmpo).
    static func buildILSTUInt16Item(type: String, value: UInt16) -> Data {
        var valueData = BinaryWriter()
        valueData.writeUInt16(value)
        let dataPayload = buildDataPayload(typeIndicator: 21, value: valueData.data)
        let dataAtom = buildAtom(type: "data", data: dataPayload)
        return buildContainerAtom(type: type, children: [dataAtom])
    }

    /// Builds artwork data atom (covr).
    static func buildILSTArtwork(
        typeIndicator: UInt32 = 13,
        imageData: Data
    ) -> Data {
        let dataPayload = buildDataPayload(typeIndicator: typeIndicator, value: imageData)
        let dataAtom = buildAtom(type: "data", data: dataPayload)
        return buildContainerAtom(type: "covr", children: [dataAtom])
    }

    /// Builds a gnre (genre index) atom.
    static func buildGnreAtom(genreIndex: UInt16) -> Data {
        var valueData = BinaryWriter()
        valueData.writeUInt16(genreIndex)
        let dataPayload = buildDataPayload(typeIndicator: 0, value: valueData.data)
        let dataAtom = buildAtom(type: "data", data: dataPayload)
        return buildContainerAtom(type: "gnre", children: [dataAtom])
    }

    /// Builds a reverse DNS (----) atom with mean, name, and data.
    static func buildReverseDNSAtom(
        mean: String,
        name: String,
        value: String
    ) -> Data {
        // mean atom: version(4) + text
        var meanPayload = BinaryWriter()
        meanPayload.writeRepeating(0x00, count: 4)
        meanPayload.writeUTF8String(mean)
        let meanAtom = buildAtom(type: "mean", data: meanPayload.data)

        // name atom: version(4) + text
        var namePayload = BinaryWriter()
        namePayload.writeRepeating(0x00, count: 4)
        namePayload.writeUTF8String(name)
        let nameAtom = buildAtom(type: "name", data: namePayload.data)

        // data atom: type(4) + locale(4) + text
        let dataPayload = buildDataPayload(typeIndicator: 1, value: Data(value.utf8))
        let dataAtom = buildAtom(type: "data", data: dataPayload)

        return buildContainerAtom(type: "----", children: [meanAtom, nameAtom, dataAtom])
    }

    // MARK: - Nero Chapters (chpl)

    /// Builds a chpl (Nero chapters) atom.
    static func buildChplAtom(
        chapters: [(startTime100ns: UInt64, title: String)]
    ) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(1)  // version
        payload.writeUInt32(0)  // unknown/reserved
        payload.writeUInt8(UInt8(chapters.count))

        for chapter in chapters {
            payload.writeUInt64(chapter.startTime100ns)
            let titleData = Data(chapter.title.utf8)
            payload.writeUInt8(UInt8(titleData.count))
            payload.writeData(titleData)
        }

        return buildAtom(type: "chpl", data: payload.data)
    }

    // MARK: - QuickTime Chapter Track Atoms

    /// Builds an hdlr atom with the given handler type.
    static func buildHdlrAtom(handlerType: String) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt8(0)  // version
        payload.writeRepeating(0x00, count: 3)  // flags
        payload.writeUInt32(0)  // pre_defined
        payload.writeLatin1String(handlerType)
        payload.writeRepeating(0x00, count: 12)  // reserved + name
        return buildAtom(type: "hdlr", data: payload.data)
    }

    /// Builds an mdhd atom (version 0) with timescale.
    static func buildMdhdAtom(timescale: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt8(0)  // version
        payload.writeRepeating(0x00, count: 3)  // flags
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt32(0)  // duration
        payload.writeUInt32(0)  // language + pre_defined
        return buildAtom(type: "mdhd", data: payload.data)
    }

    /// Builds an stts (sample-to-time) atom.
    static func buildSttsAtom(entries: [(count: UInt32, duration: UInt32)]) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(UInt32(entries.count))
        for entry in entries {
            payload.writeUInt32(entry.count)
            payload.writeUInt32(entry.duration)
        }
        return buildAtom(type: "stts", data: payload.data)
    }

    /// Builds an stco (chunk offset) atom with 32-bit offsets.
    static func buildStcoAtom(offsets: [UInt32]) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(UInt32(offsets.count))
        for offset in offsets {
            payload.writeUInt32(offset)
        }
        return buildAtom(type: "stco", data: payload.data)
    }

    /// Builds a co64 (chunk offset) atom with 64-bit offsets.
    static func buildCo64Atom(offsets: [UInt64]) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(UInt32(offsets.count))
        for offset in offsets {
            payload.writeUInt64(offset)
        }
        return buildAtom(type: "co64", data: payload.data)
    }

    /// Builds an stsz (sample size) atom.
    static func buildStszAtom(defaultSize: UInt32, sizes: [UInt32]) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(defaultSize)
        payload.writeUInt32(UInt32(sizes.count))
        if defaultSize == 0 {
            for size in sizes {
                payload.writeUInt32(size)
            }
        }
        return buildAtom(type: "stsz", data: payload.data)
    }

    /// Builds an stsc (sample-to-chunk) atom.
    static func buildStscAtom() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(0)  // entry count
        return buildAtom(type: "stsc", data: payload.data)
    }

    // MARK: - Artwork

    /// Builds a minimal JPEG-like data blob with valid magic bytes.
    static func buildMinimalJPEG(size: Int = 64) -> Data {
        var data = Data([0xFF, 0xD8, 0xFF, 0xE0])
        if size > 4 {
            data.append(Data(repeating: 0x00, count: size - 4))
        }
        return data
    }

    // MARK: - Data Payload

    /// Builds the payload for a data atom (type indicator + locale + value).
    static func buildDataPayload(typeIndicator: UInt32, value: Data) -> Data {
        var writer = BinaryWriter()
        writer.writeUInt32(typeIndicator)
        writer.writeUInt32(0)  // locale
        writer.writeData(value)
        return writer.data
    }

}

// MARK: - Complete File Builders

extension MP4TestHelper {

    /// Builds a minimal valid MP4 file with ftyp + moov (containing mvhd).
    static func buildMinimalMP4(
        majorBrand: String = "M4A ",
        timescale: UInt32 = 44100,
        duration: UInt32 = 441_000
    ) -> Data {
        let ftyp = buildFtyp(majorBrand: majorBrand)
        let mvhd = buildMVHD(timescale: timescale, duration: duration)
        let moov = buildContainerAtom(type: "moov", children: [mvhd])
        var file = Data()
        file.append(ftyp)
        file.append(moov)
        return file
    }

    /// Builds an MP4 file with metadata in the ilst atom.
    static func buildMP4WithMetadata(ilstItems: [Data]) -> Data {
        let ftyp = buildFtyp()
        let mvhd = buildMVHD(timescale: 44100, duration: 441_000)
        let ilst = buildContainerAtom(type: "ilst", children: ilstItems)
        let meta = buildMetaAtom(children: [ilst])
        let udta = buildContainerAtom(type: "udta", children: [meta])
        let moov = buildContainerAtom(type: "moov", children: [mvhd, udta])
        var file = Data()
        file.append(ftyp)
        file.append(moov)
        return file
    }

    /// Builds an MP4 file with Nero chapters.
    static func buildMP4WithNeroChapters(
        chapters: [(startTime100ns: UInt64, title: String)]
    ) -> Data {
        let ftyp = buildFtyp()
        let mvhd = buildMVHD(timescale: 44100, duration: 441_000)
        let chpl = buildChplAtom(chapters: chapters)
        let udta = buildContainerAtom(type: "udta", children: [chpl])
        let moov = buildContainerAtom(type: "moov", children: [mvhd, udta])
        var file = Data()
        file.append(ftyp)
        file.append(moov)
        return file
    }

    /// Builds an MP4 file with a QuickTime text chapter track.
    static func buildMP4WithQuickTimeChapters(
        titles: [String],
        timescale: UInt32 = 1000,
        sampleDuration: UInt32 = 10_000
    ) -> Data {
        // Build chapter text samples.
        var sampleData: [Data] = []
        for text in titles {
            var writer = BinaryWriter()
            let textBytes = Data(text.utf8)
            writer.writeUInt16(UInt16(textBytes.count))
            writer.writeData(textBytes)
            sampleData.append(writer.data)
        }

        let sampleSizes = sampleData.map { UInt32($0.count) }
        let sampleCount = UInt32(titles.count)

        // Build track atoms with placeholder offsets.
        let hdlr = buildHdlrAtom(handlerType: "text")
        let mdhd = buildMdhdAtom(timescale: timescale)
        let stts = buildSttsAtom(entries: [(count: sampleCount, duration: sampleDuration)])
        let stco = buildStcoAtom(offsets: [UInt32](repeating: 0, count: titles.count))
        let stsz = buildStszAtom(defaultSize: 0, sizes: sampleSizes)
        let stsc = buildStscAtom()

        let stbl = buildContainerAtom(type: "stbl", children: [stts, stco, stsz, stsc])
        let minf = buildContainerAtom(type: "minf", children: [stbl])
        let mdia = buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minf])
        let trak = buildContainerAtom(type: "trak", children: [mdia])

        let ftyp = buildFtyp()
        let totalDuration = sampleCount * sampleDuration
        let mvhd = buildMVHD(timescale: timescale, duration: totalDuration)
        let moov = buildContainerAtom(type: "moov", children: [mvhd, trak])

        // Calculate actual sample offsets.
        let sampleDataStart = UInt32(ftyp.count + moov.count)
        var actualOffsets: [UInt32] = []
        var offset = sampleDataStart
        for sample in sampleData {
            actualOffsets.append(offset)
            offset += UInt32(sample.count)
        }

        // Rebuild with correct offsets.
        let stcoFixed = buildStcoAtom(offsets: actualOffsets)
        let stblFixed = buildContainerAtom(type: "stbl", children: [stts, stcoFixed, stsz, stsc])
        let minfFixed = buildContainerAtom(type: "minf", children: [stblFixed])
        let mdiaFixed = buildContainerAtom(type: "mdia", children: [mdhd, hdlr, minfFixed])
        let trakFixed = buildContainerAtom(type: "trak", children: [mdiaFixed])
        let moovFixed = buildContainerAtom(type: "moov", children: [mvhd, trakFixed])

        var file = Data()
        file.append(ftyp)
        file.append(moovFixed)
        for sample in sampleData {
            file.append(sample)
        }
        return file
    }

    // MARK: - File Helpers

    /// Creates a temporary file with the given data.
    static func createTempFile(data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        try data.write(to: url)
        return url
    }
}
