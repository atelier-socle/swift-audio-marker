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

@Suite("Streaming Constants")
struct StreamingConstantsTests {

    @Test("Default buffer size is 64 KB")
    func defaultBufferSize() {
        #expect(StreamingConstants.defaultBufferSize == 65_536)
    }

    @Test("Minimum buffer size is 4 KB")
    func minimumBufferSize() {
        #expect(StreamingConstants.minimumBufferSize == 4_096)
    }

    @Test("Maximum buffer size is 1 MB")
    func maximumBufferSize() {
        #expect(StreamingConstants.maximumBufferSize == 1_048_576)
    }

    @Test("Minimum is less than default, default is less than maximum")
    func ordering() {
        #expect(StreamingConstants.minimumBufferSize < StreamingConstants.defaultBufferSize)
        #expect(StreamingConstants.defaultBufferSize < StreamingConstants.maximumBufferSize)
    }
}
