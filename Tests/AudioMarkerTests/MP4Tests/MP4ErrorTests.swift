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

@Suite("MP4Error")
struct MP4ErrorTests {

    @Test("invalidFile has correct description")
    func invalidFile() {
        let error = MP4Error.invalidFile("Not a valid file")
        #expect(error.errorDescription == "Invalid MP4 file: Not a valid file.")
    }

    @Test("atomNotFound has correct description")
    func atomNotFound() {
        let error = MP4Error.atomNotFound("moov")
        #expect(error.errorDescription == "Required MP4 atom not found: \"moov\".")
    }

    @Test("invalidAtom has correct description")
    func invalidAtom() {
        let error = MP4Error.invalidAtom(type: "ftyp", reason: "Payload too small")
        #expect(error.errorDescription == "Invalid MP4 atom \"ftyp\": Payload too small.")
    }

    @Test("unsupportedFileType has correct description")
    func unsupportedFileType() {
        let error = MP4Error.unsupportedFileType("ZZZZ")
        #expect(error.errorDescription == "Unsupported MP4 file type: \"ZZZZ\".")
    }

    @Test("truncatedData has correct description")
    func truncatedData() {
        let error = MP4Error.truncatedData(expected: 100, available: 50)
        #expect(error.errorDescription == "Truncated MP4 data: expected 100 bytes, 50 available.")
    }

    @Test("writeFailed has correct description")
    func writeFailed() {
        let error = MP4Error.writeFailed("Disk full")
        #expect(error.errorDescription == "MP4 write failed: Disk full.")
    }
}
