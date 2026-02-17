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


import ArgumentParser

/// Command-line tool for managing audio file metadata and chapters.
@available(macOS 14, iOS 17, macCatalyst 17, visionOS 1, *)
public struct AudioMarkerCLI: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "audio-marker",
        abstract: "Manage audio file metadata, chapters, and artwork.",
        version: "0.1.0",
        subcommands: [
            Read.self,
            Write.self,
            Chapters.self,
            Lyrics.self,
            ArtworkGroup.self,
            Validate.self,
            Strip.self,
            Batch.self,
            Info.self
        ]
    )

    public init() {}
}
