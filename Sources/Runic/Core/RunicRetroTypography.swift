import SwiftUI

/// Retro-specific typography helpers. VT323 is the bundled pixel-display
/// font used only for decorative roles (section headers, tagline). Body
/// text continues to use the user's chosen font via `RunicFontStore`.
enum RunicRetroFont {
    /// VT323 family name — matches the CTFont family attribute in the TTF.
    static let pixelFamily = "VT323"

    /// Decorative header font (section labels). Sized to read like a
    /// signage panel — slightly oversized to leave headroom for the
    /// pixel rendering.
    static func pixelHeader(size: CGFloat = 14) -> Font {
        Font.custom(self.pixelFamily, size: size)
    }

    /// Smaller pixel label (used for footer tagline and decorative chrome).
    static func pixelLabel(size: CGFloat = 11) -> Font {
        Font.custom(self.pixelFamily, size: size)
    }
}

/// "Retro tools. Modern intelligence." — the brand tagline. Renders only on
/// the Retro theme; an empty view elsewhere. Pixel font, low opacity, sits
/// at the bottom of the popover + Preferences About.
@MainActor
struct RetroTaglineFooter: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.runicTheme.id == "retro" {
            HStack(spacing: 6) {
                Text("RUNIC")
                    .tracking(2.5)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.65))
                Text("·")
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.45))
                Text("Retro tools. Modern intelligence.")
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.70))
            }
            .font(RunicRetroFont.pixelLabel(size: 11))
            .accessibilityLabel("Runic — retro tools, modern intelligence")
        } else {
            EmptyView()
        }
    }
}

/// Themed section header. Per-theme rendering:
/// - **Retro:** plain uppercase with wide tracking, sans-serif, muted navy
///   (matches Mockup #7 — brackets are NOT a retro pattern, they're terminal).
/// - **Terminal:** monospaced `[ SECTION ]` brackets in phosphor green.
/// - **Sumi:** a small vermilion seal mark, then the title in the body face.
/// - **Blueprint:** tracked caps with a cyan tick and a title-block rule
///   running to the trailing edge.
/// - **Relief:** small tracked caps pressed into the surface (letterpress).
/// - **Kirigami (any display face):** the title handwritten in lowercase,
///   a size up, with a small marker underline that stops short.
/// - **Everywhere else:** standard subheadline.
@MainActor
struct RetroSectionHeader: View {
    let text: String
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.runicFonts) private var fonts

    var body: some View {
        Group {
            if self.runicTheme.id == "retro" {
                Text(self.text.uppercased())
                    .tracking(1.6)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.85))
            } else if self.runicTheme.isTerminalHUD {
                HStack(alignment: .top, spacing: 4) {
                    Text("[")
                        .foregroundStyle(self.runicTheme.accent.opacity(0.85))
                    Text(self.text.uppercased())
                        .tracking(1.8)
                        .foregroundStyle(self.runicTheme.primaryText)
                        // Long headers (e.g. "Export visible timeline, 1 year")
                        // overflow a single line even at a shrunk scale — wrap
                        // to a second line instead of silently truncating.
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("]")
                        .foregroundStyle(self.runicTheme.accent.opacity(0.85))
                }
                .font(self.fonts.callout.weight(.bold))
            } else if self.runicTheme.id == "sumi" {
                HStack(alignment: .center, spacing: 6) {
                    // Hanko: a small square seal in vermilion with the
                    // first letter knocked out of it.
                    ZStack {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(self.runicTheme.accent.opacity(0.92))
                        Text(String(self.text.prefix(1)).uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(self.runicTheme.surface)
                    }
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                    Text(self.text)
                        .font(self.fonts.subheadline.weight(.semibold))
                        .foregroundStyle(self.runicTheme.primaryText)
                }
            } else if self.runicTheme.id == "blueprint" {
                HStack(alignment: .center, spacing: 8) {
                    Rectangle()
                        .fill(self.runicTheme.accent)
                        .frame(width: 10, height: 1.5)
                        .accessibilityHidden(true)
                    Text(self.text.uppercased())
                        .tracking(1.6)
                        .font(self.fonts.system(size: 10, weight: .semibold))
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                    Rectangle()
                        .fill(self.runicTheme.cardStroke.opacity(0.45))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            } else if self.fonts.hasDisplayFace {
                Text(self.text.lowercased())
                    .font(self.fonts.display(size: 18))
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.bottom, 1)
                    .background(alignment: .bottomLeading) {
                        // Marker underline, a touch short of the text width.
                        RunicMarkerUnderline(color: self.runicTheme.highlight.opacity(0.62))
                            .frame(height: 3)
                            .padding(.trailing, 12)
                            .offset(y: 1)
                    }
            } else if self.runicTheme.isElevated {
                Text(self.text.uppercased())
                    .tracking(1.2)
                    .font(self.fonts.caption.weight(.bold))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .shadow(color: self.runicTheme.elevationRimColor, radius: 0, y: 1)
            } else {
                Text(self.text)
                    .font(self.fonts.subheadline.weight(.semibold))
                    .foregroundStyle(self.runicTheme.primaryText)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}
