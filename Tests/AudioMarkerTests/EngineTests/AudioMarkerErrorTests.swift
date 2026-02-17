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

@Suite("AudioMarker Error")
struct AudioMarkerErrorTests {

    @Test("unknownFormat has description with file name")
    func unknownFormatDescription() {
        let error = AudioMarkerError.unknownFormat("test.wav")
        #expect(error.errorDescription?.contains("test.wav") == true)
    }

    @Test("unsupportedFormat has description with format and operation")
    func unsupportedFormatDescription() {
        let error = AudioMarkerError.unsupportedFormat(.mp3, operation: "transcode")
        #expect(error.errorDescription?.contains("mp3") == true)
        #expect(error.errorDescription?.contains("transcode") == true)
    }

    @Test("readFailed has description with detail")
    func readFailedDescription() {
        let error = AudioMarkerError.readFailed("file corrupted")
        #expect(error.errorDescription?.contains("file corrupted") == true)
    }

    @Test("writeFailed has description with detail")
    func writeFailedDescription() {
        let error = AudioMarkerError.writeFailed("disk full")
        #expect(error.errorDescription?.contains("disk full") == true)
    }

    @Test("validationFailed includes issue count")
    func validationFailedDescription() {
        let issues = [
            ValidationIssue(severity: .error, message: "Bad title"),
            ValidationIssue(severity: .error, message: "Bad year")
        ]
        let error = AudioMarkerError.validationFailed(issues)
        #expect(error.errorDescription?.contains("2") == true)
    }

    @Test("validationFailed contains the issues")
    func validationFailedIssues() {
        let issues = [ValidationIssue(severity: .error, message: "Test")]
        let error = AudioMarkerError.validationFailed(issues)
        if case .validationFailed(let captured) = error {
            #expect(captured.count == 1)
            #expect(captured[0].message == "Test")
        } else {
            Issue.record("Expected validationFailed case")
        }
    }
}
