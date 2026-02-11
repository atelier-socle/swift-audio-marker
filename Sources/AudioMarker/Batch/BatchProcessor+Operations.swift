import Foundation

extension BatchProcessor {

    /// Processes a single batch item.
    /// - Parameter item: The item to process.
    /// - Returns: The result with success or failure outcome.
    func processItem(_ item: BatchItem) -> BatchResult {
        do {
            switch item.operation {
            case .read:
                let info = try engine.read(from: item.url)
                return BatchResult(item: item, outcome: .success(info))
            case .write(let info):
                try engine.write(info, to: item.url)
                return BatchResult(item: item, outcome: .success(nil))
            case .strip:
                try engine.strip(from: item.url)
                return BatchResult(item: item, outcome: .success(nil))
            case .exportChapters(let format, let outputURL):
                let exported = try engine.exportChapters(from: item.url, format: format)
                try exported.write(to: outputURL, atomically: true, encoding: .utf8)
                return BatchResult(item: item, outcome: .success(nil))
            case .importChapters(let string, let format):
                try engine.importChapters(from: string, format: format, to: item.url)
                return BatchResult(item: item, outcome: .success(nil))
            }
        } catch {
            return BatchResult(item: item, outcome: .failure(error))
        }
    }
}
