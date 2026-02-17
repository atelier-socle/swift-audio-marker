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


import Foundation
import Testing

@testable import AudioMarker

@Suite("Batch Operation")
struct BatchOperationTests {

    // MARK: - BatchItem Creation

    @Test("BatchItem stores URL and operation")
    func batchItemCreation() {
        let url = URL(fileURLWithPath: "/tmp/test.mp3")
        let item = BatchItem(url: url, operation: .read)
        #expect(item.url == url)
        #expect(item.operation == .read)
    }

    // MARK: - BatchOperation Cases

    @Test("read case")
    func readCase() {
        let op = BatchOperation.read
        #expect(op == .read)
    }

    @Test("write case stores AudioFileInfo")
    func writeCase() {
        let info = AudioFileInfo(metadata: AudioMetadata(title: "Test"))
        let op = BatchOperation.write(info)
        if case .write(let stored) = op {
            #expect(stored.metadata.title == "Test")
        } else {
            Issue.record("Expected write case")
        }
    }

    @Test("strip case")
    func stripCase() {
        let op = BatchOperation.strip
        #expect(op == .strip)
    }

    @Test("exportChapters case stores format and outputURL")
    func exportChaptersCase() {
        let output = URL(fileURLWithPath: "/tmp/chapters.json")
        let op = BatchOperation.exportChapters(format: .podloveJSON, outputURL: output)
        if case .exportChapters(let format, let url) = op {
            #expect(format == .podloveJSON)
            #expect(url == output)
        } else {
            Issue.record("Expected exportChapters case")
        }
    }

    @Test("importChapters case stores string and format")
    func importChaptersCase() {
        let json = "{}"
        let op = BatchOperation.importChapters(json, format: .podloveJSON)
        if case .importChapters(let string, let format) = op {
            #expect(string == json)
            #expect(format == .podloveJSON)
        } else {
            Issue.record("Expected importChapters case")
        }
    }

    // MARK: - Hashable

    @Test("Equal operations hash equally")
    func hashableEqual() {
        let a = BatchOperation.read
        let b = BatchOperation.read
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Different operations are not equal")
    func hashableDifferent() {
        let read = BatchOperation.read
        let strip = BatchOperation.strip
        #expect(read != strip)
    }

    @Test("BatchItem Hashable conformance")
    func batchItemHashable() {
        let url = URL(fileURLWithPath: "/tmp/test.mp3")
        let a = BatchItem(url: url, operation: .read)
        let b = BatchItem(url: url, operation: .read)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)

        let c = BatchItem(url: url, operation: .strip)
        #expect(a != c)
    }
}
