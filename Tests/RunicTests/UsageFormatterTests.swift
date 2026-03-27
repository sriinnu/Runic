import Foundation
import RunicCore
import Testing
@testable import Runic

struct UsageFormatterTests {
    @Test
    func `formats usage line`() {
        let line = UsageFormatter.usageLine(remaining: 25, used: 75)
        #expect(line == "25% left")
    }

    @Test
    func `relative updated recent`() {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let text = UsageFormatter.updatedString(from: fiveHoursAgo, now: now)
        #expect(text.contains("Updated"))
        // Check for relative time format (varies by locale: "ago" in English, "전" in Korean, etc.)
        #expect(text.contains("5") || text.lowercased().contains("hour") || text.contains("시간"))
    }

    @Test
    func `absolute updated old`() {
        let now = Date()
        let dayAgo = now.addingTimeInterval(-26 * 3600)
        let text = UsageFormatter.updatedString(from: dayAgo, now: now)
        #expect(text.contains("Updated"))
        #expect(!text.contains("ago"))
    }

    @Test
    func `reset countdown minutes`() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(10 * 60 + 1)
        #expect(UsageFormatter.resetCountdownDescription(from: reset, now: now) == "in 11m")
    }

    @Test
    func `reset countdown hours and minutes`() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(3 * 3600 + 31 * 60)
        #expect(UsageFormatter.resetCountdownDescription(from: reset, now: now) == "in 3h 31m")
    }

    @Test
    func `reset countdown days and hours`() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval((26 * 3600) + 10)
        #expect(UsageFormatter.resetCountdownDescription(from: reset, now: now) == "in 1d 2h")
    }

    @Test
    func `reset countdown exact hour`() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(60 * 60)
        #expect(UsageFormatter.resetCountdownDescription(from: reset, now: now) == "in 1h")
    }

    @Test
    func `reset countdown past date`() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let reset = now.addingTimeInterval(-10)
        #expect(UsageFormatter.resetCountdownDescription(from: reset, now: now) == "now")
    }

    @Test
    func `model display name strips trailing dates`() {
        #expect(UsageFormatter.modelDisplayName("claude-opus-4-5-20251101") == "claude-opus-4-5")
        #expect(UsageFormatter.modelDisplayName("gpt-4o-2024-08-06") == "gpt-4o")
        #expect(UsageFormatter.modelDisplayName("Claude Opus 4.5 2025 1101") == "Claude Opus 4.5")
        #expect(UsageFormatter.modelDisplayName("claude-sonnet-4-5") == "claude-sonnet-4-5")
    }

    @Test
    func `clean plan maps O auth to ollama`() {
        #expect(UsageFormatter.cleanPlanName("oauth") == "Ollama")
    }

    @Test
    func `model context from known model`() {
        #expect(UsageFormatter.modelContextLabel(for: "gpt-4o") == "ctx 128K")
        #expect(UsageFormatter.modelContextLabel(for: "claude-opus-4-5") == "ctx 200K")
        #expect(UsageFormatter.modelContextLabel(for: "gpt-5") == "ctx 400K")
        #expect(UsageFormatter.modelContextLabel(for: "gpt-5.2") == "ctx 400K")
        #expect(UsageFormatter.modelContextLabel(for: "claude-opus-4-6") == "ctx 1M")
        #expect(UsageFormatter.modelContextLabel(for: "claude-sonnet-4-6") == "ctx 1M")
    }

    @Test
    func `model context from name suffix`() {
        #expect(UsageFormatter.modelContextWindow(for: "qwen2.5-128k-instruct") == 128_000)
        #expect(UsageFormatter.modelContextLabel(for: "provider/qwen2.5-2m-long-context") == "ctx 2M")
    }

    @Test
    func `model context unknown returns nil`() {
        #expect(UsageFormatter.modelContextWindow(for: "unknown-custom-model-v1") == nil)
    }

    @Test
    func `token summary includes breakdown`() {
        let totals = UsageLedgerTotals(
            inputTokens: 1000,
            outputTokens: 200,
            cacheCreationTokens: 300,
            cacheReadTokens: 50,
            costUSD: nil)
        #expect(UsageFormatter.tokenSummaryString(totals) == "1.6K tok (in 1K, out 200, cache 350)")
    }
}
