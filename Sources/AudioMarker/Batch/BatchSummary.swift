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

/// Summary of a completed batch operation.
public struct BatchSummary: Sendable {

    /// All individual results.
    public let results: [BatchResult]

    /// Total number of items processed.
    public var total: Int { results.count }

    /// Number of successful items.
    public var succeeded: Int {
        results.filter(\.isSuccess).count
    }

    /// Number of failed items.
    public var failed: Int {
        results.filter { !$0.isSuccess }.count
    }

    /// All errors that occurred, paired with their source URLs.
    public var errors: [(url: URL, error: Error)] {
        results.compactMap { result in
            if case .failure(let error) = result.outcome {
                return (url: result.item.url, error: error)
            }
            return nil
        }
    }

    /// All successfully read `AudioFileInfo` results, paired with their source URLs.
    public var readResults: [(url: URL, info: AudioFileInfo)] {
        results.compactMap { result in
            if case .success(let info?) = result.outcome {
                return (url: result.item.url, info: info)
            }
            return nil
        }
    }

    /// Whether all items succeeded.
    public var allSucceeded: Bool {
        failed == 0
    }
}
