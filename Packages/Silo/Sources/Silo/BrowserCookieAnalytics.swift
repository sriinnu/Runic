import Foundation

public struct BrowserCookieSameSiteCounts: Sendable {
    public let lax: Int
    public let strict: Int
    public let none: Int
    public let unspecified: Int

    public init(lax: Int, strict: Int, none: Int, unspecified: Int) {
        self.lax = lax
        self.strict = strict
        self.none = none
        self.unspecified = unspecified
    }
}

public struct BrowserCookieDomainCount: Sendable, Hashable {
    public let domain: String
    public let count: Int

    public init(domain: String, count: Int) {
        self.domain = domain
        self.count = count
    }
}

public struct BrowserCookieAnalytics: Sendable {
    public let totalCount: Int
    public let uniqueDomainCount: Int
    public let sessionCount: Int
    public let persistentCount: Int
    public let secureCount: Int
    public let httpOnlyCount: Int
    public let hostOnlyCount: Int
    public let partitionedCount: Int
    public let samePartyCount: Int
    public let expiredCount: Int
    public let expiringSoonCount: Int
    public let sameSiteCounts: BrowserCookieSameSiteCounts
    public let topDomains: [BrowserCookieDomainCount]
    public let earliestExpiry: Date?
    public let latestExpiry: Date?

    public init(
        records: [BrowserCookieRecord],
        referenceDate: Date = Date(),
        expiringSoonInterval: TimeInterval = 7 * 24 * 60 * 60,
        topDomainLimit: Int = 10)
    {
        self.totalCount = records.count

        var sessionCount = 0
        var secureCount = 0
        var httpOnlyCount = 0
        var hostOnlyCount = 0
        var partitionedCount = 0
        var samePartyCount = 0
        var expiredCount = 0
        var expiringSoonCount = 0
        var earliestExpiry: Date?
        var latestExpiry: Date?

        var sameSiteLax = 0
        var sameSiteStrict = 0
        var sameSiteNone = 0
        var sameSiteUnspecified = 0

        var domainCounts: [String: Int] = [:]
        var uniqueDomains: Set<String> = []

        let expiringCutoff = expiringSoonInterval > 0
            ? referenceDate.addingTimeInterval(expiringSoonInterval)
            : referenceDate

        for record in records {
            let domain = record.domain.lowercased()
            domainCounts[domain, default: 0] += 1
            uniqueDomains.insert(domain)

            if record.isSession {
                sessionCount += 1
            }
            if record.isSecure {
                secureCount += 1
            }
            if record.isHTTPOnly {
                httpOnlyCount += 1
            }
            if record.isHostOnly {
                hostOnlyCount += 1
            }
            if record.partitionKey != nil {
                partitionedCount += 1
            }
            if record.isSameParty == true {
                samePartyCount += 1
            }

            switch record.sameSite {
            case .some(.lax):
                sameSiteLax += 1
            case .some(.strict):
                sameSiteStrict += 1
            case .some(.none):
                sameSiteNone += 1
            case nil:
                sameSiteUnspecified += 1
            }

            if let expires = record.expires {
                if expires < referenceDate {
                    expiredCount += 1
                } else if expiringSoonInterval > 0 && expires <= expiringCutoff {
                    expiringSoonCount += 1
                }

                if let currentEarliest = earliestExpiry {
                    if expires < currentEarliest {
                        earliestExpiry = expires
                    }
                } else {
                    earliestExpiry = expires
                }

                if let currentLatest = latestExpiry {
                    if expires > currentLatest {
                        latestExpiry = expires
                    }
                } else {
                    latestExpiry = expires
                }
            }
        }

        self.sessionCount = sessionCount
        self.persistentCount = records.count - sessionCount
        self.secureCount = secureCount
        self.httpOnlyCount = httpOnlyCount
        self.hostOnlyCount = hostOnlyCount
        self.partitionedCount = partitionedCount
        self.samePartyCount = samePartyCount
        self.expiredCount = expiredCount
        self.expiringSoonCount = expiringSoonCount
        self.sameSiteCounts = BrowserCookieSameSiteCounts(
            lax: sameSiteLax,
            strict: sameSiteStrict,
            none: sameSiteNone,
            unspecified: sameSiteUnspecified)
        self.uniqueDomainCount = uniqueDomains.count
        self.earliestExpiry = earliestExpiry
        self.latestExpiry = latestExpiry

        if topDomainLimit > 0 {
            let sorted = domainCounts
                .map { BrowserCookieDomainCount(domain: $0.key, count: $0.value) }
                .sorted {
                    if $0.count == $1.count {
                        return $0.domain < $1.domain
                    }
                    return $0.count > $1.count
                }
            self.topDomains = Array(sorted.prefix(topDomainLimit))
        } else {
            self.topDomains = []
        }
    }
}

public struct BrowserCookieIdentity: Sendable, Hashable {
    public let domain: String
    public let name: String
    public let path: String
    public let partitionKey: String?
    public let isHostOnly: Bool

    public init(
        domain: String,
        name: String,
        path: String,
        partitionKey: String?,
        isHostOnly: Bool)
    {
        self.domain = domain.lowercased()
        self.name = name
        self.path = path
        self.partitionKey = partitionKey
        self.isHostOnly = isHostOnly
    }

    public init(record: BrowserCookieRecord) {
        self.init(
            domain: record.domain,
            name: record.name,
            path: record.path,
            partitionKey: record.partitionKey,
            isHostOnly: record.isHostOnly)
    }

    var sortKey: String {
        "\(self.domain)|\(self.path)|\(self.name)|\(self.partitionKey ?? "")|\(self.isHostOnly)"
    }
}

public struct BrowserCookieSyncComparison: Sendable {
    public var includeCreatedAt: Bool
    public var includeLastAccessedAt: Bool

    public init(includeCreatedAt: Bool = false, includeLastAccessedAt: Bool = false) {
        self.includeCreatedAt = includeCreatedAt
        self.includeLastAccessedAt = includeLastAccessedAt
    }

    public static let strict = BrowserCookieSyncComparison(includeCreatedAt: true, includeLastAccessedAt: true)
}

public struct BrowserCookieSyncUpdate: Sendable {
    public let identity: BrowserCookieIdentity
    public let existing: BrowserCookieRecord
    public let incoming: BrowserCookieRecord

    public init(identity: BrowserCookieIdentity, existing: BrowserCookieRecord, incoming: BrowserCookieRecord) {
        self.identity = identity
        self.existing = existing
        self.incoming = incoming
    }
}

public struct BrowserCookieSyncCollision: Sendable {
    public let identity: BrowserCookieIdentity
    public let existing: [BrowserCookieRecord]
    public let incoming: [BrowserCookieRecord]

    public init(identity: BrowserCookieIdentity, existing: [BrowserCookieRecord], incoming: [BrowserCookieRecord]) {
        self.identity = identity
        self.existing = existing
        self.incoming = incoming
    }
}

public struct BrowserCookieSyncPlan: Sendable {
    public let additions: [BrowserCookieRecord]
    public let deletions: [BrowserCookieRecord]
    public let updates: [BrowserCookieSyncUpdate]
    public let unchanged: [BrowserCookieRecord]
    public let collisions: [BrowserCookieSyncCollision]

    public init(
        additions: [BrowserCookieRecord],
        deletions: [BrowserCookieRecord],
        updates: [BrowserCookieSyncUpdate],
        unchanged: [BrowserCookieRecord],
        collisions: [BrowserCookieSyncCollision])
    {
        self.additions = additions
        self.deletions = deletions
        self.updates = updates
        self.unchanged = unchanged
        self.collisions = collisions
    }

    public var hasChanges: Bool {
        !self.additions.isEmpty || !self.deletions.isEmpty || !self.updates.isEmpty || !self.collisions.isEmpty
    }
}

public enum BrowserCookieSync {
    public static func plan(
        existing: [BrowserCookieRecord],
        incoming: [BrowserCookieRecord],
        comparison: BrowserCookieSyncComparison = BrowserCookieSyncComparison()) -> BrowserCookieSyncPlan
    {
        let existingBuckets = Dictionary(grouping: existing, by: BrowserCookieIdentity.init(record:))
        let incomingBuckets = Dictionary(grouping: incoming, by: BrowserCookieIdentity.init(record:))
        let identities = Set(existingBuckets.keys).union(incomingBuckets.keys)

        var additions: [BrowserCookieRecord] = []
        var deletions: [BrowserCookieRecord] = []
        var updates: [BrowserCookieSyncUpdate] = []
        var unchanged: [BrowserCookieRecord] = []
        var collisions: [BrowserCookieSyncCollision] = []

        for identity in identities {
            let existingRecords = existingBuckets[identity] ?? []
            let incomingRecords = incomingBuckets[identity] ?? []

            if existingRecords.count > 1 || incomingRecords.count > 1 {
                collisions.append(
                    BrowserCookieSyncCollision(
                        identity: identity,
                        existing: existingRecords,
                        incoming: incomingRecords))
                continue
            }

            if existingRecords.isEmpty {
                if let record = incomingRecords.first {
                    additions.append(record)
                }
                continue
            }

            if incomingRecords.isEmpty {
                if let record = existingRecords.first {
                    deletions.append(record)
                }
                continue
            }

            guard let existingRecord = existingRecords.first, let incomingRecord = incomingRecords.first else {
                continue
            }

            if recordsEqual(existingRecord, incomingRecord, comparison: comparison) {
                unchanged.append(existingRecord)
            } else {
                updates.append(
                    BrowserCookieSyncUpdate(
                        identity: identity,
                        existing: existingRecord,
                        incoming: incomingRecord))
            }
        }

        additions.sort { BrowserCookieIdentity(record: $0).sortKey < BrowserCookieIdentity(record: $1).sortKey }
        deletions.sort { BrowserCookieIdentity(record: $0).sortKey < BrowserCookieIdentity(record: $1).sortKey }
        unchanged.sort { BrowserCookieIdentity(record: $0).sortKey < BrowserCookieIdentity(record: $1).sortKey }
        updates.sort { $0.identity.sortKey < $1.identity.sortKey }
        collisions.sort { $0.identity.sortKey < $1.identity.sortKey }

        return BrowserCookieSyncPlan(
            additions: additions,
            deletions: deletions,
            updates: updates,
            unchanged: unchanged,
            collisions: collisions)
    }

    public static func plan(
        existing: BrowserCookieStoreRecords,
        incoming: BrowserCookieStoreRecords,
        comparison: BrowserCookieSyncComparison = BrowserCookieSyncComparison()) -> BrowserCookieSyncPlan
    {
        plan(existing: existing.records, incoming: incoming.records, comparison: comparison)
    }

    private static func recordsEqual(
        _ lhs: BrowserCookieRecord,
        _ rhs: BrowserCookieRecord,
        comparison: BrowserCookieSyncComparison) -> Bool
    {
        if lhs.value != rhs.value { return false }
        if lhs.expires != rhs.expires { return false }
        if lhs.isSecure != rhs.isSecure { return false }
        if lhs.isHTTPOnly != rhs.isHTTPOnly { return false }
        if lhs.sameSite != rhs.sameSite { return false }
        if lhs.priority != rhs.priority { return false }
        if lhs.partitionKey != rhs.partitionKey { return false }
        if lhs.isSameParty != rhs.isSameParty { return false }

        if comparison.includeCreatedAt && lhs.createdAt != rhs.createdAt { return false }
        if comparison.includeLastAccessedAt && lhs.lastAccessedAt != rhs.lastAccessedAt { return false }

        return true
    }
}
