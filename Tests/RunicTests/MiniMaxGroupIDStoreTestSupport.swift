@testable import Runic

struct NoopMiniMaxGroupIDStore: MiniMaxGroupIDStoring {
    func loadGroupID() throws -> String? { nil }
    func storeGroupID(_ groupID: String?) throws {
        _ = groupID
    }
}
