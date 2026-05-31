import Foundation

#if os(macOS)
extension MiniMaxWebUsageFetcher {
    func resolveSessions(logger: @escaping (String) -> Void) -> [MiniMaxWebSession] {
        var sessions: [MiniMaxWebSession] = []
        let fallbackGroupID = ProviderTokenResolver.minimaxGroupID()

        if let manual = self.manualSession() {
            let resolved = MiniMaxWebSession(
                cookieHeader: manual.cookieHeader,
                accessToken: manual.accessToken,
                groupID: manual.groupID ?? fallbackGroupID,
                sourceLabel: manual.sourceLabel,
                isManual: true)
            sessions.append(resolved)
        }

        let tokenCandidates = MiniMaxLocalStorageImporter.importTokens(logger: logger)
        let cookieSessions = MiniMaxCookieImporter.importSessions(logger: logger)

        for cookieSession in cookieSessions {
            if tokenCandidates.isEmpty {
                sessions.append(MiniMaxWebSession(
                    cookieHeader: cookieSession.cookieHeader,
                    accessToken: nil,
                    groupID: fallbackGroupID,
                    sourceLabel: cookieSession.sourceLabel,
                    isManual: false))
                continue
            }

            for token in tokenCandidates {
                sessions.append(MiniMaxWebSession(
                    cookieHeader: cookieSession.cookieHeader,
                    accessToken: token.accessToken,
                    groupID: token.groupID ?? fallbackGroupID,
                    sourceLabel: "\(cookieSession.sourceLabel)",
                    isManual: false))
            }

            sessions.append(MiniMaxWebSession(
                cookieHeader: cookieSession.cookieHeader,
                accessToken: nil,
                groupID: fallbackGroupID,
                sourceLabel: cookieSession.sourceLabel,
                isManual: false))
        }

        if sessions.isEmpty {
            logger("No MiniMax cookie sessions found.")
        }

        return sessions
    }

    private func manualSession() -> MiniMaxWebSession? {
        guard let resolution = ProviderTokenResolver.minimaxCookieHeaderResolution(),
              let parsed = MiniMaxWebParsing.parseManualInput(resolution.token)
        else {
            return nil
        }

        let label = resolution.source == .environment ? "manual (env)" : "manual"
        return MiniMaxWebSession(
            cookieHeader: parsed.cookieHeader,
            accessToken: parsed.accessToken,
            groupID: parsed.groupID,
            sourceLabel: label,
            isManual: true)
    }
}
#endif
