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


/// A rule that validates audio file data.
public protocol ValidationRule: Sendable {

    /// Human-readable name of this rule.
    var name: String { get }

    /// Validates the given audio file info and returns any issues found.
    /// - Parameter info: The audio file data to validate.
    /// - Returns: An array of issues (empty if valid).
    func validate(_ info: AudioFileInfo) -> [ValidationIssue]
}
