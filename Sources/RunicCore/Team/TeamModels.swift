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
        updatedAt: Date = Date())
    {
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
        self.members.count
    }

    /// Get all admin users (owner + admins)
    public var adminUserIDs: [String] {
        self.members.filter { $0.role == .owner || $0.role == .admin }.map(\.userID)
    }

    /// Check if a user is a member of this team
    public func hasMember(userID: String) -> Bool {
        self.members.contains { $0.userID == userID }
    }

    /// Get membership for a specific user
    public func membership(for userID: String) -> TeamMembership? {
        self.members.first { $0.userID == userID }
    }

    /// Check if user has admin privileges
    public func isAdmin(userID: String) -> Bool {
        guard let membership = membership(for: userID) else { return false }
        return membership.role == .owner || membership.role == .admin
    }

    /// Calculate total quota allocated to members with individual limits
    public var allocatedQuota: Int {
        self.members.compactMap(\.quotaLimit).reduce(0, +)
    }

    /// Remaining unallocated quota
    public var unallocatedQuota: Int {
        max(0, self.totalQuota - self.allocatedQuota)
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
        joinedAt: Date = Date())
    {
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
        self.role == .owner || self.role == .admin
    }

    /// Check if this member can modify team settings
    public var canModifyTeamSettings: Bool {
        self.role == .owner || self.role == .admin
    }

    /// Check if this member can invite others
    public var canInviteMembers: Bool {
        self.role == .owner || self.role == .admin
    }

    /// Check if this member can view usage
    public var canViewUsage: Bool {
        true // All members can view usage
    }

    /// Check if this member can create projects
    public var canCreateProjects: Bool {
        self.role != .viewer
    }
}

// MARK: - TeamRole

/// Defines permission levels within a team
public enum TeamRole: String, Codable, Sendable, CaseIterable {
    case owner
    case admin
    case member
    case viewer

    /// Display name for the role
    public var displayName: String {
        switch self {
        case .owner: "Owner"
        case .admin: "Admin"
        case .member: "Member"
        case .viewer: "Viewer"
        }
    }

    /// Description of role permissions
    public var description: String {
        switch self {
        case .owner:
            "Full control over team, billing, and members"
        case .admin:
            "Can manage members and team settings"
        case .member:
            "Can create and share projects within team"
        case .viewer:
            "Read-only access to team projects"
        }
    }

    /// Permission level (higher = more permissions)
    public var level: Int {
        switch self {
        case .owner: 4
        case .admin: 3
        case .member: 2
        case .viewer: 1
        }
    }

    /// Check if this role can modify another role
    public func canModify(_ other: TeamRole) -> Bool {
        self.level > other.level
    }
}
