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

@Suite("TTML Style")
struct TTMLStyleTests {

    // MARK: - Creation

    @Test("Creates style with ID and properties")
    func basicCreation() {
        let style = TTMLStyle(
            id: "s1",
            properties: [
                "tts:color": "#FFFFFF",
                "tts:fontFamily": "sans-serif"
            ])
        #expect(style.id == "s1")
        #expect(style.properties.count == 2)
    }

    @Test("Creates style with empty properties")
    func emptyProperties() {
        let style = TTMLStyle(id: "empty")
        #expect(style.id == "empty")
        #expect(style.properties.isEmpty)
    }

    // MARK: - Convenience Accessors

    @Test("color accessor returns tts:color value")
    func colorAccessor() {
        let style = TTMLStyle(id: "s1", properties: ["tts:color": "#FF0000"])
        #expect(style.color == "#FF0000")
    }

    @Test("backgroundColor accessor returns tts:backgroundColor value")
    func backgroundColorAccessor() {
        let style = TTMLStyle(
            id: "s1", properties: ["tts:backgroundColor": "#000000"])
        #expect(style.backgroundColor == "#000000")
    }

    @Test("fontFamily accessor returns tts:fontFamily value")
    func fontFamilyAccessor() {
        let style = TTMLStyle(
            id: "s1", properties: ["tts:fontFamily": "monospace"])
        #expect(style.fontFamily == "monospace")
    }

    @Test("fontSize accessor returns tts:fontSize value")
    func fontSizeAccessor() {
        let style = TTMLStyle(
            id: "s1", properties: ["tts:fontSize": "18px"])
        #expect(style.fontSize == "18px")
    }

    @Test("fontWeight accessor returns tts:fontWeight value")
    func fontWeightAccessor() {
        let style = TTMLStyle(
            id: "s1", properties: ["tts:fontWeight": "bold"])
        #expect(style.fontWeight == "bold")
    }

    @Test("fontStyle accessor returns tts:fontStyle value")
    func fontStyleAccessor() {
        let style = TTMLStyle(
            id: "s1", properties: ["tts:fontStyle": "italic"])
        #expect(style.fontStyle == "italic")
    }

    @Test("textAlign accessor returns tts:textAlign value")
    func textAlignAccessor() {
        let style = TTMLStyle(
            id: "s1", properties: ["tts:textAlign": "center"])
        #expect(style.textAlign == "center")
    }

    @Test("direction accessor returns tts:direction value")
    func directionAccessor() {
        let style = TTMLStyle(
            id: "s1", properties: ["tts:direction": "rtl"])
        #expect(style.direction == "rtl")
    }

    @Test("writingMode accessor returns tts:writingMode value")
    func writingModeAccessor() {
        let style = TTMLStyle(
            id: "s1", properties: ["tts:writingMode": "tbrl"])
        #expect(style.writingMode == "tbrl")
    }

    @Test("opacity accessor returns tts:opacity value")
    func opacityAccessor() {
        let style = TTMLStyle(
            id: "s1", properties: ["tts:opacity": "0.5"])
        #expect(style.opacity == "0.5")
    }

    @Test("textDecoration accessor returns tts:textDecoration value")
    func textDecorationAccessor() {
        let style = TTMLStyle(
            id: "s1", properties: ["tts:textDecoration": "underline"])
        #expect(style.textDecoration == "underline")
    }

    @Test("Missing property accessor returns nil")
    func missingAccessor() {
        let style = TTMLStyle(id: "s1")
        #expect(style.color == nil)
        #expect(style.fontSize == nil)
        #expect(style.fontWeight == nil)
    }

    // MARK: - Hashable / Equatable

    @Test("Equal styles are Equatable")
    func equatable() {
        let s1 = TTMLStyle(id: "s1", properties: ["tts:color": "#FFF"])
        let s2 = TTMLStyle(id: "s1", properties: ["tts:color": "#FFF"])
        #expect(s1 == s2)
    }

    @Test("Different styles are not equal")
    func notEqual() {
        let s1 = TTMLStyle(id: "s1", properties: ["tts:color": "#FFF"])
        let s2 = TTMLStyle(id: "s2", properties: ["tts:color": "#FFF"])
        #expect(s1 != s2)
    }

    @Test("Equal styles produce same hash")
    func hashable() {
        let s1 = TTMLStyle(id: "s1", properties: ["tts:color": "#FFF"])
        let s2 = TTMLStyle(id: "s1", properties: ["tts:color": "#FFF"])
        #expect(s1.hashValue == s2.hashValue)
    }
}
