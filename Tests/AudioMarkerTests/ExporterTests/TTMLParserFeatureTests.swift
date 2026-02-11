import Testing

@testable import AudioMarker

@Suite("TTML Parser Features")
struct TTMLParserFeatureTests {

    let parser = TTMLParser()

    // MARK: - Line Breaks

    @Test("Parses <br/> as newline in text")
    func lineBreak() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:05.000">First line<br/>Second line</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.divisions[0].paragraphs[0].text == "First line\nSecond line")
    }

    // MARK: - Multiple Divisions

    @Test("Parses multiple divs as separate divisions")
    func multipleDivisions() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div xml:lang="en">
                  <p begin="00:00:00.000" end="00:00:05.000">Hello</p>
                </div>
                <div xml:lang="fr">
                  <p begin="00:00:00.000" end="00:00:05.000">Bonjour</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.divisions.count == 2)
        #expect(doc.divisions[0].language == "en")
        #expect(doc.divisions[0].paragraphs[0].text == "Hello")
        #expect(doc.divisions[1].language == "fr")
        #expect(doc.divisions[1].paragraphs[0].text == "Bonjour")
    }

    // MARK: - Division Attributes

    @Test("Parses div with style and region")
    func divWithAttributes() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div style="s1" region="r1">
                  <p begin="00:00:00.000" end="00:00:01.000">Line</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.divisions[0].styleID == "s1")
        #expect(doc.divisions[0].regionID == "r1")
    }

    // MARK: - Time Base

    @Test("Parses timeBase and frameRate from root")
    func timeBaseAndFrameRate() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:ttp="http://www.w3.org/ns/ttml#parameter"
                ttp:timeBase="smpte" ttp:frameRate="25">
              <body>
                <div>
                  <p begin="00:00:01.000" end="00:00:02.000">Line</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.timeBase == "smpte")
        #expect(doc.frameRate == 25)
    }

    // MARK: - Empty Body

    @Test("Parses TTML with empty body")
    func emptyBody() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div/>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.divisions.count == 1)
        #expect(doc.divisions[0].paragraphs.isEmpty)
    }

    // MARK: - Offset Time in Paragraphs

    @Test("Parses offset time expressions in begin/end")
    func offsetTimeInParagraphs() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="5s" end="10s">Line with offset time</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        let para = doc.divisions[0].paragraphs[0]
        #expect(para.begin == .seconds(5))
        #expect(para.end == .seconds(10))
    }

    // MARK: - parseLyrics Convenience

    @Test("parseLyrics returns SynchronizedLyrics array")
    func parseLyricsConvenience() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:03.000">First</p>
                  <p begin="00:00:03.000" end="00:00:06.000">Second</p>
                </div>
              </body>
            </tt>
            """
        let lyrics = try parser.parseLyrics(from: ttml)
        #expect(lyrics.count == 1)
        #expect(lyrics[0].language == "eng")
        #expect(lyrics[0].lines.count == 2)
        #expect(lyrics[0].lines[0].text == "First")
        #expect(lyrics[0].lines[1].text == "Second")
    }

    @Test("parseLyrics converts multi-div to multiple lyrics")
    func parseLyricsMultiDiv() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div xml:lang="en">
                  <p begin="00:00:00.000" end="00:00:03.000">Hello</p>
                </div>
                <div xml:lang="fr">
                  <p begin="00:00:00.000" end="00:00:03.000">Bonjour</p>
                </div>
              </body>
            </tt>
            """
        let lyrics = try parser.parseLyrics(from: ttml)
        #expect(lyrics.count == 2)
        #expect(lyrics[0].language == "eng")
        #expect(lyrics[1].language == "fra")
    }

    @Test("parseLyrics preserves karaoke segments")
    func parseLyricsKaraoke() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:05.000">
                    <span begin="00:00:00.000" end="00:00:02.000">Hello</span>
                    <span begin="00:00:02.000" end="00:00:05.000">world</span>
                  </p>
                </div>
              </body>
            </tt>
            """
        let lyrics = try parser.parseLyrics(from: ttml)
        #expect(lyrics[0].lines[0].isKaraoke)
        #expect(lyrics[0].lines[0].segments.count == 2)
        #expect(lyrics[0].lines[0].segments[0].text == "Hello")
        #expect(lyrics[0].lines[0].segments[0].startTime == .zero)
        #expect(lyrics[0].lines[0].segments[0].endTime == .seconds(2))
    }

    // MARK: - Error Cases

    @Test("Throws for invalid XML")
    func invalidXML() {
        #expect(throws: TTMLParseError.self) {
            try parser.parseDocument(from: "not xml at all <<<")
        }
    }

    @Test("Throws missingTiming for paragraph without begin")
    func missingBegin() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p end="00:00:05.000">No begin</p>
                </div>
              </body>
            </tt>
            """
        #expect(throws: TTMLParseError.self) {
            try parser.parseDocument(from: ttml)
        }
    }

    @Test("Throws for invalid time expression")
    func invalidTimeExpression() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="not-a-time" end="00:00:05.000">Bad time</p>
                </div>
              </body>
            </tt>
            """
        #expect(throws: TTMLParseError.self) {
            try parser.parseDocument(from: ttml)
        }
    }

    // MARK: - Whitespace Normalization

    @Test("Normalizes whitespace in paragraph text")
    func normalizesWhitespace() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:05.000">
                    Hello     world
                  </p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.divisions[0].paragraphs[0].text == "Hello world")
    }
}
