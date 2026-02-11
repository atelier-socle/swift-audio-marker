/// Known MP4/ISOBMFF atom types.
///
/// iTunes metadata atoms (e.g., `©nam`, `©ART`) use special characters
/// and are matched by raw string comparison rather than this enum.
public enum MP4AtomType: String, Sendable, Hashable, CaseIterable {

    // MARK: - Top-Level

    /// File type and compatibility.
    case ftyp

    /// Movie container (holds all metadata and track structure).
    case moov

    /// Media data (audio samples — never load in memory).
    case mdat

    /// Free space.
    case free

    /// Skip (alias for free space).
    case skip

    // MARK: - Movie Structure

    /// Movie header (duration, timescale).
    case mvhd

    /// Track container.
    case trak

    /// Track header.
    case tkhd

    /// Media container.
    case mdia

    /// Media header (timescale, duration).
    case mdhd

    /// Handler reference (identifies track type).
    case hdlr

    /// Media information container.
    case minf

    /// Sample table container.
    case stbl

    /// Chunk offset table (32-bit offsets).
    case stco

    /// Chunk offset table (64-bit offsets).
    case co64

    /// Sample-to-time mapping.
    case stts

    /// Sample size table.
    case stsz

    /// Sample-to-chunk mapping.
    case stsc

    // MARK: - User Data & Metadata

    /// User data container.
    case udta

    /// Metadata container.
    case meta

    /// iTunes metadata list.
    case ilst

    // MARK: - Chapters

    /// Nero chapter list.
    case chpl

    // MARK: - Data

    /// Data atom (used inside ilst items).
    case data

    /// Whether this atom type is a known container that has child atoms.
    public var isContainer: Bool {
        switch self {
        case .moov, .trak, .mdia, .minf, .stbl, .udta, .ilst:
            return true
        default:
            return false
        }
    }
}
