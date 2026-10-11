import SwiftUI

/// The default kit: every slot is the standard rendering, so this type is
/// deliberately empty. System, Dark, Glass, Blueprint, Retro, Terminal,
/// Relief and Yantra draw with it today; each moves to its own kit as it
/// gets one.
struct StandardSkin: RunicSkin {
    static let skinID = "standard"
    var id: String {
        Self.skinID
    }
}
