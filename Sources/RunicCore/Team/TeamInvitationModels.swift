import Foundation

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
        createdAt: Date = Date())
    {
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
        self.status == .pending && !self.isExpired
    }

    /// Check if invitation has expired
    public var isExpired: Bool {
        Date() > self.expiresAt
    }

    /// Days until expiration
    public var daysUntilExpiration: Int {
        let timeInterval = self.expiresAt.timeIntervalSince(Date())
        return max(0, Int(timeInterval / (24 * 60 * 60)))
    }

    /// Accept the invitation
    public mutating func accept() {
        guard self.isValid else { return }
        self.status = .accepted
    }

    /// Decline the invitation
    public mutating func decline() {
        guard self.isValid else { return }
        self.status = .declined
    }

    /// Mark as expired
    public mutating func expire() {
        if self.status == .pending {
            self.status = .expired
        }
    }
}

// MARK: - InvitationStatus

/// Status of a team invitation
public enum InvitationStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case accepted
    case declined
    case expired

    /// Display name for the status
    public var displayName: String {
        switch self {
        case .pending: "Pending"
        case .accepted: "Accepted"
        case .declined: "Declined"
        case .expired: "Expired"
        }
    }

    /// Icon representing the status
    public var icon: String {
        switch self {
        case .pending: "clock.fill"
        case .accepted: "checkmark.circle.fill"
        case .declined: "xmark.circle.fill"
        case .expired: "hourglass.bottomhalf.filled"
        }
    }

    /// Color associated with status
    public var colorName: String {
        switch self {
        case .pending: "orange"
        case .accepted: "green"
        case .declined: "red"
        case .expired: "gray"
        }
    }
}
