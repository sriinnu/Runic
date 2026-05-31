import Foundation

extension TeamStore {
    public enum TeamStoreError: LocalizedError {
        case teamNotFound
        case membershipNotFound
        case projectNotFound
        case invitationNotFound
        case invalidQuota
        case insufficientPermissions
        case duplicateMembership
        case duplicateInvitation
        case invitationExpired
        case ownerCannotLeave
        case invalidEmailFormat
        case teamQuotaExceeded
        case memberQuotaExceeded

        public var errorDescription: String? {
            switch self {
            case .teamNotFound:
                "Team not found"
            case .membershipNotFound:
                "Membership not found"
            case .projectNotFound:
                "Project not found"
            case .invitationNotFound:
                "Invitation not found"
            case .invalidQuota:
                "Invalid quota value"
            case .insufficientPermissions:
                "Insufficient permissions to perform this action"
            case .duplicateMembership:
                "User is already a member of this team"
            case .duplicateInvitation:
                "An invitation has already been sent to this email"
            case .invitationExpired:
                "This invitation has expired"
            case .ownerCannotLeave:
                "Team owner cannot leave the team. Transfer ownership first."
            case .invalidEmailFormat:
                "Invalid email format"
            case .teamQuotaExceeded:
                "Team quota exceeded"
            case .memberQuotaExceeded:
                "Member quota exceeded"
            }
        }
    }
}
