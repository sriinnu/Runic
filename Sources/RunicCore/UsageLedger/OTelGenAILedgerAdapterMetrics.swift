import Foundation

extension OTelGenAILedgerAdapter {
    static func tokenCounts(from attributes: [String: Any]) -> TokenCounts {
        let input = max(0, self.intValue(
            for: [
                "gen_ai.usage.input_tokens",
                "gen_ai.usage.prompt_tokens",
                "gen_ai.usage.promptTokens",
                "ai.usage.promptTokens",
                "ai.usage.prompt_tokens",
                "llm.usage.prompt_tokens",
                "usage.prompt_tokens",
                "usage.input_tokens",
                "usage.promptTokens",
                "prompt_eval_count",
                "input_tokens",
                "prompt_tokens",
            ],
            in: attributes) ?? 0)
        let parsedOutput = self.intValue(
            for: [
                "gen_ai.usage.output_tokens",
                "gen_ai.usage.completion_tokens",
                "gen_ai.usage.completionTokens",
                "ai.usage.completionTokens",
                "ai.usage.completion_tokens",
                "llm.usage.completion_tokens",
                "usage.completion_tokens",
                "usage.output_tokens",
                "usage.completionTokens",
                "eval_count",
                "output_tokens",
                "completion_tokens",
            ],
            in: attributes)
        let parsedTotal = self.intValue(
            for: [
                "gen_ai.usage.total_tokens",
                "gen_ai.usage.totalTokens",
                "ai.usage.totalTokens",
                "ai.usage.total_tokens",
                "llm.usage.total_tokens",
                "usage.total_tokens",
                "usage.totalTokens",
                "total_tokens",
            ],
            in: attributes)
        let output = max(0, parsedOutput ?? parsedTotal.map { max(0, $0 - input) } ?? 0)
        let cacheCreation = max(0, self.intValue(
            for: [
                "gen_ai.usage.cache_creation_input_tokens",
                "gen_ai.usage.cache_write_tokens",
                "gen_ai.usage.cacheWriteTokens",
                "ai.usage.cacheWriteTokens",
                "usage.cache_write_tokens",
                "usage.cache_creation_input_tokens",
                "prompt_cache_miss_tokens",
                "cache_creation_tokens",
            ],
            in: attributes) ?? 0)
        let cacheRead = max(0, self.intValue(
            for: [
                "gen_ai.usage.cache_read_input_tokens",
                "gen_ai.usage.cache_read_tokens",
                "gen_ai.usage.cacheReadTokens",
                "ai.usage.cacheReadTokens",
                "usage.cache_read_tokens",
                "usage.cache_read_input_tokens",
                "prompt_cache_hit_tokens",
                "cache_read_tokens",
            ],
            in: attributes) ?? 0)
        return TokenCounts(input: input, output: output, cacheCreation: cacheCreation, cacheRead: cacheRead)
    }

    static func entryMetadata(from attributes: [String: Any]) -> EntryMetadata {
        EntryMetadata(
            timestamp: self.dateValue(
                for: [
                    "endTimeUnixNano",
                    "end_time_unix_nano",
                    "time_unix_nano",
                    "timeUnixNano",
                    "timestamp",
                    "time",
                ],
                in: attributes) ?? Date(),
            projectID: self.stringValue(for: ["gen_ai.project.id", "project.id", "project_id"], in: attributes),
            projectName: self.stringValue(
                for: ["gen_ai.project.name", "project.name", "project_name"],
                in: attributes),
            sessionID: self.stringValue(
                for: ["gen_ai.conversation.id", "session.id", "session_id", "thread.id"],
                in: attributes),
            requestID: self.stringValue(for: ["gen_ai.request.id", "request.id", "request_id", "span.id"], in: attributes),
            messageID: self.stringValue(for: ["gen_ai.message.id", "message.id", "message_id"], in: attributes),
            version: self.stringValue(for: ["gen_ai.system.version", "library.version", "sdk.version"], in: attributes))
    }

    static func operationKind(from attributes: [String: Any]) -> UsageLedgerOperationKind {
        let signals = [
            self.stringValue(
                for: [
                    "gen_ai.query.source",
                    "gen_ai.request.query_source",
                    "claude_code.query_source",
                    "claude.code.query_source",
                    "query_source",
                    "query.source",
                ],
                in: attributes),
            self.stringValue(
                for: [
                    "gen_ai.operation.name",
                    "operation.name",
                    "span.name",
                    "name",
                ],
                in: attributes),
        ]
        .compactMap { $0?.lowercased() }

        if signals.contains(where: { $0.contains("compact") || $0.contains("compaction") }) {
            return .compaction
        }
        if signals.contains(where: { $0.contains("tool") || $0.contains("function") }) {
            return .tool
        }
        return .inference
    }
}
