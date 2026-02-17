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

@Suite("ID3 Header")
struct ID3HeaderTests {

    // MARK: - Valid Headers

    @Test("Parses valid v2.3 header")
    func parseV23Header() throws {
        var writer = BinaryWriter()
        writer.writeData(Data([0x49, 0x44, 0x33]))  // "ID3"
        writer.writeUInt8(3)  // Major version
        writer.writeUInt8(0)  // Revision
        writer.writeUInt8(0x00)  // Flags
        writer.writeSyncsafeUInt32(1024)  // Tag size

        let header = try ID3Header(data: writer.data)
        #expect(header.version == .v2_3)
        #expect(header.tagSize == 1024)
        #expect(!header.flags.unsynchronization)
        #expect(!header.flags.extendedHeader)
        #expect(!header.flags.experimental)
        #expect(!header.flags.footer)
    }

    @Test("Parses valid v2.4 header")
    func parseV24Header() throws {
        var writer = BinaryWriter()
        writer.writeData(Data([0x49, 0x44, 0x33]))
        writer.writeUInt8(4)
        writer.writeUInt8(0)
        writer.writeUInt8(0x00)
        writer.writeSyncsafeUInt32(2048)

        let header = try ID3Header(data: writer.data)
        #expect(header.version == .v2_4)
        #expect(header.tagSize == 2048)
    }

    // MARK: - Flags

    @Test("Parses unsynchronization flag")
    func unsynchronizationFlag() throws {
        var writer = BinaryWriter()
        writer.writeData(Data([0x49, 0x44, 0x33]))
        writer.writeUInt8(3)
        writer.writeUInt8(0)
        writer.writeUInt8(0x80)  // Unsync flag
        writer.writeSyncsafeUInt32(0)

        let header = try ID3Header(data: writer.data)
        #expect(header.flags.unsynchronization)
        #expect(!header.flags.extendedHeader)
    }

    @Test("Parses extended header flag")
    func extendedHeaderFlag() throws {
        var writer = BinaryWriter()
        writer.writeData(Data([0x49, 0x44, 0x33]))
        writer.writeUInt8(3)
        writer.writeUInt8(0)
        writer.writeUInt8(0x40)  // Extended header flag
        writer.writeSyncsafeUInt32(0)

        let header = try ID3Header(data: writer.data)
        #expect(header.flags.extendedHeader)
    }

    @Test("Parses experimental flag")
    func experimentalFlag() throws {
        var writer = BinaryWriter()
        writer.writeData(Data([0x49, 0x44, 0x33]))
        writer.writeUInt8(3)
        writer.writeUInt8(0)
        writer.writeUInt8(0x20)  // Experimental flag
        writer.writeSyncsafeUInt32(0)

        let header = try ID3Header(data: writer.data)
        #expect(header.flags.experimental)
    }

    @Test("Parses v2.4 footer flag")
    func footerFlag() throws {
        var writer = BinaryWriter()
        writer.writeData(Data([0x49, 0x44, 0x33]))
        writer.writeUInt8(4)
        writer.writeUInt8(0)
        writer.writeUInt8(0x10)  // Footer flag (v2.4 only)
        writer.writeSyncsafeUInt32(0)

        let header = try ID3Header(data: writer.data)
        #expect(header.flags.footer)
    }

    @Test("Footer flag ignored in v2.3")
    func footerFlagIgnoredInV23() throws {
        var writer = BinaryWriter()
        writer.writeData(Data([0x49, 0x44, 0x33]))
        writer.writeUInt8(3)
        writer.writeUInt8(0)
        writer.writeUInt8(0x10)  // Footer bit set but v2.3
        writer.writeSyncsafeUInt32(0)

        let header = try ID3Header(data: writer.data)
        #expect(!header.flags.footer)
    }

    // MARK: - Tag Size

    @Test("Syncsafe tag size is decoded correctly")
    func syncsafeTagSize() throws {
        // Syncsafe: 0x00 0x00 0x02 0x01 = (0 << 21) | (0 << 14) | (2 << 7) | 1 = 257
        let data = Data([0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x02, 0x01])
        let header = try ID3Header(data: data)
        #expect(header.tagSize == 257)
    }

    // MARK: - Errors

    @Test("Missing ID3 marker throws noTag")
    func missingMarker() {
        let data = Data([0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        #expect(throws: ID3Error.self) {
            _ = try ID3Header(data: data)
        }
    }

    @Test("Unsupported version v2.2 throws")
    func unsupportedVersionV22() {
        let data = Data([0x49, 0x44, 0x33, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        #expect(throws: ID3Error.self) {
            _ = try ID3Header(data: data)
        }
    }

    @Test("Unsupported version v2.5 throws")
    func unsupportedVersionV25() {
        let data = Data([0x49, 0x44, 0x33, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        #expect(throws: ID3Error.self) {
            _ = try ID3Header(data: data)
        }
    }

    @Test("Data too short throws invalidHeader")
    func dataTooShort() {
        let data = Data([0x49, 0x44, 0x33])
        #expect(throws: ID3Error.self) {
            _ = try ID3Header(data: data)
        }
    }

    @Test("Invalid syncsafe integer throws")
    func invalidSyncsafe() {
        // Byte 6 has bit 7 set (0x80)
        let data = Data([0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00])
        #expect(throws: ID3Error.self) {
            _ = try ID3Header(data: data)
        }
    }
}
