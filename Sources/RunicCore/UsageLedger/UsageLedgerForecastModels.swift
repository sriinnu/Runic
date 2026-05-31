import Foundation

public struct UsageLedgerSpendForecast: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let projectKey: String?
    public let projectID: String?
    public let projectName: String?
    public let observedDays: Int
    public let observedCostUSD: Double
    public let averageDailyCostUSD: Double
    public let projected30DayCostUSD: Double
    public let projectedCostP50USD: Double?
    public let projectedCostP80USD: Double?
    public let projectedCostP95USD: Double?
    public let projectionDays: Int
    public let budgetLimitUSD: Double?
    public let budgetETAInDays: Double?
    public let budgetWillBreach: Bool

    public init(
        provider: UsageProvider,
        projectKey: String? = nil,
        projectID: String? = nil,
        projectName: String? = nil,
        observedDays: Int,
        observedCostUSD: Double,
        averageDailyCostUSD: Double,
        projected30DayCostUSD: Double,
        projectedCostP50USD: Double? = nil,
        projectedCostP80USD: Double? = nil,
        projectedCostP95USD: Double? = nil,
        projectionDays: Int = 30,
        budgetLimitUSD: Double? = nil,
        budgetETAInDays: Double? = nil,
        budgetWillBreach: Bool = false)
    {
        self.provider = provider
        self.projectKey = projectKey
        self.projectID = projectID
        self.projectName = projectName
        self.observedDays = observedDays
        self.observedCostUSD = observedCostUSD
        self.averageDailyCostUSD = averageDailyCostUSD
        self.projected30DayCostUSD = projected30DayCostUSD
        self.projectedCostP50USD = projectedCostP50USD
        self.projectedCostP80USD = projectedCostP80USD
        self.projectedCostP95USD = projectedCostP95USD
        self.projectionDays = projectionDays
        self.budgetLimitUSD = budgetLimitUSD
        self.budgetETAInDays = budgetETAInDays
        self.budgetWillBreach = budgetWillBreach
    }

    public var projectedAdditionalCostUSD: Double {
        max(0, self.projected30DayCostUSD - self.observedCostUSD)
    }

    public func applyingBudget(monthlyLimitUSD: Double?) -> UsageLedgerSpendForecast {
        guard let monthlyLimitUSD, monthlyLimitUSD > 0 else {
            return UsageLedgerSpendForecast(
                provider: self.provider,
                projectKey: self.projectKey,
                projectID: self.projectID,
                projectName: self.projectName,
                observedDays: self.observedDays,
                observedCostUSD: self.observedCostUSD,
                averageDailyCostUSD: self.averageDailyCostUSD,
                projected30DayCostUSD: self.projected30DayCostUSD,
                projectedCostP50USD: self.projectedCostP50USD,
                projectedCostP80USD: self.projectedCostP80USD,
                projectedCostP95USD: self.projectedCostP95USD,
                projectionDays: self.projectionDays,
                budgetLimitUSD: nil,
                budgetETAInDays: nil,
                budgetWillBreach: false)
        }

        let willBreach = self.projected30DayCostUSD > monthlyLimitUSD
        let etaDays: Double? = {
            guard willBreach, self.averageDailyCostUSD > 0 else { return nil }
            if self.observedCostUSD >= monthlyLimitUSD { return 0 }
            let remainingBudget = monthlyLimitUSD - self.observedCostUSD
            let value = remainingBudget / self.averageDailyCostUSD
            guard value.isFinite else { return nil }
            return max(0, value)
        }()

        return UsageLedgerSpendForecast(
            provider: self.provider,
            projectKey: self.projectKey,
            projectID: self.projectID,
            projectName: self.projectName,
            observedDays: self.observedDays,
            observedCostUSD: self.observedCostUSD,
            averageDailyCostUSD: self.averageDailyCostUSD,
            projected30DayCostUSD: self.projected30DayCostUSD,
            projectedCostP50USD: self.projectedCostP50USD,
            projectedCostP80USD: self.projectedCostP80USD,
            projectedCostP95USD: self.projectedCostP95USD,
            projectionDays: self.projectionDays,
            budgetLimitUSD: monthlyLimitUSD,
            budgetETAInDays: etaDays,
            budgetWillBreach: willBreach)
    }
}
