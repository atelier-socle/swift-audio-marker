/// Constants for streaming I/O operations.
public enum StreamingConstants {

    /// Default buffer size for chunk-based I/O (64 KB).
    public static let defaultBufferSize: Int = 65_536

    /// Minimum allowed buffer size (4 KB).
    public static let minimumBufferSize: Int = 4_096

    /// Maximum allowed buffer size (1 MB).
    public static let maximumBufferSize: Int = 1_048_576
}
