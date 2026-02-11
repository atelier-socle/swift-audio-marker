import Testing

@testable import AudioMarker

@Suite("TTML Exporter Document")
struct TTMLExporterDocumentTests {

    // MARK: - TTMLDocument Export

    @Test("Exports TTMLDocument with styles and regions")
    func exportDocument() {
        let doc = TTMLDocument(
            language: "en",
            styles: [
                TTMLStyle(
                    id: "s1", properties: ["tts:color": "#FFFFFF"])
            ],
            regions: [
                TTMLRegion(
                    id: "r1", origin: "10% 80%", extent: "80% 20%")
            ],
            divisions: [
                TTMLDivision(
                    language: "en",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(3), text: "Hello")
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("xml:lang=\"en\""))
        #expect(result.contains("xmlns:tts="))
        #expect(result.contains("<style xml:id=\"s1\""))
        #expect(result.contains("tts:color=\"#FFFFFF\""))
        #expect(result.contains("<region xml:id=\"r1\""))
        #expect(result.contains("tts:origin=\"10% 80%\""))
        #expect(result.contains(">Hello</p>"))
    }

    @Test("Exports TTMLDocument with title and description")
    func exportDocumentMetadata() {
        let doc = TTMLDocument(
            language: "en",
            title: "My Song",
            description: "A great song",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Line")
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("<ttm:title>My Song</ttm:title>"))
        #expect(result.contains("<ttm:desc>A great song</ttm:desc>"))
    }

    @Test("Exports TTMLDocument with agents")
    func exportDocumentAgents() {
        let doc = TTMLDocument(
            language: "en",
            agents: [
                TTMLAgent(id: "narrator", type: "person", name: "John")
            ],
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Line")
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("<ttm:agent xml:id=\"narrator\""))
        #expect(result.contains("type=\"person\""))
        #expect(result.contains("<ttm:name>John</ttm:name>"))
    }

    @Test("Exports TTMLDocument with paragraph attributes")
    func exportDocumentParagraphAttributes() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1),
                            text: "Line",
                            styleID: "s1",
                            regionID: "r1",
                            agentID: "narrator",
                            role: "dialog")
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("style=\"s1\""))
        #expect(result.contains("region=\"r1\""))
        #expect(result.contains("ttm:agent=\"narrator\""))
        #expect(result.contains("ttm:role=\"dialog\""))
    }

    @Test("Exports TTMLDocument with karaoke spans")
    func exportDocumentKaraoke() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(5),
                            text: "Hello world",
                            spans: [
                                TTMLSpan(
                                    begin: .zero, end: .seconds(2),
                                    text: "Hello"),
                                TTMLSpan(
                                    begin: .seconds(2), end: .seconds(5),
                                    text: "world")
                            ])
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("<span begin=\"00:00:00.000\" end=\"00:00:02.000\">Hello</span>"))
        #expect(result.contains("<span begin=\"00:00:02.000\" end=\"00:00:05.000\">world</span>"))
    }

    @Test("TTMLDocument export omits head when empty")
    func exportDocumentNoHead() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Line")
                    ])
            ])

        let result = TTMLExporter.exportDocument(doc)
        #expect(!result.contains("<head>"))
    }

    @Test("Exports TTMLDocument with frameRate")
    func exportDocumentFrameRate() {
        let doc = TTMLDocument(
            language: "en",
            timeBase: "smpte",
            frameRate: 25,
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Line")
                    ])
            ])
        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("ttp:frameRate=\"25\""))
    }

    @Test("Exports TTMLDocument with region displayAlign and properties")
    func exportDocumentRegionFull() {
        let doc = TTMLDocument(
            language: "en",
            regions: [
                TTMLRegion(
                    id: "r1",
                    origin: "10% 80%",
                    extent: "80% 20%",
                    displayAlign: "after",
                    properties: ["tts:overflow": "visible"])
            ],
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Line")
                    ])
            ])
        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("tts:displayAlign=\"after\""))
        #expect(result.contains("tts:overflow=\"visible\""))
    }

    @Test("Exports TTMLDocument div with style and region")
    func exportDocumentDivAttributes() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    language: "fr",
                    styleID: "s1",
                    regionID: "r1",
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(1), text: "Bonjour")
                    ])
            ])
        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("xml:lang=\"fr\""))
        #expect(result.contains("style=\"s1\""))
        #expect(result.contains("region=\"r1\""))
    }

    @Test("Exports TTMLDocument span with style")
    func exportDocumentSpanStyle() {
        let doc = TTMLDocument(
            language: "en",
            divisions: [
                TTMLDivision(
                    paragraphs: [
                        TTMLParagraph(
                            begin: .zero, end: .seconds(5),
                            text: "Hello",
                            spans: [
                                TTMLSpan(
                                    begin: .zero, end: .seconds(2),
                                    text: "Hello", styleID: "hl")
                            ])
                    ])
            ])
        let result = TTMLExporter.exportDocument(doc)
        #expect(result.contains("style=\"hl\""))
    }
}
