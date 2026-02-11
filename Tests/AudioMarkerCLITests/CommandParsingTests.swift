import ArgumentParser
import Testing

@testable import AudioMarkerCommands

@Suite("Command Parsing")
struct CommandParsingTests {

    // MARK: - Read

    @Test("Read parses file path and default format")
    func readDefaults() throws {
        let cmd = try Read.parse(["song.mp3"])
        #expect(cmd.file == "song.mp3")
        #expect(cmd.format == "text")
    }

    @Test("Read parses json format option")
    func readJSON() throws {
        let cmd = try Read.parse(["song.mp3", "--format", "json"])
        #expect(cmd.format == "json")
    }

    // MARK: - Write

    @Test("Write parses title, artist, album, year")
    func writeMetadata() throws {
        let cmd = try Write.parse([
            "song.mp3",
            "--title", "My Song",
            "--artist", "Artist",
            "--album", "Album",
            "--year", "2024"
        ])
        #expect(cmd.file == "song.mp3")
        #expect(cmd.title == "My Song")
        #expect(cmd.artist == "Artist")
        #expect(cmd.album == "Album")
        #expect(cmd.year == 2024)
    }

    @Test("Write parses extended options")
    func writeExtended() throws {
        let cmd = try Write.parse([
            "song.mp3",
            "--genre", "Rock",
            "--track-number", "3",
            "--disc-number", "1",
            "--composer", "Bach",
            "--album-artist", "VA",
            "--comment", "Nice",
            "--bpm", "120"
        ])
        #expect(cmd.genre == "Rock")
        #expect(cmd.trackNumber == 3)
        #expect(cmd.discNumber == 1)
        #expect(cmd.composer == "Bach")
        #expect(cmd.albumArtist == "VA")
        #expect(cmd.comment == "Nice")
        #expect(cmd.bpm == 120)
    }

    @Test("Write parses artwork path")
    func writeArtwork() throws {
        let cmd = try Write.parse(["song.mp3", "--artwork", "cover.jpg"])
        #expect(cmd.artwork == "cover.jpg")
    }

    // MARK: - Chapters List

    @Test("Chapters list parses file")
    func chaptersList() throws {
        let cmd = try Chapters.List.parse(["song.mp3"])
        #expect(cmd.file == "song.mp3")
    }

    // MARK: - Chapters Add

    @Test("Chapters add parses start, title, url")
    func chaptersAdd() throws {
        let cmd = try Chapters.Add.parse([
            "song.mp3",
            "--start", "00:01:30",
            "--title", "Verse 1",
            "--url", "https://example.com"
        ])
        #expect(cmd.file == "song.mp3")
        #expect(cmd.start == "00:01:30")
        #expect(cmd.title == "Verse 1")
        #expect(cmd.url == "https://example.com")
    }

    @Test("Chapters add parses artwork option")
    func chaptersAddArtwork() throws {
        let cmd = try Chapters.Add.parse([
            "song.mp3",
            "--start", "00:02:00",
            "--title", "Solo",
            "--artwork", "cover.jpg"
        ])
        #expect(cmd.artwork == "cover.jpg")
    }

    // MARK: - Chapters Clear

    @Test("Chapters clear parses file and force flag")
    func chaptersClearForce() throws {
        let cmd = try Chapters.Clear.parse(["song.mp3", "--force"])
        #expect(cmd.file == "song.mp3")
        #expect(cmd.force)
    }

    @Test("Chapters clear defaults force to false")
    func chaptersClearDefaultForce() throws {
        let cmd = try Chapters.Clear.parse(["song.mp3"])
        #expect(!cmd.force)
    }

    // MARK: - Chapters Remove

    @Test("Chapters remove parses index")
    func chaptersRemoveByIndex() throws {
        let cmd = try Chapters.Remove.parse(["song.mp3", "--index", "2"])
        #expect(cmd.file == "song.mp3")
        #expect(cmd.index == 2)
        #expect(cmd.title == nil)
    }

    @Test("Chapters remove parses title")
    func chaptersRemoveByTitle() throws {
        let cmd = try Chapters.Remove.parse(["song.mp3", "--title", "Intro"])
        #expect(cmd.title == "Intro")
        #expect(cmd.index == nil)
    }

    // MARK: - Chapters Import

    @Test("Chapters import parses file, from, format")
    func chaptersImport() throws {
        let cmd = try Chapters.Import.parse([
            "song.mp3",
            "--from", "chapters.json",
            "--format", "podlove-xml"
        ])
        #expect(cmd.file == "song.mp3")
        #expect(cmd.from == "chapters.json")
        #expect(cmd.format == "podlove-xml")
    }

    @Test("Chapters import has default format")
    func chaptersImportDefault() throws {
        let cmd = try Chapters.Import.parse(["song.mp3", "--from", "chapters.json"])
        #expect(cmd.format == "podlove-json")
    }

    // MARK: - Chapters Export

    @Test("Chapters export parses file, to, format")
    func chaptersExport() throws {
        let cmd = try Chapters.Export.parse([
            "song.mp3",
            "--to", "output.json",
            "--format", "mp4chaps"
        ])
        #expect(cmd.file == "song.mp3")
        #expect(cmd.to == "output.json")
        #expect(cmd.format == "mp4chaps")
    }

    @Test("Chapters export defaults to stdout and podlove-json")
    func chaptersExportDefaults() throws {
        let cmd = try Chapters.Export.parse(["song.mp3"])
        #expect(cmd.to == nil)
        #expect(cmd.format == "podlove-json")
    }

    // MARK: - Strip

    @Test("Strip parses file and force flag")
    func stripCommand() throws {
        let cmd = try Strip.parse(["song.mp3", "--force"])
        #expect(cmd.file == "song.mp3")
        #expect(cmd.force)
    }

    @Test("Strip defaults force to false")
    func stripDefaultForce() throws {
        let cmd = try Strip.parse(["song.mp3"])
        #expect(!cmd.force)
    }

    // MARK: - Info

    @Test("Info parses file")
    func infoCommand() throws {
        let cmd = try Info.parse(["song.mp3"])
        #expect(cmd.file == "song.mp3")
    }

    // MARK: - Batch Read

    @Test("Batch read parses directory, recursive, concurrency")
    func batchRead() throws {
        let cmd = try Batch.BatchRead.parse([
            "/music", "--recursive", "--concurrency", "8"
        ])
        #expect(cmd.directory == "/music")
        #expect(cmd.recursive)
        #expect(cmd.concurrency == 8)
    }

    @Test("Batch read has defaults")
    func batchReadDefaults() throws {
        let cmd = try Batch.BatchRead.parse(["/music"])
        #expect(!cmd.recursive)
        #expect(cmd.concurrency == 4)
    }

    // MARK: - Batch Strip

    @Test("Batch strip parses directory, recursive, force, concurrency")
    func batchStrip() throws {
        let cmd = try Batch.BatchStrip.parse([
            "/music", "--recursive", "--force", "--concurrency", "2"
        ])
        #expect(cmd.directory == "/music")
        #expect(cmd.recursive)
        #expect(cmd.force)
        #expect(cmd.concurrency == 2)
    }
}
