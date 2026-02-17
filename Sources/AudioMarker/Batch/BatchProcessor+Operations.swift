// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


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
