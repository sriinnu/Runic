import Foundation

extension OTelGenAILedgerAdapter {
    static func parseResourceSpans(
        _ resourceSpans: [Any],
        options: OTelGenAIIngestionOptions) -> [UsageLedgerEntry]
    {
        var entries: [UsageLedgerEntry] = []

        for resourceSpanAny in resourceSpans {
            guard let resourceSpan = resourceSpanAny as? [String: Any] else { continue }
            let resourceAttributes = self.parseAttributesPayload(resourceSpan["resource"])

            let scopeSpans = (resourceSpan["scopeSpans"] as? [Any]) ?? []
            for scopeSpanAny in scopeSpans {
                guard let scopeSpan = scopeSpanAny as? [String: Any] else { continue }
                let spans = (scopeSpan["spans"] as? [Any]) ?? []
                for spanAny in spans {
                    guard let span = spanAny as? [String: Any] else { continue }
                    let spanAttributes = self.parseAttributesPayload(span["attributes"])
                    var merged: [String: Any] = resourceAttributes
                    merged.merge(spanAttributes, uniquingKeysWith: { _, rhs in rhs })

                    if let name = span["name"] as? String, !name.isEmpty {
                        merged["operation.name"] = name
                    }
                    if let end = span["endTimeUnixNano"] {
                        merged["endTimeUnixNano"] = end
                    }
                    if let start = span["startTimeUnixNano"] {
                        merged["startTimeUnixNano"] = start
                    }
                    if let traceID = span["traceId"] as? String, !traceID.isEmpty {
                        merged["trace.id"] = traceID
                    }
                    if let spanID = span["spanId"] as? String, !spanID.isEmpty {
                        merged["span.id"] = spanID
                    }

                    if let entry = self.makeLedgerEntry(from: merged, options: options) {
                        entries.append(entry)
                    }
                }
            }
        }

        return entries
    }

    static func parseFlatRecord(
        _ record: [String: Any],
        options: OTelGenAIIngestionOptions) -> UsageLedgerEntry?
    {
        var attributes = self.parseAttributesPayload(record["attributes"])
        for (key, value) in record {
            if attributes[key] == nil, self.isScalar(value) {
                attributes[key] = value
            }
        }

        if let resource = record["resource"] as? [String: Any] {
            let resourceAttributes = self.parseAttributesPayload(resource["attributes"])
            attributes.merge(resourceAttributes, uniquingKeysWith: { lhs, _ in lhs })
        }

        return self.makeLedgerEntry(from: attributes, options: options)
    }

    static func makeLedgerEntry(
        from attributes: [String: Any],
        options: OTelGenAIIngestionOptions) -> UsageLedgerEntry?
    {
        let model = self.stringValue(
            for: [
                "gen_ai.request.model",
                "gen_ai.response.model",
                "llm.model",
                "ai.model",
                "model",
            ],
            in: attributes)

        let provider = self.resolvedProvider(model: model, attributes: attributes, options: options)
        guard let provider else { return nil }

        let tokens = self.tokenCounts(from: attributes)
        let metadata = self.entryMetadata(from: attributes)
        let costUSD = self.doubleValue(
            for: [
                "gen_ai.usage.cost",
                "gen_ai.usage.cost_usd",
                "gen_ai.usage.costUSD",
                "ai.usage.costUSD",
                "ai.usage.cost_usd",
                "usage.cost",
                "usage.cost_usd",
                "usage.costUSD",
                "cost.usd",
                "cost_usd",
                "total_cost",
            ],
            in: attributes)
        let operationKind = self.operationKind(from: attributes)

        return UsageLedgerEntry(
            provider: provider,
            timestamp: metadata.timestamp,
            sessionID: metadata.sessionID,
            projectID: metadata.projectID,
            projectName: metadata.projectName,
            model: model,
            inputTokens: tokens.input,
            outputTokens: tokens.output,
            cacheCreationTokens: tokens.cacheCreation,
            cacheReadTokens: tokens.cacheRead,
            costUSD: costUSD,
            requestID: metadata.requestID,
            messageID: metadata.messageID,
            version: metadata.version,
            source: options.source,
            operationKind: operationKind,
            tokenProvenance: MetricProvenance(
                confidence: .providerReported,
                source: .openTelemetry,
                detail: "GenAI token usage attributes"),
            costProvenance: costUSD == nil ? nil : MetricProvenance(
                confidence: .providerReported,
                source: .openTelemetry,
                detail: "GenAI cost attribute"))
    }
}
