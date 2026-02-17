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

@Suite("TTML Parser")
struct TTMLParserTests {

    let parser = TTMLParser()

    // MARK: - Minimal Document

    @Test("Parses minimal TTML document")
    func minimalDocument() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:01.000" end="00:00:03.000">Hello world</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.language == "en")
        #expect(doc.divisions.count == 1)
        #expect(doc.divisions[0].paragraphs.count == 1)
        #expect(doc.divisions[0].paragraphs[0].text == "Hello world")
        #expect(doc.divisions[0].paragraphs[0].begin == .seconds(1))
        #expect(doc.divisions[0].paragraphs[0].end == .seconds(3))
    }

    // MARK: - Metadata

    @Test("Parses title from head metadata")
    func parsesTitle() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
              <head>
                <metadata>
                  <ttm:title>My Song</ttm:title>
                </metadata>
              </head>
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:01.000">Line</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.title == "My Song")
    }

    @Test("Parses description from head metadata")
    func parsesDescription() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
              <head>
                <metadata>
                  <ttm:desc>A song about testing</ttm:desc>
                </metadata>
              </head>
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:01.000">Line</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.description == "A song about testing")
    }

    // MARK: - Styles

    @Test("Parses style definitions")
    func parsesStyles() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:tts="http://www.w3.org/ns/ttml#styling">
              <head>
                <styling>
                  <style xml:id="s1" tts:color="#FFFFFF" tts:fontFamily="sans-serif"/>
                </styling>
              </head>
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:01.000">Line</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.styles.count == 1)
        #expect(doc.styles[0].id == "s1")
        #expect(doc.styles[0].color == "#FFFFFF")
        #expect(doc.styles[0].fontFamily == "sans-serif")
    }

    // MARK: - Regions

    @Test("Parses region definitions")
    func parsesRegions() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:tts="http://www.w3.org/ns/ttml#styling">
              <head>
                <layout>
                  <region xml:id="r1" tts:origin="10% 80%" tts:extent="80% 20%"
                          tts:displayAlign="after"/>
                </layout>
              </head>
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:01.000">Line</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.regions.count == 1)
        #expect(doc.regions[0].id == "r1")
        #expect(doc.regions[0].origin == "10% 80%")
        #expect(doc.regions[0].extent == "80% 20%")
        #expect(doc.regions[0].displayAlign == "after")
    }

    // MARK: - Agents

    @Test("Parses metadata agents")
    func parsesAgents() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
              <head>
                <metadata>
                  <ttm:agent xml:id="narrator" type="person">
                    <ttm:name>John</ttm:name>
                  </ttm:agent>
                </metadata>
              </head>
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:01.000">Line</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.agents.count == 1)
        #expect(doc.agents[0].id == "narrator")
        #expect(doc.agents[0].type == "person")
        #expect(doc.agents[0].name == "John")
    }

    // MARK: - Paragraphs

    @Test("Parses multiple paragraphs")
    func multipleParagraphs() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:01.000" end="00:00:03.000">First</p>
                  <p begin="00:00:03.000" end="00:00:06.000">Second</p>
                  <p begin="00:00:06.000" end="00:00:09.000">Third</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.divisions[0].paragraphs.count == 3)
        #expect(doc.divisions[0].paragraphs[0].text == "First")
        #expect(doc.divisions[0].paragraphs[1].text == "Second")
        #expect(doc.divisions[0].paragraphs[2].text == "Third")
    }

    @Test("Parses paragraph with dur attribute")
    func paragraphWithDur() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:01.000" dur="00:00:02.000">Duration line</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        let para = doc.divisions[0].paragraphs[0]
        #expect(para.begin == .seconds(1))
        #expect(para.end == .seconds(3))
    }

    @Test("Parses paragraph with style and region refs")
    func paragraphWithStyleAndRegion() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:01.000"
                     style="s1" region="r1">Styled line</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        let para = doc.divisions[0].paragraphs[0]
        #expect(para.styleID == "s1")
        #expect(para.regionID == "r1")
    }

    @Test("Parses paragraph with agent and role")
    func paragraphWithAgentAndRole() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:ttm="http://www.w3.org/ns/ttml#metadata">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:01.000"
                     ttm:agent="narrator" ttm:role="dialog">Hello</p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        let para = doc.divisions[0].paragraphs[0]
        #expect(para.agentID == "narrator")
        #expect(para.role == "dialog")
    }

    // MARK: - Karaoke Spans

    @Test("Parses karaoke spans inside paragraph")
    func karaokeSpans() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:01.000" end="00:00:05.000">
                    <span begin="00:00:01.000" end="00:00:02.000">Hello</span>
                    <span begin="00:00:02.000" end="00:00:03.500">beautiful</span>
                    <span begin="00:00:03.500" end="00:00:05.000">world</span>
                  </p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        let para = doc.divisions[0].paragraphs[0]
        #expect(para.spans.count == 3)
        #expect(para.spans[0].text == "Hello")
        #expect(para.spans[0].begin == .seconds(1))
        #expect(para.spans[0].end == .seconds(2))
        #expect(para.spans[1].text == "beautiful")
        #expect(para.spans[2].text == "world")
        #expect(para.text == "Hello beautiful world")
    }

    @Test("Parses span with style reference")
    func spanWithStyle() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:02.000">
                    <span begin="00:00:00.000" end="00:00:01.000" style="highlight">Word</span>
                  </p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        #expect(doc.divisions[0].paragraphs[0].spans[0].styleID == "highlight")
    }

    @Test("Span uses dur attribute when end is missing")
    func spanWithDur() throws {
        let ttml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:05.000">
                    <span begin="00:00:01.000" dur="00:00:02.000">Word</span>
                  </p>
                </div>
              </body>
            </tt>
            """
        let doc = try parser.parseDocument(from: ttml)
        let span = doc.divisions[0].paragraphs[0].spans[0]
        #expect(span.begin == .seconds(1))
        #expect(span.end == .seconds(3))
    }
}
