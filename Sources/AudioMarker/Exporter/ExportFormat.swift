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

/// Supported export formats for chapters and lyrics.
public enum ExportFormat: String, Sendable, CaseIterable {
    /// Podlove Simple Chapters (JSON).
    case podloveJSON
    /// Podlove Simple Chapters (XML).
    case podloveXML
    /// MP4Chaps plain text format.
    case mp4chaps
    /// FFmpeg metadata format.
    case ffmetadata
    /// Markdown (export only).
    case markdown
    /// LRC synchronized lyrics format.
    case lrc
    /// W3C Timed Text Markup Language.
    case ttml
    /// Podcasting 2.0 (podcast-namespace) JSON format.
    case podcastNamespace
    /// WebVTT synchronized lyrics/subtitle format.
    case webvtt
    /// SubRip (SRT) synchronized lyrics/subtitle format.
    case srt
    /// Cue Sheet chapter format.
    case cueSheet

    /// The file extension for this format.
    public var fileExtension: String {
        switch self {
        case .podloveJSON: "json"
        case .podloveXML: "xml"
        case .mp4chaps: "txt"
        case .ffmetadata: "ini"
        case .markdown: "md"
        case .lrc: "lrc"
        case .ttml: "ttml"
        case .podcastNamespace: "json"
        case .webvtt: "vtt"
        case .srt: "srt"
        case .cueSheet: "cue"
        }
    }

    /// Whether this format supports importing.
    public var supportsImport: Bool {
        switch self {
        case .markdown: false
        default: true
        }
    }
}
