import Foundation
import Testing
@testable import RunicCLI

struct CLIProgressBarTests {
    @Test
    func `progress bar counts clamp to bar width`() {
        #expect(RunicCLI.progressBarCounts(usedPercent: 0, width: 20) == (0, 20))
        #expect(RunicCLI.progressBarCounts(usedPercent: 100, width: 20) == (20, 0))
        #expect(RunicCLI.progressBarCounts(usedPercent: 110, width: 20) == (20, 0))
        #expect(RunicCLI.progressBarCounts(usedPercent: -5, width: 20) == (0, 20))
    }

    @Test
    func `progress bar counts stay proportional in range`() {
        #expect(RunicCLI.progressBarCounts(usedPercent: 50, width: 20) == (10, 10))
        #expect(RunicCLI.progressBarCounts(usedPercent: 12, width: 20) == (2, 18))
    }

    @Test
    func `enhanced usage progress bar does not crash on out of range percents`() {
        for used in [0.0, 100.0, 110.0, -5.0] {
            let bar = EnhancedUsageCommand.progressBar(used: used, width: 20, useColor: false)
            #expect(bar.count == 22) // 20 cells plus brackets
        }
        #expect(EnhancedUsageCommand.progressBar(used: 110, width: 20, useColor: false) == "[████████████████████]")
        #expect(EnhancedUsageCommand.progressBar(used: -5, width: 20, useColor: false) == "[░░░░░░░░░░░░░░░░░░░░]")
    }
}
