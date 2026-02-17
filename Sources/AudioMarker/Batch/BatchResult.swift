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

/// The result of processing a single batch item.
public struct BatchResult: Sendable {

    /// The original item.
    public let item: BatchItem

    /// The outcome: success with optional data, or failure.
    public let outcome: Outcome

    /// Possible outcomes for a batch item.
    public enum Outcome: Sendable {
        /// The operation succeeded with optional file info (present for reads).
        case success(AudioFileInfo?)
        /// The operation failed with an error.
        case failure(Error)
    }

    /// Whether the operation succeeded.
    public var isSuccess: Bool {
        if case .success = outcome { return true }
        return false
    }

    /// The `AudioFileInfo` if the operation was a successful read.
    public var info: AudioFileInfo? {
        if case .success(let fileInfo) = outcome { return fileInfo }
        return nil
    }

    /// The error if the operation failed.
    public var error: Error? {
        if case .failure(let error) = outcome { return error }
        return nil
    }
}
