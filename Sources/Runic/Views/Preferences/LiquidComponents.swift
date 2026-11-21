import AppKit
import SwiftUI

// MARK: - Ambient liquid mesh

@MainActor
struct LiquidMeshBackground: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.runicTheme.isTerminalHUD {
            ZStack {
                self.runicTheme.menuSurfaceGradient
                RunicTerminalCodeRainOverlay()
                RunicTerminalScanlineOverlay(opacity: self.runicTheme.style.effects.scanlineOpacity)
            }
        } else if self.runicTheme.hasSurfaceTexture ||
            (self.runicTheme.id != "glass" && self.runicTheme.style.effects.materialIntensity < 0.1)
        {
            // Paper, film, parchment: the texture is the ground. A blurred
            // mesh under it only produced a stray gray band mid-window.
            Color.clear
        } else {
            Canvas { context, size in
                self.drawMesh(context: context, size: size)
            }
            .blur(radius: 36)
        }
    }

    private func drawMesh(context: GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        let cy = size.height / 2
        let palette = self.runicTheme.meshColors

        for (index, color) in palette.enumerated() {
            let fi = Double(index)
            let angle = fi * 1.42
            let r = min(cx, cy) * (0.32 + 0.08 * sin(fi * 0.9))
            let x = cx + cos(angle) * r * 0.72
            let y = cy + sin(angle) * r * 0.58
            let blob = min(size.width, size.height) * (0.50 + 0.08 * sin(fi))

            let rect = CGRect(x: x - blob / 2, y: y - blob / 2, width: blob, height: blob)
            context.fill(
                Ellipse().path(in: rect),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.35), color.opacity(0.08), color.opacity(0)]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: blob / 2))
        }
    }
}

// MARK: - Shared glass modifier (single source of truth)

@MainActor
private struct LiquidGlassCore: ViewModifier {
    let shimmerIndex: Int
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.runicTheme) private var runicTheme

    func body(content: Content) -> some View {
        let isTerminalHUD = self.runicTheme.isTerminalHUD
        let cornerRadius = self.runicTheme.shape.cornerRadius(RunicCornerRadius.md)
        content
            .padding(RunicSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(self.runicTheme.cardFill.opacity(0.68)))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isTerminalHUD
                            ? self.runicTheme.accent.opacity(self.hovering ? 0.56 : 0.36)
                            : self.runicTheme.menuSeparatorColor.opacity(self.hovering ? 0.65 : 0.45),
                        lineWidth: isTerminalHUD ? self.runicTheme.style.chrome.borderWeight : 1))
            .animation(self.reduceMotion ? nil : self.runicTheme.motion.curve, value: self.hovering)
            .onHover { isHovered in
                self.hovering = isHovered
            }
    }
}

// MARK: - Public components using the shared core

@MainActor
struct LiquidSection<Content: View>: View {
    @Environment(\.runicFonts) private var fonts
    let title: String?
    let content: Content
    @Environment(\.runicTheme) private var runicTheme

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            if let title {
                RunicPreferencesSectionTitle(text: title)
                    .padding(.leading, RunicSpacing.xxs)
            }
            self.content
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(LiquidGlassCore(shimmerIndex: self.title.hashValue & 0xF))
    }
}

/// Section title for preferences cards. Opinionated themes get the same
/// header treatment as the menu (seal, brackets, rule, tracked caps);
/// System and Dark keep a quiet uppercase label in the accent.
@MainActor
struct RunicPreferencesSectionTitle: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let text: String

    var body: some View {
        if self.runicTheme.isCustom || self.runicTheme.isTerminalHUD {
            RetroSectionHeader(text: self.text)
        } else {
            Text(self.text)
                .font(self.fonts.subheadline.weight(.semibold))
                .foregroundStyle(self.runicTheme.accent)
                .textCase(.uppercase)
                .tracking(0.6)
        }
    }
}

@MainActor
struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        self.content
            .modifier(LiquidGlassCore(shimmerIndex: 0))
    }
}

// MARK: - View modifiers

extension View {
    func liquidGlass() -> some View {
        modifier(LiquidGlassCore(shimmerIndex: 3))
    }

    func liquidEntrance(appeared: Bool, index: Int) -> some View {
        self.modifier(LiquidEntranceModifier(appeared: appeared, index: index))
    }
}

@MainActor
private struct LiquidEntranceModifier: ViewModifier {
    let appeared: Bool
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isScreenshot = RunicScreenshotRenderer.isRequested
        let isVisible = self.appeared || isScreenshot
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: self.reduceMotion || isVisible ? 0 : 14)
            .scaleEffect(self.reduceMotion || isVisible ? 1 : 0.97, anchor: .top)
            .animation(
                self.reduceMotion || isScreenshot ? nil : .spring(response: 0.5, dampingFraction: 0.78)
                    .delay(Double(self.index) * 0.07),
                value: self.appeared)
    }
}

// MARK: - Liquid preferences pane wrapper

@MainActor
struct LiquidPreferencesPane<Content: View>: View {
    let meshOpacity: Double
    let showsIndicators: Bool
    private let content: () -> Content

    init(
        meshOpacity: Double = 0.3,
        showsIndicators: Bool = true,
        @ViewBuilder content: @escaping () -> Content)
    {
        self.meshOpacity = meshOpacity
        self.showsIndicators = showsIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: self.showsIndicators) {
            VStack(alignment: .leading, spacing: RunicSpacing.md) {
                self.content()
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
            .padding(.vertical, PreferencesLayoutMetrics.paneVertical)
        }
    }
}
