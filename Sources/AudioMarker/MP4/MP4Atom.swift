import Foundation

/// A parsed MP4/ISOBMFF atom (box) with optional children.
///
/// Atoms form a tree structure. Container atoms (e.g., `moov`, `trak`) hold
/// child atoms, while leaf atoms contain raw data.
public struct MP4Atom: Sendable, Hashable {

    /// The 4-character atom type (e.g., `"moov"`, `"trak"`).
    public let type: String

    /// Byte offset of this atom in the file (position of the size field).
    public let offset: UInt64

    /// Total size of the atom including header.
    public let size: UInt64

    /// Byte offset where the atom's data payload begins (after the header).
    public let dataOffset: UInt64

    /// Child atoms (for container atoms like `moov`, `trak`, etc.).
    public var children: [MP4Atom]

    /// Creates a parsed MP4 atom.
    /// - Parameters:
    ///   - type: The 4-character atom type.
    ///   - offset: Byte offset in the file.
    ///   - size: Total atom size including header.
    ///   - dataOffset: Offset where data payload begins.
    ///   - children: Child atoms for container types.
    public init(
        type: String,
        offset: UInt64,
        size: UInt64,
        dataOffset: UInt64,
        children: [MP4Atom] = []
    ) {
        self.type = type
        self.offset = offset
        self.size = size
        self.dataOffset = dataOffset
        self.children = children
    }

    /// The size of the data payload (total size minus header).
    public var dataSize: UInt64 {
        guard size > (dataOffset - offset) else { return 0 }
        return size - (dataOffset - offset)
    }
}

// MARK: - Search

extension MP4Atom {

    /// Finds the first child atom with the given type.
    /// - Parameter type: The atom type to search for.
    /// - Returns: The first matching child, or `nil`.
    public func child(ofType type: String) -> MP4Atom? {
        children.first { $0.type == type }
    }

    /// Finds all child atoms with the given type.
    /// - Parameter type: The atom type to search for.
    /// - Returns: All matching children.
    public func children(ofType type: String) -> [MP4Atom] {
        children.filter { $0.type == type }
    }

    /// Finds an atom by a dot-separated path (e.g., `"moov.udta.meta.ilst"`).
    ///
    /// The search starts from this atom's children. For example,
    /// calling `find(path: "udta.meta")` on a `moov` atom will
    /// look for `udta` among `moov`'s children, then `meta` among
    /// `udta`'s children.
    /// - Parameter path: Dot-separated atom type path.
    /// - Returns: The atom at the end of the path, or `nil`.
    public func find(path: String) -> MP4Atom? {
        let components = path.split(separator: ".").map(String.init)
        guard !components.isEmpty else { return nil }

        var current: MP4Atom? = self
        for component in components {
            current = current?.child(ofType: component)
            if current == nil { return nil }
        }
        return current
    }
}
