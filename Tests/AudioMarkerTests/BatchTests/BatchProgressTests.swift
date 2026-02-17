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

@Suite("Batch Progress")
struct BatchProgressTests {

    // MARK: - Fraction

    @Test("Fraction calculates correctly")
    func fractionCalculation() {
        let progress = BatchProgress(total: 4, completed: 2, latestResult: nil)
        #expect(progress.fraction == 0.5)
    }

    @Test("Fraction is 1.0 when total is zero")
    func fractionZeroTotal() {
        let progress = BatchProgress(total: 0, completed: 0, latestResult: nil)
        #expect(progress.fraction == 1.0)
    }

    @Test("Fraction is 1.0 when all completed")
    func fractionComplete() {
        let progress = BatchProgress(total: 3, completed: 3, latestResult: nil)
        #expect(progress.fraction == 1.0)
    }

    // MARK: - isFinished

    @Test("isFinished when completed equals total")
    func isFinishedTrue() {
        let progress = BatchProgress(total: 5, completed: 5, latestResult: nil)
        #expect(progress.isFinished)
    }

    @Test("Not finished when completed less than total")
    func isFinishedFalse() {
        let progress = BatchProgress(total: 5, completed: 3, latestResult: nil)
        #expect(!progress.isFinished)
    }

    @Test("isFinished for empty batch")
    func isFinishedEmpty() {
        let progress = BatchProgress(total: 0, completed: 0, latestResult: nil)
        #expect(progress.isFinished)
    }

    // MARK: - Initial Progress

    @Test("Initial progress has zero completed and nil result")
    func initialProgress() {
        let progress = BatchProgress(total: 10, completed: 0, latestResult: nil)
        #expect(progress.completed == 0)
        #expect(progress.total == 10)
        #expect(progress.latestResult == nil)
        #expect(progress.fraction == 0.0)
        #expect(!progress.isFinished)
    }
}
