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


/// Progress update for a batch operation.
public struct BatchProgress: Sendable {

    /// Total number of items in the batch.
    public let total: Int

    /// Number of items completed so far.
    public let completed: Int

    /// The most recently completed item's result.
    public let latestResult: BatchResult?

    /// Progress as a fraction (0.0 to 1.0).
    public var fraction: Double {
        total == 0 ? 1.0 : Double(completed) / Double(total)
    }

    /// Whether all items have been processed.
    public var isFinished: Bool {
        completed >= total
    }
}
