import Foundation

#if os(macOS)

extension CursorStatusProbe {
    func fetchWithCookieHeader(_ cookieHeader: String) async throws -> CursorStatusSnapshot {
        async let usageSummaryTask = self.fetchUsageSummary(cookieHeader: cookieHeader)
        async let userInfoTask = self.fetchUserInfo(cookieHeader: cookieHeader)

        let usageSummary = try await usageSummaryTask
        let userInfo = try? await userInfoTask

        return self.parseUsageSummary(usageSummary, userInfo: userInfo)
    }

    private func fetchUsageSummary(cookieHeader: String) async throws -> CursorUsageSummary {
        let url = self.baseURL.appendingPathComponent("/api/usage-summary")
        var request = URLRequest(url: url)
        request.timeoutInterval = self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CursorStatusProbeError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw CursorStatusProbeError.notLoggedIn
        }

        guard httpResponse.statusCode == 200 else {
            throw CursorStatusProbeError.networkError("HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(CursorUsageSummary.self, from: data)
        } catch {
            let rawJSON = String(data: data, encoding: .utf8) ?? "<binary>"
            throw CursorStatusProbeError
                .parseFailed("JSON decode failed: \(error.localizedDescription). Raw: \(rawJSON.prefix(200))")
        }
    }

    private func fetchUserInfo(cookieHeader: String) async throws -> CursorUserInfo {
        let url = self.baseURL.appendingPathComponent("/api/auth/me")
        var request = URLRequest(url: url)
        request.timeoutInterval = self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CursorStatusProbeError.networkError("Failed to fetch user info")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(CursorUserInfo.self, from: data)
    }

    func parseUsageSummary(_ summary: CursorUsageSummary, userInfo: CursorUserInfo?) -> CursorStatusSnapshot {
        let billingCycleEnd: Date? = summary.billingCycleEnd.flatMap { dateString in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
        }

        let planUsedRaw = Double(summary.individualUsage?.plan?.used ?? 0)
        let planLimitRaw = Double(summary.individualUsage?.plan?.limit ?? 0)
        let planUsed = planUsedRaw / 100.0
        let planLimit = planLimitRaw / 100.0
        let planPercentUsed: Double = if planLimitRaw > 0 {
            (planUsedRaw / planLimitRaw) * 100
        } else if let totalPercentUsed = summary.individualUsage?.plan?.totalPercentUsed {
            // The units of totalPercentUsed are ambiguous: the field name says
            // percent, but real payloads have been observed carrying a 0-1
            // fraction (e.g. 0.40625 alongside used/limit). Exactly 1.0 is
            // ambiguous both ways, and the tie DELIBERATELY breaks toward
            // "fraction": a fraction-based plan reports exactly 1.0 at the
            // moment its quota is fully used, and reading that as 1% would show
            // an exhausted plan as nearly untouched — the worst direction to
            // fail. Misreading a genuine 1%-as-1.0 as 100% merely over-warns.
            // Values above 1.0 pass through as already-scaled percents.
            totalPercentUsed <= 1 ? totalPercentUsed * 100 : totalPercentUsed
        } else {
            0
        }

        let onDemandUsed = Double(summary.individualUsage?.onDemand?.used ?? 0) / 100.0
        let onDemandLimit: Double? = summary.individualUsage?.onDemand?.limit.map { Double($0) / 100.0 }

        let teamOnDemandUsed: Double? = summary.teamUsage?.onDemand?.used.map { Double($0) / 100.0 }
        let teamOnDemandLimit: Double? = summary.teamUsage?.onDemand?.limit.map { Double($0) / 100.0 }

        return CursorStatusSnapshot(
            planPercentUsed: planPercentUsed,
            planUsedUSD: planUsed,
            planLimitUSD: planLimit,
            onDemandUsedUSD: onDemandUsed,
            onDemandLimitUSD: onDemandLimit,
            teamOnDemandUsedUSD: teamOnDemandUsed,
            teamOnDemandLimitUSD: teamOnDemandLimit,
            billingCycleEnd: billingCycleEnd,
            membershipType: summary.membershipType,
            accountEmail: userInfo?.email,
            accountName: userInfo?.name,
            rawJSON: nil)
    }
}

#endif
