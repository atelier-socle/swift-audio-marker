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

/// An operation to perform on a single audio file.
public enum BatchOperation: Sendable, Hashable {
    /// Read metadata and chapters from the file.
    case read
    /// Write the given metadata and chapters to the file.
    case write(AudioFileInfo)
    /// Strip all metadata and chapters.
    case strip
    /// Export chapters to a text format, saving to the given URL.
    case exportChapters(format: ExportFormat, outputURL: URL)
    /// Import chapters from a text string and write to the file.
    case importChapters(String, format: ExportFormat)
}
