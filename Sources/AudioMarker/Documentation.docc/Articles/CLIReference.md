# CLI Reference

@Metadata {
    @PageKind(article)
}

Command-line tool for managing audio file metadata, chapters, artwork, and lyrics.

## Overview

The `audio-marker` CLI provides 9 command groups with 17 subcommands. Install via Swift Package Manager and use directly from the terminal.

### Installation

```bash
swift build -c release
cp .build/release/audio-marker /usr/local/bin/
```

### Commands

#### read

Display all metadata, chapters, and lyrics from an audio file.

```bash
audio-marker read song.mp3
audio-marker read song.mp3 --format json
audio-marker read song.m4a --format text
```

#### write

Write metadata fields to an audio file.

```bash
audio-marker write song.mp3 --title "New Title" --artist "Artist" --album "Album"
audio-marker write song.mp3 --year 2025 --genre "Rock" --bpm 120
audio-marker write song.mp3 --lyrics "Plain text lyrics here"
```

#### chapters

Manage chapter markers with `add`, `import`, `export`, and `clear` subcommands.

```bash
# Add a chapter
audio-marker chapters add song.mp3 --title "Intro" --start 00:00:00

# Import from file
audio-marker chapters import song.mp3 --from chapters.json --format podlove-json

# Export to file
audio-marker chapters export song.mp3 --to chapters.json --format podlove-json
audio-marker chapters export song.mp3 --format mp4chaps
audio-marker chapters export song.mp3 --format ffmetadata

# Clear all chapters
audio-marker chapters clear song.mp3 --force
```

Supported chapter formats: `podlove-json`, `podlove-xml`, `mp4chaps`, `ffmetadata`, `markdown`, `podcast-namespace`, `cue-sheet`.

#### lyrics

Manage synchronized lyrics with `export`, `import`, and `clear` subcommands.

```bash
# Export to LRC
audio-marker lyrics export song.mp3 --format lrc
audio-marker lyrics export song.mp3 --to lyrics.lrc --format lrc

# Export to TTML
audio-marker lyrics export song.mp3 --format ttml
audio-marker lyrics export song.mp3 --to lyrics.ttml --format ttml

# Export to WebVTT or SRT
audio-marker lyrics export song.mp3 --to subtitles.vtt --format webvtt
audio-marker lyrics export song.mp3 --to subtitles.srt --format srt

# Import lyrics
audio-marker lyrics import song.mp3 --from lyrics.ttml --format ttml
audio-marker lyrics import song.mp3 --from subtitles.vtt --format webvtt
audio-marker lyrics import song.mp3 --from subtitles.srt --format srt

# Clear all lyrics
audio-marker lyrics clear song.mp3 --force
```

Supported lyrics formats: `lrc`, `ttml`, `webvtt`, `srt`.

#### artwork

Manage cover artwork with `set`, `extract`, and `remove` subcommands.

```bash
# Set artwork
audio-marker artwork set song.mp3 --file cover.jpg

# Extract artwork
audio-marker artwork extract song.mp3 --output cover.jpg

# Remove artwork
audio-marker artwork remove song.mp3 --force
```

#### validate

Run validation rules against a file.

```bash
audio-marker validate song.mp3
```

#### strip

Remove all metadata from a file.

```bash
audio-marker strip song.mp3 --force
```

#### batch

Process multiple files in parallel.

```bash
audio-marker batch read *.mp3
audio-marker batch read *.mp3 --format json
```

#### info

Display file format information.

```bash
audio-marker info song.mp3
```

## Next Steps

- <doc:GettingStarted> — Use AudioMarker as a library
- <doc:ChapterFormats> — Chapter format details
- <doc:LyricsFormats> — Lyrics format details
