import RunicCore
import SwiftUI

// MARK: - Skin

/// A skin is the whole visual language of the panel — not a palette, a kit.
/// It composes the pages (provider, front page, resets) and supplies the
/// chrome slots the shared surfaces ask for (panel, tabs, chip, action row,
/// section header, note, footer, popover frame).
///
/// Every slot returns `nil` to mean "use the standard rendering", so a skin
/// implements only what it changes, and no view ever consults a theme id.
/// A theme chooses its skin with `style.skin` in its JSON; two themes may
/// share one skin and differ only in tokens.
///
/// Add a skin: a folder under `Skins/`, a type conforming to this protocol,
/// a case in `RunicSkinRegistry`, and `"skin": "<id>"` in the theme JSON.
protocol RunicSkin {
    var id: String { get }

    // MARK: Pages

    /// The provider card: windows, balance, cost, insights.
    @MainActor func providerPage(_ model: UsageMenuCardView.Model, width: CGFloat) -> AnyView?

    /// The overview of every provider.
    @MainActor func frontPage(_ view: OverviewMenuView) -> AnyView?

    /// The resets list (windows counting down, banked resets).
    @MainActor func resetsPage(_ resets: RunicSkinResets) -> AnyView?

    // MARK: Chrome

    /// A section container. The standard one is a bordered card.
    @MainActor func panel(_ content: AnyView) -> AnyView?

    /// The provider tab strip.
    @MainActor func tabs(
        _ items: [ProviderTabBarView.TabItem],
        width: CGFloat,
        onSelect: @escaping (UsageProvider?) -> Void) -> AnyView?

    /// A selectable chip (Explore panels).
    @MainActor func chip(_ chip: RunicSkinChip) -> AnyView?

    /// An action row (Ping now, Settings…, Quit) or compact button (CSV).
    @MainActor func actionRow(_ row: RunicSkinActionRow) -> AnyView?

    /// A section title ("Resets", "Explore").
    @MainActor func sectionHeader(_ text: String) -> AnyView?

    /// A line of copy inside an action section.
    @MainActor func note(_ text: String, style: MenuDescriptor.TextStyle) -> AnyView?

    /// Closing line of the panel. Standard panels have none.
    @MainActor func footer(_ context: RunicSkinFooterContext) -> AnyView?

    /// Corner, border and shadow of the popover itself.
    func popoverChrome(for palette: RunicThemePalette) -> RunicSkinPopoverChrome?

    /// Inset between a panel's edge and its content.
    func panelInset(for palette: RunicThemePalette) -> CGFloat?

    /// Whether the tab strip sits in an outlined tray.
    var showsTabTray: Bool { get }

    /// Decoration laid over the whole popover, above the scrolling content
    /// and below the frame stroke: an inner bevel, corner screws, a vignette.
    /// Purely visual — it never takes hits. Standard panels have none.
    @MainActor func stageOverlay() -> AnyView?
}

extension RunicSkin {
    @MainActor func providerPage(_: UsageMenuCardView.Model, width _: CGFloat) -> AnyView? {
        nil
    }

    @MainActor func frontPage(_: OverviewMenuView) -> AnyView? {
        nil
    }

    @MainActor func resetsPage(_: RunicSkinResets) -> AnyView? {
        nil
    }

    @MainActor func panel(_: AnyView) -> AnyView? {
        nil
    }

    @MainActor func tabs(
        _: [ProviderTabBarView.TabItem],
        width _: CGFloat,
        onSelect _: @escaping (UsageProvider?) -> Void) -> AnyView?
    {
        nil
    }

    @MainActor func chip(_: RunicSkinChip) -> AnyView? {
        nil
    }

    @MainActor func actionRow(_: RunicSkinActionRow) -> AnyView? {
        nil
    }

    @MainActor func sectionHeader(_: String) -> AnyView? {
        nil
    }

    @MainActor func note(_: String, style _: MenuDescriptor.TextStyle) -> AnyView? {
        nil
    }

    @MainActor func footer(_: RunicSkinFooterContext) -> AnyView? {
        nil
    }

    func popoverChrome(for _: RunicThemePalette) -> RunicSkinPopoverChrome? {
        nil
    }

    func panelInset(for _: RunicThemePalette) -> CGFloat? {
        nil
    }

    var showsTabTray: Bool {
        true
    }

    @MainActor func stageOverlay() -> AnyView? {
        nil
    }
}

// MARK: - Slot inputs

struct RunicSkinChip {
    let title: String
    let systemImage: String
    let iconIntent: RunicIconIntent
    let isSelected: Bool
    let action: () -> Void
}

struct RunicSkinActionRow {
    let title: String
    let systemImage: String?
    let iconIntent: RunicIconIntent
    let isCompact: Bool
    let action: () -> Void
}

struct RunicSkinResets {
    let entries: [ResetScheduleEntry]
    let credits: [ResetCreditEntry]
    let width: CGFloat
    let showsProvider: Bool
}

struct RunicSkinFooterContext {
    let width: CGFloat
    let openAbout: () -> Void
}

struct RunicSkinPopoverChrome {
    var cornerRadius: CGFloat
    var strokeWidth: CGFloat
    var strokeColor: Color
}

// MARK: - Registry and environment

enum RunicSkinRegistry {
    /// The skin a palette asks for. Unknown ids fall back to the standard
    /// kit so a hand-edited theme file can never blank the panel.
    static func skin(for palette: RunicThemePalette) -> any RunicSkin {
        switch palette.skinID {
        case GazetteSkin.skinID: GazetteSkin()
        case SumiSkin.skinID: SumiSkin()
        case DraftingSkin.skinID: DraftingSkin()
        case ReceiptSkin.skinID: ReceiptSkin()
        case FlightDeckSkin.skinID: FlightDeckSkin()
        case DeparturesSkin.skinID: DeparturesSkin()
        case InstrumentSkin.skinID: InstrumentSkin()
        default: StandardSkin()
        }
    }

    /// Every bundled skin, for completeness tests and the appearance pane.
    static var all: [any RunicSkin] {
        [
            StandardSkin(),
            GazetteSkin(),
            SumiSkin(),
            DraftingSkin(),
            ReceiptSkin(),
            FlightDeckSkin(),
            DeparturesSkin(),
            InstrumentSkin(),
        ]
    }
}

extension EnvironmentValues {
    @Entry var runicSkin: any RunicSkin = StandardSkin()
}

// MARK: - Shared helpers

enum RunicSkinImprint {
    /// "Runic 2.10.1 · No. 156" — marketing version and build, so every
    /// build is its own edition. Read once.
    static let line: String = {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "Runic \(RunicVersion.marketing) \u{00B7} No. \(build)"
        }
        return "Runic \(RunicVersion.marketing)"
    }()

    static let author = "Sriinnu"
    static let authorURL = URL(string: "https://github.com/sriinnu")!
}

extension View {
    /// Pins a skin's bundled faces against the environment's font design. A
    /// user whose body font is SF Mono carries `.fontDesign(.monospaced)`
    /// through the panel, and SwiftUI would re-resolve every `Font.custom`
    /// through it — a face with no monospaced cut falls back to the body
    /// font. `nil` clears the inherited design and leaves the custom face
    /// alone; `.default` is not the same thing — it re-resolves through a
    /// design too, and Shippori Mincho and Zen Kaku fall back to the system
    /// sans under it. Every skin text sits under one of these.
    func skinFace() -> some View {
        self.fontDesign(nil)
    }
}
