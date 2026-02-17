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


import Testing

@testable import AudioMarker

@Suite("Cue Sheet Exporter")
struct CueSheetExporterTests {

    // MARK: - Parse

    @Test("Parses basic cue sheet")
    func parseBasic() throws {
        let cue = """
            FILE "audio.mp3" MP3
              TRACK 01 AUDIO
                TITLE "Introduction"
                INDEX 01 00:00:00
              TRACK 02 AUDIO
                TITLE "Main Topic"
                INDEX 01 01:30:00
              TRACK 03 AUDIO
                TITLE "Conclusion"
                INDEX 01 05:00:00
            """
        let chapters = try CueSheetExporter.parse(cue)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "Introduction")
        #expect(chapters[0].start == .zero)
        #expect(chapters[1].title == "Main Topic")
        #expect(chapters[1].start.timeInterval == 90.0)
        #expect(chapters[2].title == "Conclusion")
        #expect(chapters[2].start.timeInterval == 300.0)
    }

    @Test("Parses timestamps with CD frames")
    func parsesCDFrames() throws {
        let cue = """
            FILE "audio.mp3" MP3
              TRACK 01 AUDIO
                TITLE "Track One"
                INDEX 01 00:00:37
            """
        let chapters = try CueSheetExporter.parse(cue)
        // 37 frames at 75 fps = 37/75 ≈ 0.4933 seconds
        let expected = 37.0 / 75.0
        #expect(abs(chapters[0].start.timeInterval - expected) < 0.01)
    }

    @Test("Skips REM comments")
    func skipsREMComments() throws {
        let cue = """
            REM GENRE Rock
            REM DATE 2024
            FILE "audio.mp3" MP3
              TRACK 01 AUDIO
                TITLE "Song"
                INDEX 01 00:00:00
            """
        let chapters = try CueSheetExporter.parse(cue)
        #expect(chapters.count == 1)
        #expect(chapters[0].title == "Song")
    }

    @Test("Skips INDEX 00 pre-gap")
    func skipsPreGap() throws {
        let cue = """
            FILE "audio.mp3" MP3
              TRACK 01 AUDIO
                TITLE "First"
                INDEX 00 00:00:00
                INDEX 01 00:02:00
            """
        let chapters = try CueSheetExporter.parse(cue)
        #expect(chapters.count == 1)
        #expect(chapters[0].start.timeInterval == 2.0)
    }

    @Test("Uses default title when TITLE is missing")
    func defaultTitle() throws {
        let cue = """
            FILE "audio.mp3" MP3
              TRACK 01 AUDIO
                INDEX 01 00:00:00
              TRACK 02 AUDIO
                INDEX 01 01:00:00
            """
        let chapters = try CueSheetExporter.parse(cue)
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "Track 1")
        #expect(chapters[1].title == "Track 2")
    }

    @Test("Handles global TITLE and PERFORMER")
    func handlesGlobalMetadata() throws {
        let cue = """
            TITLE "Album Name"
            PERFORMER "Artist"
            FILE "audio.mp3" MP3
              TRACK 01 AUDIO
                TITLE "Song One"
                INDEX 01 00:00:00
            """
        let chapters = try CueSheetExporter.parse(cue)
        // Global TITLE is overridden by track TITLE.
        #expect(chapters[0].title == "Song One")
    }

    @Test("No valid tracks throws invalidData")
    func noTracksThrows() {
        #expect(throws: ExportError.self) {
            try CueSheetExporter.parse("REM This is just a comment\n")
        }
    }

    @Test("Empty input throws invalidData")
    func emptyInputThrows() {
        #expect(throws: ExportError.self) {
            try CueSheetExporter.parse("")
        }
    }

    // MARK: - Export

    @Test("Exports basic chapters to cue sheet")
    func exportBasic() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Introduction"),
            Chapter(start: .seconds(90), title: "Main Topic")
        ])
        let result = CueSheetExporter.export(chapters)
        #expect(result.contains("TRACK 01 AUDIO"))
        #expect(result.contains("TITLE \"Introduction\""))
        #expect(result.contains("INDEX 01 00:00:00"))
        #expect(result.contains("TRACK 02 AUDIO"))
        #expect(result.contains("TITLE \"Main Topic\""))
        #expect(result.contains("INDEX 01 01:30:00"))
    }

    @Test("Export includes metadata when provided")
    func exportWithMetadata() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "First")
        ])
        var metadata = AudioMetadata()
        metadata.title = "My Album"
        metadata.artist = "My Artist"
        let result = CueSheetExporter.export(chapters, metadata: metadata)
        #expect(result.contains("TITLE \"My Album\""))
        #expect(result.contains("PERFORMER \"My Artist\""))
    }

    @Test("Export uses custom audio filename")
    func exportCustomFilename() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "First")
        ])
        let result = CueSheetExporter.export(chapters, audioFilename: "podcast.m4a")
        #expect(result.contains("FILE \"podcast.m4a\" M4A"))
    }

    @Test("Export defaults to audio.mp3")
    func exportDefaultFilename() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "First")
        ])
        let result = CueSheetExporter.export(chapters)
        #expect(result.contains("FILE \"audio.mp3\" MP3"))
    }

    @Test("Export escapes quotes in titles")
    func exportEscapesQuotes() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "He said \"hello\"")
        ])
        let result = CueSheetExporter.export(chapters)
        #expect(result.contains("TITLE \"He said 'hello'\""))
    }

    @Test("Export formats CD frames correctly")
    func exportCDFrames() {
        // 0.5 seconds = 37.5 frames → rounded to 38
        let chapters = ChapterList([
            Chapter(start: AudioTimestamp(timeInterval: 0.5), title: "Half second")
        ])
        let result = CueSheetExporter.export(chapters)
        #expect(result.contains("INDEX 01 00:00:38"))
    }

    // MARK: - Round-Trip

    @Test("Round-trip preserves chapter titles and approximate timestamps")
    func roundTrip() throws {
        let original = ChapterList([
            Chapter(start: .zero, title: "Intro"),
            Chapter(start: .seconds(90), title: "Chapter 2"),
            Chapter(start: .seconds(300), title: "End")
        ])
        let exported = CueSheetExporter.export(original)
        let imported = try CueSheetExporter.parse(exported)

        #expect(imported.count == original.count)
        for (orig, imp) in zip(original, imported) {
            #expect(orig.title == imp.title)
            // Cue Sheet uses CD frames (1/75s), so timestamps may differ slightly.
            #expect(abs(orig.start.timeInterval - imp.start.timeInterval) < 0.02)
        }
    }

    @Test("Round-trip with WAV file type")
    func roundTripWAV() throws {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "First Track")
        ])
        let exported = CueSheetExporter.export(chapters, audioFilename: "audio.wav")
        #expect(exported.contains("FILE \"audio.wav\" WAVE"))
        let imported = try CueSheetExporter.parse(exported)
        #expect(imported.count == 1)
        #expect(imported[0].title == "First Track")
    }
}
