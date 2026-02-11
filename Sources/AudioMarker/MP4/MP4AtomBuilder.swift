import Foundation

/// Builds raw MP4/ISOBMFF atom data from structured values.
///
/// Constructs individual atoms, container atoms, and iTunes metadata
/// atoms using ``BinaryWriter`` for byte-level encoding.
public struct MP4AtomBuilder: Sendable {

    /// Creates an MP4 atom builder.
    public init() {}

    // MARK: - Generic Atoms

    /// Builds a generic atom (header + data).
    /// - Parameters:
    ///   - type: 4-character atom type.
    ///   - data: Atom payload data.
    /// - Returns: Complete atom bytes (size + type + data).
    public func buildAtom(type: String, data: Data) -> Data {
        var writer = BinaryWriter(capacity: 8 + data.count)
        writer.writeUInt32(UInt32(8 + data.count))
        writer.writeLatin1String(type)
        writer.writeData(data)
        return writer.data
    }

    /// Builds a container atom with children.
    /// - Parameters:
    ///   - type: 4-character atom type.
    ///   - children: Child atom data to concatenate.
    /// - Returns: Complete container atom bytes.
    public func buildContainerAtom(type: String, children: [Data]) -> Data {
        var bodySize = 0
        for child in children {
            bodySize += child.count
        }
        var writer = BinaryWriter(capacity: 8 + bodySize)
        writer.writeUInt32(UInt32(8 + bodySize))
        writer.writeLatin1String(type)
        for child in children {
            writer.writeData(child)
        }
        return writer.data
    }

    // MARK: - iTunes Metadata Atoms

    /// Builds a "data" atom (iTunes metadata value atom).
    ///
    /// The data atom format is: size(4) + "data"(4) + typeIndicator(4) + locale(4) + value.
    /// - Parameters:
    ///   - typeIndicator: Data type (1=UTF-8, 13=JPEG, 14=PNG, 21=integer).
    ///   - value: The value data.
    /// - Returns: Complete data atom bytes.
    public func buildDataAtom(typeIndicator: UInt32, value: Data) -> Data {
        var payload = BinaryWriter(capacity: 8 + value.count)
        payload.writeUInt32(typeIndicator)
        payload.writeUInt32(0)  // locale
        payload.writeData(value)
        return buildAtom(type: "data", data: payload.data)
    }

    /// Builds an iTunes metadata item atom (e.g., \u{00A9}nam, \u{00A9}ART).
    ///
    /// The item is a container with a single "data" child atom.
    /// - Parameters:
    ///   - type: Atom type (e.g., "\u{00A9}nam", "covr").
    ///   - typeIndicator: Data type indicator.
    ///   - value: Value data.
    /// - Returns: Complete metadata item atom bytes.
    public func buildMetadataItem(type: String, typeIndicator: UInt32, value: Data) -> Data {
        let dataAtom = buildDataAtom(typeIndicator: typeIndicator, value: value)
        return buildContainerAtom(type: type, children: [dataAtom])
    }

    // MARK: - Meta Atom

    /// Builds a meta atom (container with 4-byte version/flags prefix).
    /// - Parameter children: Child atom data to include.
    /// - Returns: Complete meta atom bytes.
    public func buildMetaAtom(children: [Data]) -> Data {
        var bodySize = 4  // version/flags prefix
        for child in children {
            bodySize += child.count
        }
        var writer = BinaryWriter(capacity: 8 + bodySize)
        writer.writeUInt32(UInt32(8 + bodySize))
        writer.writeLatin1String("meta")
        writer.writeUInt32(0)  // version + flags
        for child in children {
            writer.writeData(child)
        }
        return writer.data
    }
}
