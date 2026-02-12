import ArgumentParser
import AudioMarker
import Foundation

/// Validates an audio file's metadata and chapters against built-in rules.
struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Validate metadata and chapters in an audio file."
    )

    @Argument(help: "Path to the audio file.")
    var file: String

    @Option(name: .long, help: "Output format: text or json.")
    var format: String = "text"

    mutating func run() throws {
        let fileURL = CLIHelpers.resolveURL(file)
        let engine = AudioMarkerEngine()
        let info = try engine.read(from: fileURL)

        let validator = AudioValidator()
        let result = validator.validate(info)

        if format == "json" {
            printJSON(result, url: fileURL)
        } else {
            printText(result, rules: validator.rules, info: info, url: fileURL)
        }

        if !result.isValid {
            throw ExitCode(1)
        }
    }
}

// MARK: - Text Output

extension Validate {

    private func printText(
        _ result: ValidationResult,
        rules: [any ValidationRule],
        info: AudioFileInfo,
        url: URL
    ) {
        print("Validating: \(url.lastPathComponent)")

        for rule in rules {
            let ruleIssues = rule.validate(info)
            let errors = ruleIssues.filter { $0.severity == .error }
            let warnings = ruleIssues.filter { $0.severity == .warning }

            if !errors.isEmpty {
                for issue in errors {
                    let context = issue.context.map { " (\($0))" } ?? ""
                    print("\u{2717} \(rule.name) \u{2014} \(issue.message)\(context)")
                }
            } else if !warnings.isEmpty {
                for issue in warnings {
                    let context = issue.context.map { " (\($0))" } ?? ""
                    print("\u{26A0} \(rule.name) \u{2014} \(issue.message)\(context)")
                }
            } else {
                print("\u{2713} \(rule.name)")
            }
        }

        print()
        let errorCount = result.errors.count
        let warningCount = result.warnings.count
        print("Result: \(errorCount) error(s), \(warningCount) warning(s)")
    }
}

// MARK: - JSON Output

extension Validate {

    private func printJSON(_ result: ValidationResult, url: URL) {
        var dict: [String: Any] = [
            "file": url.lastPathComponent,
            "valid": result.isValid
        ]

        dict["errors"] = result.errors.map { issue in
            var entry: [String: String] = ["message": issue.message]
            if let context = issue.context { entry["context"] = context }
            return entry
        }

        dict["warnings"] = result.warnings.map { issue in
            var entry: [String: String] = ["message": issue.message]
            if let context = issue.context { entry["context"] = context }
            return entry
        }

        if let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            print(String(data: data, encoding: .utf8) ?? "{}")
        }
    }
}
