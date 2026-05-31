import Foundation
import RunicCore

extension UsageStore {
    nonisolated func trackLatency(
        provider: UsageProvider,
        providerLabel: String? = nil,
        requestID: String,
        startTime: Date,
        endTime: Date,
        success: Bool) async
    {
        guard let storage = self.performanceStorage else { return }
        guard Self.localPerformanceTrackingEnabled() else { return }

        let metric = LatencyMetric(
            id: UUID().uuidString,
            requestID: requestID,
            provider: provider,
            providerLabel: providerLabel,
            model: nil,
            startTime: startTime,
            endTime: endTime,
            durationMs: Int(endTime.timeIntervalSince(startTime) * 1000),
            success: success,
            createdAt: Date())

        try? await storage.save(latency: metric)
    }

    nonisolated func trackError(provider: UsageProvider, providerLabel: String? = nil, error: Error) async {
        guard let storage = self.performanceStorage else { return }
        guard Self.localPerformanceTrackingEnabled() else { return }

        let errorType = self.classifyError(error)
        let errorEvent = ErrorEvent(
            id: UUID().uuidString,
            provider: provider,
            providerLabel: providerLabel,
            errorType: errorType,
            errorMessage: error.localizedDescription,
            retryCount: 0,
            timestamp: Date())

        try? await storage.save(error: errorEvent)
    }

    nonisolated static func customProviderMetricLabel(_ config: CustomProviderConfig) -> String {
        let raw = config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? config.id
            : config.name
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}._-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        return "custom:\(normalized.isEmpty ? config.id : normalized)"
    }

    private nonisolated static func localPerformanceTrackingEnabled() -> Bool {
        (UserDefaults.standard.object(forKey: "performanceTrackingEnabled") as? Bool) ?? true
    }

    private nonisolated func classifyError(_ error: Error) -> ErrorType {
        let message = error.localizedDescription.lowercased()

        if message.contains("timed out") || message.contains("timeout") {
            return .timeout
        }

        if message.contains("quota") || message.contains("rate limit") || message.contains("429") {
            return .quota
        }

        if message.contains("auth") || message.contains("unauthorized") ||
            message.contains("401") || message.contains("403")
        {
            return .auth
        }

        if message.contains("network") || message.contains("connection") ||
            message.contains("offline") || message.contains("no internet")
        {
            return .network
        }

        if message.contains("json") || message.contains("decode") || message.contains("parse") {
            return .parsing
        }

        if message.contains("api") || message.contains("server") {
            return .apiError
        }

        return .unknown
    }
}
