//
//  TeamModels.swift
//  RunicCore
//
//  Created on 2026-01-31.
//

import Foundation

// MARK: - Team

/// Core team entity representing a collaborative workspace
public struct Team: Codable, Sendable, Identifiable {
    public let id: String // UUID
    public var name: String
    public let ownerUserID: String
    public var totalQuota: Int // tokens/month
    public var members: [TeamMembership]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        ownerUserID: String,
        totalQuota: Int,
        members: [TeamMembership] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.ownerUserID = ownerUserID
        self.totalQuota = totalQuota
        self.members = members
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Team {
    /// Total number of team members including owner
    public var memberCount: Int {
        return members.count
    }

    /// Get all admin users (owner + admins)
    public var adminUserIDs: [String] {
        return members.filter { $0.role == .owner || $0.role == .admin }.map(\.userID)
    }

    /// Check if a user is a member of this team
    public func hasMember(userID: String) -> Bool {
        return members.contains { $0.userID == userID }
    }

    /// Get membership for a specific user
    public func membership(for userID: String) -> TeamMembership? {
        return members.first { $0.userID == userID }
    }

    /// Check if user has admin privileges
    public func isAdmin(userID: String) -> Bool {
        guard let membership = membership(for: userID) else { return false }
        return membership.role == .owner || membership.role == .admin
    }

    /// Calculate total quota allocated to members with individual limits
    public var allocatedQuota: Int {
        return members.compactMap(\.quotaLimit).reduce(0, +)
    }

    /// Remaining unallocated quota
    public var unallocatedQuota: Int {
        return max(0, totalQuota - allocatedQuota)
    }
}

// MARK: - TeamMembership

/// Represents a user's role and permissions within a team
public struct TeamMembership: Codable, Sendable, Identifiable {
    public let id: String
    public let userID: String
    public let teamID: String
    public var role: TeamRole
    public var quotaLimit: Int? // Individual member limit (nil = no limit)
    public let joinedAt: Date

    public init(
        id: String = UUID().uuidString,
        userID: String,
        teamID: String,
        role: TeamRole,
        quotaLimit: Int? = nil,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.teamID = teamID
        self.role = role
        self.quotaLimit = quotaLimit
        self.joinedAt = joinedAt
    }
}

extension TeamMembership {
    /// Check if this member can manage other members
    public var canManageMembers: Bool {
        return role == .owner || role == .admin
    }

    /// Check if this member can modify team settings
    public var canModifyTeamSettings: Bool {
        return role == .owner || role == .admin
    }

    /// Check if this member can invite others
    public var canInviteMembers: Bool {
        return role == .owner || role == .admin
    }

    /// Check if this member can view usage
    public var canViewUsage: Bool {
        return true // All members can view usage
    }

    /// Check if this member can create projects
    public var canCreateProjects: Bool {
        return role != .viewer
    }
}

// MARK: - TeamRole

/// Defines permission levels within a team
public enum TeamRole: String, Codable, Sendable, CaseIterable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
    case viewer = "viewer"

    /// Display name for the role
    public var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .admin: return "Admin"
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }

    /// Description of role permissions
    public var description: String {
        switch self {
        case .owner:
            return "Full control over team, billing, and members"
        case .admin:
            return "Can manage members and team settings"
        case .member:
            return "Can create and share projects within team"
        case .viewer:
            return "Read-only access to team projects"
        }
    }

    /// Permission level (higher = more permissions)
    public var level: Int {
        switch self {
        case .owner: return 4
        case .admin: return 3
        case .member: return 2
        case .viewer: return 1
        }
    }

    /// Check if this role can modify another role
    public func canModify(_ other: TeamRole) -> Bool {
        return self.level > other.level
    }
}

// MARK: - ProjectOwnership

/// Defines ownership and sharing settings for a project
public struct ProjectOwnership: Codable, Sendable, Identifiable {
    public let id: String
    public let projectID: String
    public let teamID: String?
    public let ownerUserID: String
    public var sharedWith: [String] // User IDs
    public var accessLevel: AccessLevel
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        projectID: String,
        teamID: String? = nil,
        ownerUserID: String,
        sharedWith: [String] = [],
        accessLevel: AccessLevel = .privateAccess,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.teamID = teamID
        self.ownerUserID = ownerUserID
        self.sharedWith = sharedWith
        self.accessLevel = accessLevel
        self.createdAt = createdAt
    }
}

extension ProjectOwnership {
    /// Check if a user has access to this project
    public func hasAccess(userID: String) -> Bool {
        // Owner always has access
        if userID == ownerUserID {
            return true
        }

        // Check access level
        switch accessLevel {
        case .privateAccess:
            return sharedWith.contains(userID)
        case .team:
            // User must be in the team
            return teamID != nil
        case .public:
            return true
        }
    }

    /// Check if a user can edit this project
    public func canEdit(userID: String) -> Bool {
        return userID == ownerUserID || sharedWith.contains(userID)
    }

    /// Add a user to the shared list
    public mutating func share(with userID: String) {
        if !sharedWith.contains(userID) {
            sharedWith.append(userID)
        }
    }

    /// Remove a user from the shared list
    public mutating func unshare(with userID: String) {
        sharedWith.removeAll { $0 == userID }
    }

    /// Check if project is owned by a team
    public var isTeamOwned: Bool {
        return teamID != nil
    }
}

// MARK: - AccessLevel

/// Defines who can access a project
public enum AccessLevel: String, Codable, Sendable, CaseIterable {
    case privateAccess = "private" // Only owner and explicitly shared users
    case team = "team" // All team members
    case `public` = "public" // Anyone with link

    /// Display name for the access level
    public var displayName: String {
        switch self {
        case .privateAccess: return "Private"
        case .team: return "Team"
        case .public: return "Public"
        }
    }

    /// Icon representing the access level
    public var icon: String {
        switch self {
        case .privateAccess: return "lock.fill"
        case .team: return "person.2.fill"
        case .public: return "globe"
        }
    }

    /// Description of access level
    public var description: String {
        switch self {
        case .privateAccess:
            return "Only you and people you share with"
        case .team:
            return "All team members can access"
        case .public:
            return "Anyone with the link can view"
        }
    }
}

// MARK: - TeamUsageSummary

/// Aggregated usage statistics for a team
public struct TeamUsageSummary: Codable, Sendable {
    public let teamID: String
    public let period: DateInterval
    public var totalTokens: Int
    public var totalCost: Double
    public var memberUsage: [String: MemberUsage] // UserID -> usage
    public var quotaUsedPercent: Double

    public init(
        teamID: String,
        period: DateInterval,
        totalTokens: Int = 0,
        totalCost: Double = 0.0,
        memberUsage: [String: MemberUsage] = [:],
        quotaUsedPercent: Double = 0.0
    ) {
        self.teamID = teamID
        self.period = period
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.memberUsage = memberUsage
        self.quotaUsedPercent = quotaUsedPercent
    }
}

extension TeamUsageSummary {
    /// Get usage for a specific member
    public func usage(for userID: String) -> MemberUsage? {
        return memberUsage[userID]
    }

    /// Top users by token consumption
    public func topUsers(limit: Int = 5) -> [(userID: String, usage: MemberUsage)] {
        return memberUsage
            .sorted { $0.value.tokens > $1.value.tokens }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    /// Average tokens per member
    public var averageTokensPerMember: Int {
        guard !memberUsage.isEmpty else { return 0 }
        return totalTokens / memberUsage.count
    }

    /// Average cost per member
    public var averageCostPerMember: Double {
        guard !memberUsage.isEmpty else { return 0.0 }
        return totalCost / Double(memberUsage.count)
    }

    /// Check if team is approaching quota limit
    public var isApproachingQuota: Bool {
        return quotaUsedPercent >= 80.0
    }

    /// Check if team has exceeded quota
    public var hasExceededQuota: Bool {
        return quotaUsedPercent >= 100.0
    }

    /// Add or update member usage
    public mutating func updateUsage(for userID: String, usage: MemberUsage) {
        memberUsage[userID] = usage
        recalculateTotals()
    }

    /// Recalculate total tokens and cost from member usage
    private mutating func recalculateTotals() {
        totalTokens = memberUsage.values.reduce(0) { $0 + $1.tokens }
        totalCost = memberUsage.values.reduce(0.0) { $0 + $1.cost }
    }
}

// MARK: - MemberUsage

/// Usage statistics for an individual team member
public struct MemberUsage: Codable, Sendable {
    public let userID: String
    public var tokens: Int
    public var cost: Double
    public var requests: Int

    public init(
        userID: String,
        tokens: Int = 0,
        cost: Double = 0.0,
        requests: Int = 0
    ) {
        self.userID = userID
        self.tokens = tokens
        self.cost = cost
        self.requests = requests
    }
}

extension MemberUsage {
    /// Average cost per request
    public var averageCostPerRequest: Double {
        guard requests > 0 else { return 0.0 }
        return cost / Double(requests)
    }

    /// Average tokens per request
    public var averageTokensPerRequest: Int {
        guard requests > 0 else { return 0 }
        return tokens / requests
    }

    /// Check if member has quota limit and percentage used
    public func quotaUsedPercent(limit: Int?) -> Double? {
        guard let limit = limit, limit > 0 else { return nil }
        return (Double(tokens) / Double(limit)) * 100.0
    }

    /// Combine with another usage record
    public mutating func merge(with other: MemberUsage) {
        self.tokens += other.tokens
        self.cost += other.cost
        self.requests += other.requests
    }
}

// MARK: - TeamInvitation

/// Represents an invitation to join a team
public struct TeamInvitation: Codable, Sendable, Identifiable {
    public let id: String
    public let teamID: String
    public let invitedEmail: String
    public let invitedByUserID: String
    public var role: TeamRole
    public let expiresAt: Date
    public var status: InvitationStatus
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        teamID: String,
        invitedEmail: String,
        invitedByUserID: String,
        role: TeamRole = .member,
        expiresAt: Date = Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
        status: InvitationStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.teamID = teamID
        self.invitedEmail = invitedEmail
        self.invitedByUserID = invitedByUserID
        self.role = role
        self.expiresAt = expiresAt
        self.status = status
        self.createdAt = createdAt
    }
}

extension TeamInvitation {
    /// Check if invitation is still valid
    public var isValid: Bool {
        return status == .pending && !isExpired
    }

    /// Check if invitation has expired
    public var isExpired: Bool {
        return Date() > expiresAt
    }

    /// Days until expiration
    public var daysUntilExpiration: Int {
        let timeInterval = expiresAt.timeIntervalSince(Date())
        return max(0, Int(timeInterval / (24 * 60 * 60)))
    }

    /// Accept the invitation
    public mutating func accept() {
        guard isValid else { return }
        status = .accepted
    }

    /// Decline the invitation
    public mutating func decline() {
        guard isValid else { return }
        status = .declined
    }

    /// Mark as expired
    public mutating func expire() {
        if status == .pending {
            status = .expired
        }
    }
}

// MARK: - InvitationStatus

/// Status of a team invitation
public enum InvitationStatus: String, Codable, Sendable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case expired = "expired"

    /// Display name for the status
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .expired: return "Expired"
        }
    }

    /// Icon representing the status
    public var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .expired: return "hourglass.bottomhalf.filled"
        }
    }

    /// Color associated with status
    public var colorName: String {
        switch self {
        case .pending: return "orange"
        case .accepted: return "green"
        case .declined: return "red"
        case .expired: return "gray"
        }
    }
}

// MARK: - TeamQuotaAllocation

/// Helper for managing quota allocation across team members
public struct TeamQuotaAllocation: Sendable {
    public let team: Team
    public let usage: TeamUsageSummary

    public init(team: Team, usage: TeamUsageSummary) {
        self.team = team
        self.usage = usage
    }

    /// Get remaining quota for a specific member
    public func remainingQuota(for userID: String) -> Int? {
        guard let membership = team.membership(for: userID),
              let limit = membership.quotaLimit else {
            return nil
        }

        let used = usage.usage(for: userID)?.tokens ?? 0
        return max(0, limit - used)
    }

    /// Check if a member can use more tokens
    public func canUseTokens(_ tokens: Int, userID: String) -> Bool {
        guard let remaining = remainingQuota(for: userID) else {
            // No individual limit, check team limit
            return usage.totalTokens + tokens <= team.totalQuota
        }
        return remaining >= tokens
    }

    /// Get members who have exceeded their quota
    public func membersExceedingQuota() -> [TeamMembership] {
        return team.members.filter { membership in
            guard let limit = membership.quotaLimit else { return false }
            let used = usage.usage(for: membership.userID)?.tokens ?? 0
            return used > limit
        }
    }

    /// Get members approaching their quota (>80%)
    public func membersApproachingQuota() -> [TeamMembership] {
        return team.members.filter { membership in
            guard let limit = membership.quotaLimit else { return false }
            let used = usage.usage(for: membership.userID)?.tokens ?? 0
            let percent = (Double(used) / Double(limit)) * 100.0
            return percent >= 80.0 && percent < 100.0
        }
    }
}
