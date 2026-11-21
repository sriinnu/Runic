import SwiftUI

/// The default kit: every slot is the standard rendering, so this type is
/// deliberately empty. System, Dark and Terminal draw with it.
struct StandardSkin: RunicSkin {
    static let skinID = "standard"
    var id: String {
        Self.skinID
    }
}
