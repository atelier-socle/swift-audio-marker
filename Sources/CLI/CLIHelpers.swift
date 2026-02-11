import ArgumentParser
import AudioMarker
import Foundation

/// Shared helpers for CLI commands.
enum CLIHelpers {

    /// Supported audio file extensions for directory scanning.
    static let audioExtensions: Set<String> = ["mp3", "m4a", "m4b"]

    /// Resolves a file path string to a URL.
    /// - Parameter path: The path string, which may be relative, absolute, or tilde-prefixed.
    /// - Returns: A file URL.
    static func resolveURL(_ path: String) -> URL {
        let expanded = NSString(string: path).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }
        let cwd = FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: cwd).appendingPathComponent(expanded)
    }

    /// Parses an `ExportFormat` from a CLI string.
    ///
    /// Accepts: `"podlove-json"`, `"podlove-xml"`, `"mp4chaps"`, `"ffmetadata"`,
    /// `"markdown"`, `"lrc"`, `"ttml"`.
    /// - Parameter string: The format string.
    /// - Returns: The matching export format.
    /// - Throws: If the string does not match a known format.
    static func parseExportFormat(_ string: String) throws -> ExportFormat {
        switch string.lowercased() {
        case "podlove-json": return .podloveJSON
        case "podlove-xml": return .podloveXML
        case "mp4chaps": return .mp4chaps
        case "ffmetadata": return .ffmetadata
        case "markdown": return .markdown
        case "lrc": return .lrc
        case "ttml": return .ttml
        default:
            throw ValidationError(
                "Unknown format \"\(string)\". "
                    + "Expected: podlove-json, podlove-xml, mp4chaps, ffmetadata, markdown, lrc, ttml."
            )
        }
    }

    /// Scans a directory for audio files.
    /// - Parameters:
    ///   - directory: The directory path.
    ///   - recursive: Whether to include subdirectories.
    /// - Returns: Array of audio file URLs.
    /// - Throws: If the directory does not exist or cannot be read.
    static func findAudioFiles(in directory: String, recursive: Bool) throws -> [URL] {
        let dirURL = resolveURL(directory)
        let fm = FileManager.default

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue else {
            throw ValidationError("Directory not found: \"\(directory)\".")
        }

        var results: [URL] = []

        if recursive {
            guard
                let enumerator = fm.enumerator(
                    at: dirURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
            else {
                return []
            }
            for case let fileURL as URL in enumerator
            where audioExtensions.contains(fileURL.pathExtension.lowercased()) {
                results.append(fileURL)
            }
        } else {
            let contents = try fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            results = contents.filter { audioExtensions.contains($0.pathExtension.lowercased()) }
        }

        return results.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Formats a file size for display.
    /// - Parameter bytes: The size in bytes.
    /// - Returns: A human-readable string like `"5.2 MB"`.
    static func formatFileSize(_ bytes: UInt64) -> String {
        let units = ["bytes", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1000 && unitIndex < units.count - 1 {
            value /= 1000
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(bytes) bytes"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }

    /// Prints an error message to stderr and exits with code 1.
    /// - Parameter message: The error message.
    static func exitWithError(_ message: String) -> Never {
        FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
        _Exit(1)
    }
}
