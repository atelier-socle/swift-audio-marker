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

/// A single item in a batch operation.
public struct BatchItem: Sendable, Hashable {

    /// The file URL to process.
    public let url: URL

    /// The operation to perform.
    public let operation: BatchOperation

    /// Creates a batch item.
    /// - Parameters:
    ///   - url: The file URL to process.
    ///   - operation: The operation to perform on the file.
    public init(url: URL, operation: BatchOperation) {
        self.url = url
        self.operation = operation
    }
}
