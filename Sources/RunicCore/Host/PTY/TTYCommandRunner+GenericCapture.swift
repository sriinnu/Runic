#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

extension TTYCommandRunner {
    struct GenericCaptureRequest {
        let context: PTYRunContext
        let trimmedScript: String
        let options: Options
        let deadline: Date
    }

    struct GenericSendNeedle {
        let needle: Data
        let needleString: String
        let keys: Data
    }

    struct GenericCaptureState {
        var scanBuffer: RollingBuffer
        var nextCursorCheckAt = Date(timeIntervalSince1970: 0)
        var lastEnter = Date()
        var stoppedEarly = false
        var urlSeen = false
        var triggeredSends = Set<Data>()
        var recentText = ""
        var lastOutputAt = Date()

        init(maxNeedle: Int) {
            self.scanBuffer = RollingBuffer(maxNeedle: maxNeedle)
        }
    }

    static let cursorQuery = Data([0x1B, 0x5B, 0x36, 0x6E])

    static func captureGeneric(
        _ request: GenericCaptureRequest,
        onURLDetected: (@Sendable () -> Void)?) throws -> Result
    {
        let context = request.context
        if !request.trimmedScript.isEmpty {
            try context.send(request.trimmedScript)
            try context.send("\r")
        }

        let stopNeedles = request.options.stopOnSubstrings.map { Data($0.utf8) }
        let sendNeedles = request.options.sendOnSubstrings.map {
            GenericSendNeedle(needle: Data($0.key.utf8), needleString: $0.key, keys: Data($0.value.utf8))
        }
        let urlNeedles = [Data("https://".utf8), Data("http://".utf8)]
        var state = GenericCaptureState(maxNeedle: Self.genericMaxNeedle(
            stopNeedles: stopNeedles,
            sendNeedles: sendNeedles,
            urlNeedles: urlNeedles))

        while Date() < request.deadline {
            let newData = context.readChunk()
            Self.updateRecentText(newData, state: &state)
            let scanData = state.scanBuffer.append(newData)
            Self.respondToCursorQuery(context: context, scanData: scanData, nextCheckAt: &state.nextCursorCheckAt)
            Self.triggerConfiguredSends(context: context, sendNeedles: sendNeedles, scanData: scanData, state: &state)

            if Self.updateURLState(
                scanData: scanData,
                urlNeedles: urlNeedles,
                stopOnURL: request.options.stopOnURL,
                state: &state,
                onURLDetected: onURLDetected)
            {
                break
            }
            if Self.shouldStopGeneric(
                scanData: scanData,
                stopNeedles: stopNeedles,
                idleTimeout: request.options.idleTimeout,
                context: context,
                state: &state)
            {
                break
            }
            Self.sendEnterIfNeeded(context: context, options: request.options, state: &state)
            if !context.proc.isRunning { break }
            usleep(60000)
        }

        _ = context.readChunk()
        if state.stoppedEarly {
            Self.settleGenericCapture(context: context, state: &state, request: request)
        }

        let text = String(data: context.buffer, encoding: .utf8) ?? ""
        guard !text.isEmpty else { throw Error.timedOut }
        return Result(text: text)
    }

    static func genericMaxNeedle(
        stopNeedles: [Data],
        sendNeedles: [GenericSendNeedle],
        urlNeedles: [Data]) -> Int
    {
        let needleLengths =
            stopNeedles.map(\.count) +
            sendNeedles.map(\.needle.count) +
            urlNeedles.map(\.count) +
            [Self.cursorQuery.count]
        return needleLengths.max() ?? Self.cursorQuery.count
    }

    static func updateRecentText(_ newData: Data, state: inout GenericCaptureState) {
        guard !newData.isEmpty else { return }
        state.lastOutputAt = Date()
        if let chunkText = String(bytes: newData, encoding: .utf8) {
            state.recentText += chunkText
            if state.recentText.count > 8192 {
                state.recentText.removeFirst(state.recentText.count - 8192)
            }
        }
    }

    static func respondToCursorQuery(
        context: PTYRunContext,
        scanData: Data,
        nextCheckAt: inout Date,
        interval: TimeInterval = 1.0)
    {
        guard Date() >= nextCheckAt,
              !scanData.isEmpty,
              scanData.range(of: Self.cursorQuery) != nil else { return }
        try? context.send("\u{1b}[1;1R")
        nextCheckAt = Date().addingTimeInterval(interval)
    }

    static func triggerConfiguredSends(
        context: PTYRunContext,
        sendNeedles: [GenericSendNeedle],
        scanData: Data,
        state: inout GenericCaptureState)
    {
        guard !sendNeedles.isEmpty else { return }
        let recentTextCollapsed = state.recentText.replacingOccurrences(of: "\r", with: "")
        for item in sendNeedles where !state.triggeredSends.contains(item.needle) {
            let matched = scanData.range(of: item.needle) != nil ||
                state.recentText.contains(item.needleString) ||
                recentTextCollapsed.contains(item.needleString)
            guard matched else { continue }
            if let keysString = String(data: item.keys, encoding: .utf8) {
                try? context.send(keysString)
            } else {
                try? context.writeAllToPrimary(item.keys)
            }
            state.triggeredSends.insert(item.needle)
        }
    }

    static func updateURLState(
        scanData: Data,
        urlNeedles: [Data],
        stopOnURL: Bool,
        state: inout GenericCaptureState,
        onURLDetected: (@Sendable () -> Void)?) -> Bool
    {
        guard urlNeedles.contains(where: { scanData.range(of: $0) != nil }) else { return false }
        state.urlSeen = true
        onURLDetected?()
        guard stopOnURL else { return false }
        state.stoppedEarly = true
        return true
    }

    static func shouldStopGeneric(
        scanData: Data,
        stopNeedles: [Data],
        idleTimeout: TimeInterval?,
        context: PTYRunContext,
        state: inout GenericCaptureState) -> Bool
    {
        if !stopNeedles.isEmpty, stopNeedles.contains(where: { scanData.range(of: $0) != nil }) {
            state.stoppedEarly = true
            return true
        }
        if let idleTimeout,
           !context.buffer.isEmpty,
           Date().timeIntervalSince(state.lastOutputAt) >= idleTimeout
        {
            state.stoppedEarly = true
            return true
        }
        return false
    }

    static func sendEnterIfNeeded(context: PTYRunContext, options: Options, state: inout GenericCaptureState) {
        guard !state.urlSeen,
              let every = options.sendEnterEvery,
              Date().timeIntervalSince(state.lastEnter) >= every else { return }
        try? context.send("\r")
        state.lastEnter = Date()
    }

    static func settleGenericCapture(
        context: PTYRunContext,
        state: inout GenericCaptureState,
        request: GenericCaptureRequest)
    {
        let settle = max(0, min(request.options.settleAfterStop, request.deadline.timeIntervalSinceNow))
        guard settle > 0 else { return }
        let settleDeadline = Date().addingTimeInterval(settle)
        while Date() < settleDeadline {
            let scanData = state.scanBuffer.append(context.readChunk())
            Self.respondToCursorQuery(context: context, scanData: scanData, nextCheckAt: &state.nextCursorCheckAt)
            usleep(50000)
        }
    }
}
