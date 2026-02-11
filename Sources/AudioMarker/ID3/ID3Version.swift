// swift-format-ignore: AlwaysUseLowerCamelCase
/// Supported ID3v2 tag versions.
public enum ID3Version: Sendable, Hashable {

    /// ID3v2.3 (most widely used).
    case v2_3

    /// ID3v2.4 (latest revision).
    case v2_4

    /// The major version number (3 or 4).
    public var majorVersion: UInt8 {
        switch self {
        case .v2_3: return 3
        case .v2_4: return 4
        }
    }

    /// The full version string (e.g., `"ID3v2.3"`, `"ID3v2.4"`).
    public var displayName: String {
        switch self {
        case .v2_3: return "ID3v2.3"
        case .v2_4: return "ID3v2.4"
        }
    }
}
