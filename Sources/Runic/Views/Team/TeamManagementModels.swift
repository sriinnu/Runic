import SwiftUI

struct Team: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var role: TeamRole
    var members: [TeamMember]
    var totalQuota: Int
    var usedQuota: Int

    var usagePercent: Double {
        guard self.totalQuota > 0 else { return 0 }
        return (Double(self.usedQuota) / Double(self.totalQuota)) * 100
    }

    var usageColor: Color {
        let percent = self.usagePercent
        if percent >= 90 { return Color(nsColor: .systemRed) }
        if percent >= 75 { return Color(nsColor: .systemOrange) }
        return Color(nsColor: .systemBlue)
    }
}

enum TeamRole: String, CaseIterable, Codable {
    case owner
    case admin
    case member
    case viewer

    var displayName: String {
        switch self {
        case .owner: "Owner"
        case .admin: "Admin"
        case .member: "Member"
        case .viewer: "Viewer"
        }
    }

    var icon: String {
        switch self {
        case .owner: "crown.fill"
        case .admin: "star.fill"
        case .member: "person.fill"
        case .viewer: "eye.fill"
        }
    }

    var color: Color {
        switch self {
        case .owner: Color(nsColor: .systemYellow)
        case .admin: Color(nsColor: .systemBlue)
        case .member: Color(nsColor: .systemGreen)
        case .viewer: Color(nsColor: .systemGray)
        }
    }

    var canInvite: Bool {
        switch self {
        case .owner, .admin: true
        case .member, .viewer: false
        }
    }

    var canEditQuota: Bool {
        switch self {
        case .owner, .admin: true
        case .member, .viewer: false
        }
    }

    var canRemoveMembers: Bool {
        switch self {
        case .owner, .admin: true
        case .member, .viewer: false
        }
    }
}
