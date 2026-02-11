import Foundation
import Testing

@testable import AudioMarker

@Suite("MP4VideoTrackBuilder")
struct MP4VideoTrackBuilderTests {

    let builder = MP4VideoTrackBuilder()

    // MARK: - Basic Building

    @Test("Builds video track with JPEG artwork")
    func buildVideoTrackWithJPEG() throws {
        let jpegData = MP4TestHelper.buildMinimalJPEG(size: 100)
        let chapters = ChapterList([
            Chapter(
                start: .zero, title: "Ch1",
                artwork: Artwork(data: jpegData, format: .jpeg)),
            Chapter(
                start: .seconds(30.0), title: "Ch2",
                artwork: Artwork(data: jpegData, format: .jpeg))
        ])

        let result = try #require(
            builder.buildVideoTrack(
                chapters: chapters, trackID: 3,
                movieTimescale: 44100, movieDuration: 441_000))

        #expect(!result.trak.isEmpty)
        #expect(result.sampleData.count == jpegData.count * 2)
        #expect(result.sampleSizes.count == 2)
        #expect(result.stcoEntryOffsets.count == 2)

        // Verify trak contains "jpeg" format.
        let trakString = String(data: result.trak, encoding: .isoLatin1) ?? ""
        #expect(trakString.contains("jpeg"))
        #expect(trakString.contains("vide"))
    }

    @Test("Builds video track with PNG artwork")
    func buildVideoTrackWithPNG() throws {
        let pngData = MP4TestHelper.buildMinimalPNG(size: 80)
        let chapters = ChapterList([
            Chapter(
                start: .zero, title: "Ch1",
                artwork: Artwork(data: pngData, format: .png))
        ])

        let result = try #require(
            builder.buildVideoTrack(
                chapters: chapters, trackID: 3,
                movieTimescale: 44100, movieDuration: 441_000))

        let trakString = String(data: result.trak, encoding: .isoLatin1) ?? ""
        #expect(trakString.contains("png "))
    }

    @Test("Sample count matches chapters with artwork")
    func sampleCountMatchesChaptersWithArtwork() throws {
        let jpegData = MP4TestHelper.buildMinimalJPEG()
        let chapters = ChapterList([
            Chapter(start: .zero, title: "Has Art", artwork: Artwork(data: jpegData, format: .jpeg)),
            Chapter(start: .seconds(10.0), title: "No Art"),
            Chapter(
                start: .seconds(20.0), title: "Has Art 2",
                artwork: Artwork(data: jpegData, format: .jpeg))
        ])

        let result = try #require(
            builder.buildVideoTrack(
                chapters: chapters, trackID: 3,
                movieTimescale: 1000, movieDuration: 30_000))

        // Only 2 chapters have artwork.
        #expect(result.sampleSizes.count == 2)
        #expect(result.stcoEntryOffsets.count == 2)
    }

    @Test("No artwork returns nil")
    func noArtworkReturnsNil() {
        let chapters = ChapterList([
            Chapter(start: .zero, title: "No Art 1"),
            Chapter(start: .seconds(10.0), title: "No Art 2")
        ])

        let result = builder.buildVideoTrack(
            chapters: chapters, trackID: 3,
            movieTimescale: 44100, movieDuration: 441_000)

        #expect(result == nil)
    }

    @Test("Sample sizes match image data byte counts")
    func sampleSizesMatchImageData() throws {
        let jpeg1 = MP4TestHelper.buildMinimalJPEG(size: 100)
        let jpeg2 = MP4TestHelper.buildMinimalJPEG(size: 200)
        let chapters = ChapterList([
            Chapter(
                start: .zero, title: "Ch1",
                artwork: Artwork(data: jpeg1, format: .jpeg)),
            Chapter(
                start: .seconds(30.0), title: "Ch2",
                artwork: Artwork(data: jpeg2, format: .jpeg))
        ])

        let result = try #require(
            builder.buildVideoTrack(
                chapters: chapters, trackID: 3,
                movieTimescale: 44100, movieDuration: 441_000))

        #expect(result.sampleSizes[0] == UInt32(jpeg1.count))
        #expect(result.sampleSizes[1] == UInt32(jpeg2.count))
        #expect(result.sampleData.count == jpeg1.count + jpeg2.count)
    }
}
