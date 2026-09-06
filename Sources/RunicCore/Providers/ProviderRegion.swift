import Foundation

/// Which platform a provider slot authenticates against. Some brands run
/// genuinely separate platforms for mainland China vs the rest of the world —
/// separate accounts, keys, and hosts — so Runic models each as its own
/// `UsageProvider` slot and pairs them here. Every surface (preferences,
/// menu switcher, overview, widget, ordering) reads this one table.
public enum ProviderRegion: String, Sendable, CaseIterable, Identifiable {
    case international
    case china

    public var id: String {
        self.rawValue
    }

    public var displayName: String {
        switch self {
        case .international: "International"
        case .china: "China"
        }
    }
}

extension UsageProvider {
    /// International slot → its China sibling.
    public static let chinaSiblingByParent: [UsageProvider: UsageProvider] = [
        .kimi: .kimiCN,
        .zai: .zaiCN,
        .minimax: .minimaxCN,
        .stepfun: .stepfunCN,
        .qwen: .qwenCN,
    ]

    private static let parentByChinaSibling: [UsageProvider: UsageProvider] = Dictionary(
        uniqueKeysWithValues: Self.chinaSiblingByParent.map { ($1, $0) })

    /// The China slot paired with this international slot, if the brand has one.
    public var chinaSibling: UsageProvider? {
        Self.chinaSiblingByParent[self]
    }

    /// The international slot this China slot belongs to, if this is a China slot.
    public var regionalParent: UsageProvider? {
        Self.parentByChinaSibling[self]
    }

    public var isChinaSlot: Bool {
        self.regionalParent != nil
    }

    public var region: ProviderRegion {
        self.isChinaSlot ? .china : .international
    }

    /// The brand-level provider: the international slot for a pair, else self.
    public var brandRoot: UsageProvider {
        self.regionalParent ?? self
    }

    /// The slot of `self`'s brand for the given region, if it exists.
    public func slot(for region: ProviderRegion) -> UsageProvider? {
        switch region {
        case .international: self.brandRoot
        case .china: self.brandRoot.chinaSibling
        }
    }

    /// Compact switcher/chip name: "Kimi" stays, "Kimi (China)" becomes "Kimi CN".
    public static func compactDisplayName(_ displayName: String) -> String {
        let suffix = " (China)"
        guard displayName.hasSuffix(suffix) else { return displayName }
        return String(displayName.dropLast(suffix.count)) + " CN"
    }
}
