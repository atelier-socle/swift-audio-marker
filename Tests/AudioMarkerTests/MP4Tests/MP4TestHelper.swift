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

// MARK: - tx3g Sample Builders

extension MP4TestHelper {

    /// Builds a tx3g text sample with an optional href atom.
    static func buildTx3gSample(title: String, url: String? = nil) -> Data {
        let textBytes = Data(title.utf8)
        var writer = BinaryWriter()
        writer.writeUInt16(UInt16(textBytes.count))
        writer.writeData(textBytes)

        if let urlString = url {
            let urlBytes = Data(urlString.utf8)
            let hrefPayloadSize = 2 + 2 + 1 + urlBytes.count + 2
            writer.writeUInt32(UInt32(8 + hrefPayloadSize))
            writer.writeLatin1String("href")
            writer.writeUInt16(0x0005)
            writer.writeUInt16(UInt16(title.count))
            writer.writeUInt8(UInt8(min(urlBytes.count, 255)))
            writer.writeData(urlBytes)
            writer.writeUInt16(0x0000)
        }

        return writer.data
    }

    /// Builds a tkhd atom (version 0) with track ID and flags.
    static func buildTkhdAtom(trackID: UInt32, flags: UInt32 = 0) -> Data {
        var payload = BinaryWriter(capacity: 84)
        payload.writeUInt8(0)  // version
        payload.writeUInt8(UInt8((flags >> 16) & 0xFF))
        payload.writeUInt8(UInt8((flags >> 8) & 0xFF))
        payload.writeUInt8(UInt8(flags & 0xFF))
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(trackID)
        payload.writeUInt32(0)  // reserved
        payload.writeUInt32(441_000)  // duration
        payload.writeRepeating(0x00, count: 60)  // remaining fields
        return buildAtom(type: "tkhd", data: payload.data)
    }

    /// Builds a video stsd atom for JPEG or PNG.
    static func buildVideoStsd(format: String = "jpeg", width: UInt16 = 300, height: UInt16 = 300) -> Data {
        var desc = BinaryWriter(capacity: 86)
        desc.writeUInt32(86)
        desc.writeLatin1String(format)
        desc.writeRepeating(0x00, count: 6)
        desc.writeUInt16(1)
        desc.writeUInt16(0)
        desc.writeUInt16(0)
        desc.writeRepeating(0x00, count: 4)
        desc.writeUInt32(0)
        desc.writeUInt32(512)
        desc.writeUInt16(width)
        desc.writeUInt16(height)
        desc.writeUInt32(0x0048_0000)
        desc.writeUInt32(0x0048_0000)
        desc.writeUInt32(0)
        desc.writeUInt16(1)
        desc.writeRepeating(0x00, count: 32)
        desc.writeUInt16(24)
        desc.writeUInt16(0xFFFF)

        var stsdPayload = BinaryWriter(capacity: 8 + desc.count)
        stsdPayload.writeUInt32(0)
        stsdPayload.writeUInt32(1)
        stsdPayload.writeData(desc.data)
        return buildAtom(type: "stsd", data: stsdPayload.data)
    }

    /// Builds a tref/chap atom referencing the given track IDs.
    static func buildTrefChap(trackIDs: [UInt32]) -> Data {
        var chapPayload = BinaryWriter()
        for id in trackIDs {
            chapPayload.writeUInt32(id)
        }
        let chapAtom = buildAtom(type: "chap", data: chapPayload.data)
        return buildContainerAtom(type: "tref", children: [chapAtom])
    }

    /// Builds a minimal synthetic JPEG image.
    static func buildMinimalJPEG(size: Int = 64) -> Data {
        var data = Data([0xFF, 0xD8, 0xFF, 0xE0])
        data.append(Data(repeating: 0xAB, count: max(0, size - 4)))
        return data
    }

    /// Builds a minimal synthetic PNG image with width/height in the IHDR chunk.
    static func buildMinimalPNG(width: UInt32 = 300, height: UInt32 = 300, size: Int = 64) -> Data {
        // PNG signature.
        var data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        // IHDR chunk: length(4) + "IHDR"(4) + width(4) + height(4) + ...
        var ihdr = BinaryWriter()
        ihdr.writeUInt32(13)  // IHDR data length
        ihdr.writeLatin1String("IHDR")
        ihdr.writeUInt32(width)
        ihdr.writeUInt32(height)
        ihdr.writeUInt8(8)  // bit depth
        ihdr.writeUInt8(2)  // color type (RGB)
        ihdr.writeRepeating(0x00, count: 3)  // compression, filter, interlace
        ihdr.writeUInt32(0)  // CRC placeholder
        data.append(ihdr.data)
        // Pad to requested size.
        if data.count < size {
            data.append(Data(repeating: 0x00, count: size - data.count))
        }
        return data
    }

}
