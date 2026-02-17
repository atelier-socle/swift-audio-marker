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

@Suite("Configuration")
struct ConfigurationTests {

    @Test("Default configuration has expected values")
    func defaultValues() {
        let config = Configuration.default
        #expect(config.id3Version == .v2_3)
        #expect(config.validateBeforeWriting == true)
        #expect(config.preserveUnknownData == true)
        #expect(config.id3PaddingSize == 2048)
    }

    @Test("Custom configuration stores values")
    func customValues() {
        let config = Configuration(
            id3Version: .v2_4,
            validateBeforeWriting: false,
            preserveUnknownData: false,
            id3PaddingSize: 4096)
        #expect(config.id3Version == .v2_4)
        #expect(config.validateBeforeWriting == false)
        #expect(config.preserveUnknownData == false)
        #expect(config.id3PaddingSize == 4096)
    }

    @Test("Hashable conformance")
    func hashable() {
        let a = Configuration.default
        let b = Configuration.default
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)

        let c = Configuration(id3Version: .v2_4)
        #expect(a != c)
    }
}
