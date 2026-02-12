# ``AudioMarker/AudioMetadata``

All metadata fields for an audio file.

## Overview

`AudioMetadata` holds 30+ fields covering core info, professional data, URLs, artwork, lyrics, and custom extensions. All fields are optional except where noted.

```swift
var meta = AudioMetadata(title: "My Song", artist: "Artist", album: "Album")
meta.genre = "Rock"
meta.year = 2025
meta.bpm = 120
meta.artwork = Artwork(data: jpegData, format: .jpeg)
```

## Topics

### Creating

- ``init(title:artist:album:artwork:)``

### Core Fields

- ``title``
- ``artist``
- ``album``
- ``genre``
- ``year``
- ``trackNumber``
- ``discNumber``

### Professional Fields

- ``composer``
- ``albumArtist``
- ``publisher``
- ``copyright``
- ``encoder``
- ``comment``
- ``bpm``
- ``key``
- ``language``
- ``isrc``

### Artwork

- ``artwork``

### Lyrics

- ``unsynchronizedLyrics``
- ``synchronizedLyrics``

### URLs

- ``artistURL``
- ``audioSourceURL``
- ``audioFileURL``
- ``publisherURL``
- ``commercialURL``
- ``customURLs``

### Custom Data

- ``customTextFields``
- ``privateData``
- ``uniqueFileIdentifiers``

### Statistics

- ``playCount``
- ``rating``
