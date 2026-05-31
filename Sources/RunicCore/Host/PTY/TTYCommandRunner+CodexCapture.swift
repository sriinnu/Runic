#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

extension TTYCommandRunner {
    struct CodexCaptureRequest {
        let context: PTYRunContext
        let script: String
        let deadline: Date
        let delayInitialSend: Bool
    }

    struct CodexCaptureState {
        var skippedUpdate = false
        var sentScript: Bool
        var updateSkipAttempts = 0
        var lastEnter = Date(timeIntervalSince1970: 0)
        var scriptSentAt: Date?
        var resendStatusRetries = 0
        var enterRetries = 0
        var sawStatus = false
        var sawUpdatePrompt = false
        var statusScanBuffer: RollingBuffer
        var updateScanBuffer: RollingBuffer
        var nextCursorCheckAt = Date(timeIntervalSince1970: 0)

        init(sentScript: Bool, statusMaxNeedle: Int, updateMaxNeedle: Int) {
            self.sentScript = sentScript
            self.scriptSentAt = sentScript ? Date() : nil
            self.statusScanBuffer = RollingBuffer(maxNeedle: statusMaxNeedle)
            self.updateScanBuffer = RollingBuffer(maxNeedle: updateMaxNeedle)
        }
    }

    static func captureCodex(_ request: CodexCaptureRequest) throws -> Result {
        let context = request.context
        if !request.delayInitialSend {
            try Self.sendInitialCodexScript(context: context, script: request.script)
        }

        let statusMarkers = Self.codexStatusMarkers()
        let updateNeedlesLower = Self.codexUpdateNeedles()
        var state = CodexCaptureState(
            sentScript: !request.delayInitialSend,
            statusMaxNeedle: Self.statusMaxNeedle(statusMarkers),
            updateMaxNeedle: Self.updateMaxNeedle(updateNeedlesLower))

        while Date() < request.deadline {
            let newData = context.readChunk()
            let scanData = state.statusScanBuffer.append(newData)
            Self.respondToCursorQuery(context: context, scanData: scanData, nextCheckAt: &state.nextCursorCheckAt)
            Self.detectCodexStatus(scanData: scanData, statusMarkers: statusMarkers, state: &state)
            Self.detectCodexUpdatePrompt(newData: newData, needles: updateNeedlesLower, state: &state)
            Self.skipCodexUpdatePromptIfNeeded(context: context, state: &state)

            if Self.sendCodexScriptIfNeeded(context: context, request: request, state: &state) { continue }
            if Self.nudgeCodexStatusIfNeeded(context: context, state: &state) { continue }
            if state.sawStatus { break }
            usleep(120_000)
        }

        if state.sawStatus {
            Self.settleCodexStatus(context: context, state: &state)
        }

        guard let text = String(data: context.buffer, encoding: .utf8), !text.isEmpty else {
            throw Error.timedOut
        }
        return Result(text: text)
    }

    static func sendInitialCodexScript(context: PTYRunContext, script: String) throws {
        try context.send(script)
        try context.send("\r")
        usleep(150_000)
        try context.send("\r")
        try context.send("\u{1b}")
    }

    static func codexStatusMarkers() -> [Data] {
        [
            "Credits:",
            "5h limit",
            "5-hour limit",
            "Weekly limit",
        ].map { Data($0.utf8) }
    }

    static func codexUpdateNeedles() -> [Data] {
        ["Update available!", "Run bun install -g @openai/codex", "0.60.1 ->"]
            .map { Data($0.lowercased().utf8) }
    }

    static func statusMaxNeedle(_ markers: [Data]) -> Int {
        ([cursorQuery.count] + markers.map(\.count)).max() ?? cursorQuery.count
    }

    static func updateMaxNeedle(_ needles: [Data]) -> Int {
        needles.map(\.count).max() ?? 0
    }

    static func detectCodexStatus(
        scanData: Data,
        statusMarkers: [Data],
        state: inout CodexCaptureState)
    {
        guard !scanData.isEmpty, !state.sawStatus else { return }
        if statusMarkers.contains(where: { scanData.range(of: $0) != nil }) {
            state.sawStatus = true
        }
    }

    static func detectCodexUpdatePrompt(
        newData: Data,
        needles: [Data],
        state: inout CodexCaptureState)
    {
        guard !state.skippedUpdate, !state.sawUpdatePrompt, !newData.isEmpty else { return }
        let lowerScan = state.updateScanBuffer.append(Self.lowercasedASCII(newData))
        if needles.contains(where: { lowerScan.range(of: $0) != nil }) {
            state.sawUpdatePrompt = true
        }
    }

    static func skipCodexUpdatePromptIfNeeded(context: PTYRunContext, state: inout CodexCaptureState) {
        guard !state.skippedUpdate, state.sawUpdatePrompt else { return }
        try? context.send("\u{1b}[B")
        usleep(120_000)
        try? context.send("\r")
        usleep(150_000)
        try? context.send("\r")
        try? context.send("/status")
        try? context.send("\r")
        state.updateSkipAttempts += 1

        guard state.updateSkipAttempts >= 1 else { return }
        state.skippedUpdate = true
        state.sentScript = false
        state.scriptSentAt = nil
        context.buffer.removeAll()
        state.statusScanBuffer.reset()
        state.updateScanBuffer.reset()
        state.sawStatus = false
        usleep(300_000)
    }

    static func sendCodexScriptIfNeeded(
        context: PTYRunContext,
        request: CodexCaptureRequest,
        state: inout CodexCaptureState) -> Bool
    {
        guard !state.sentScript, !state.sawUpdatePrompt || state.skippedUpdate else { return false }
        try? context.send(request.script)
        try? context.send("\r")
        state.sentScript = true
        state.scriptSentAt = Date()
        state.lastEnter = Date()
        usleep(200_000)
        return true
    }

    static func nudgeCodexStatusIfNeeded(
        context: PTYRunContext,
        state: inout CodexCaptureState) -> Bool
    {
        guard state.sentScript, !state.sawStatus else { return false }
        if Date().timeIntervalSince(state.lastEnter) >= 1.2, state.enterRetries < 6 {
            try? context.send("\r")
            state.enterRetries += 1
            state.lastEnter = Date()
            usleep(120_000)
            return true
        }
        if self.resendCodexStatusIfNeeded(context: context, state: &state) {
            return true
        }
        return false
    }

    static func resendCodexStatusIfNeeded(
        context: PTYRunContext,
        state: inout CodexCaptureState) -> Bool
    {
        guard let sentAt = state.scriptSentAt,
              Date().timeIntervalSince(sentAt) >= 3.0,
              state.resendStatusRetries < 2 else { return false }
        try? context.send("/status")
        try? context.send("\r")
        state.resendStatusRetries += 1
        context.buffer.removeAll()
        state.statusScanBuffer.reset()
        state.updateScanBuffer.reset()
        state.sawStatus = false
        state.scriptSentAt = Date()
        state.lastEnter = Date()
        usleep(220_000)
        return true
    }

    static func settleCodexStatus(context: PTYRunContext, state: inout CodexCaptureState) {
        let settleDeadline = Date().addingTimeInterval(2.0)
        while Date() < settleDeadline {
            let scanData = state.statusScanBuffer.append(context.readChunk())
            Self.respondToCursorQuery(context: context, scanData: scanData, nextCheckAt: &state.nextCursorCheckAt)
            usleep(100_000)
        }
    }
}
