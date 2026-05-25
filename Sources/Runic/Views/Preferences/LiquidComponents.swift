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
                RunicTerminalScanlineOverlay(opacity: self.runicTheme.style.effects.scanlineOpacity)
            }
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

// MARK: - Cursor spotlight overlay

@MainActor
private struct CursorSpotlight: View {
    let cursorPoint: UnitPoint
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            RadialGradient(
                colors: [
                    Color.primary.opacity(self.isActive ? 0.10 : 0),
                    Color.primary.opacity(self.isActive ? 0.04 : 0),
                    Color.clear,
                ],
                center: UnitPoint(
                    x: geo.size.width > 0 ? max(0, min(1, self.cursorPoint.x)) : 0.5,
                    y: geo.size.height > 0 ? max(0, min(1, self.cursorPoint.y)) : 0.5),
                startRadius: 0,
                endRadius: 160)
                .animation(self.reduceMotion ? nil : .easeOut(duration: 0.15), value: self.isActive)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Shimmer sweep overlay

@MainActor
private struct ShimmerSweep: View {
    @Environment(\.runicFonts) private var fonts
    @State private var offset: CGFloat = -0.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stableDelay: Double
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            if self.isActive, !self.reduceMotion {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.primary.opacity(0.04),
                        Color.primary.opacity(0.07),
                        Color.primary.opacity(0.04),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing)
                    .frame(width: geo.size.width * 0.35)
                    .offset(x: geo.size.width * self.offset)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            self.startIfNeeded()
        }
        .onChange(of: self.isActive) { _, _ in
            self.startIfNeeded()
        }
    }

    private func startIfNeeded() {
        guard self.isActive, !self.reduceMotion else { return }
        self.offset = -0.4
        withAnimation(.easeInOut(duration: 1.2).delay(self.stableDelay)) {
            self.offset = 1.4
        }
    }
}

// MARK: - Rotating gradient border (Magic Card)

@MainActor
private struct RotatingGradientBorder: View {
    @Environment(\.runicFonts) private var fonts
    let cornerRadius: CGFloat
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let borderColors: [Color] = [
        Color(red: 0.36, green: 0.86, blue: 1.0),
        Color(red: 0.24, green: 0.40, blue: 0.89),
        Color(red: 0.31, green: 0.00, blue: 0.76),
        Color(red: 0.24, green: 0.40, blue: 0.89),
        Color(red: 0.36, green: 0.86, blue: 1.0),
    ]

    var body: some View {
        if self.isActive, !self.reduceMotion {
            TimelineView(.periodic(from: .now, by: 1 / 12.0)) { timeline in
                let rotation = timeline.date.timeIntervalSinceReferenceDate * 72
                RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: Self.borderColors),
                            center: .center,
                            angle: .degrees(rotation)),
                        lineWidth: 1.5)
                    .opacity(0.7)
            }
            .transition(.opacity.animation(.easeInOut(duration: 0.35)))
        }
    }
}

// MARK: - Shared glass modifier (single source of truth)

@MainActor
private struct LiquidGlassCore: ViewModifier {
    let shimmerIndex: Int
    @State private var hovering = false
    @State private var cursorUnit: UnitPoint = .center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.runicTheme) private var runicTheme

    func body(content: Content) -> some View {
        let isGlassTheme = self.runicTheme.id == "glass"
        let isTerminalHUD = self.runicTheme.isTerminalHUD
        let cornerRadius = self.runicTheme.shape.cornerRadius(RunicCornerRadius.lg)
        let shadowColor = self.hovering
            ? self.runicTheme.accent.opacity(isTerminalHUD ? 0.16 : (isGlassTheme ? 0.22 : 0.10))
            : .black.opacity(isTerminalHUD ? 0.22 : (isGlassTheme ? 0.18 : 0.04))
        let shadowRadius: CGFloat = self.hovering
            ? (isTerminalHUD ? 6 : (isGlassTheme ? 18 : 12))
            : (isTerminalHUD ? 3 : (isGlassTheme ? 10 : 4))
        let shadowY: CGFloat = self.hovering ? (isTerminalHUD ? 3 : 6) : 2
        let borderWidth = isTerminalHUD
            ? self.runicTheme.style.chrome.borderWeight
            : (isGlassTheme ? 0.9 : 0.5)
        content
            .padding(RunicSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(self.runicTheme.cardBackgroundStyle)

                    if !isTerminalHUD, self.runicTheme.style.effects.materialIntensity > 0.05 {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(self.runicTheme.style.effects.materialIntensity)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .fill(self.runicTheme.cardFill.opacity(isGlassTheme ? 0.92 : 0.36)))
                    }

                    if isTerminalHUD {
                        RunicTerminalScanlineOverlay(opacity: self.runicTheme.style.effects.scanlineOpacity * 0.55)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
                .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isTerminalHUD
                                ? [
                                    self.runicTheme.accent.opacity(
                                        self.hovering ? 0.56 : self.runicTheme.style.chrome.borderOpacity),
                                    self.runicTheme.highlight.opacity(self.hovering ? 0.34 : 0.18),
                                    self.runicTheme.accent.opacity(
                                        self.hovering ? 0.46 : self.runicTheme.style.chrome.borderOpacity * 0.8),
                                ]
                                : [
                                    self.runicTheme.highlight.opacity(self.hovering ? 0.26 : 0.12),
                                    self.runicTheme.cardStroke.opacity(self.hovering ? 0.34 : 0.18),
                                    self.runicTheme.accent.opacity(self.hovering ? 0.20 : 0.08),
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: borderWidth))
            .overlay {
                if isTerminalHUD {
                    RunicTerminalCornerOverlay(
                        inset: 2,
                        length: 11,
                        lineWidth: self.runicTheme.style.chrome.borderWeight,
                        opacity: self.hovering ? 0.46 : 0.22)
                } else {
                    RotatingGradientBorder(
                        cornerRadius: RunicCornerRadius.lg,
                        isActive: self.hovering && isGlassTheme)
                }
            }
            .overlay {
                if !isTerminalHUD {
                    GeometryReader { geo in
                        CursorSpotlight(
                            cursorPoint: UnitPoint(
                                x: geo.size.width > 0 ? self.cursorUnit.x / geo.size.width : 0.5,
                                y: geo.size.height > 0 ? self.cursorUnit.y / geo.size.height : 0.5),
                            isActive: self.hovering)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if !isTerminalHUD {
                    ShimmerSweep(
                        stableDelay: Double(self.shimmerIndex) * 0.8 + 1.0,
                        isActive: self.hovering && isGlassTheme)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .scaleEffect(self.hovering && !self.reduceMotion && !isTerminalHUD ? 1.01 : 1.0)
            .animation(self.reduceMotion ? nil : self.runicTheme.motion.curve, value: self.hovering)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onContinuousHover { phase in
                            switch phase {
                            case let .active(pt):
                                self.hovering = true
                                self.cursorUnit = UnitPoint(x: pt.x, y: pt.y)
                            case .ended:
                                self.hovering = false
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                })
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
                Text(title)
                    .font(self.titleFont)
                    .foregroundStyle(self.titleColor)
                    .textCase(.uppercase)
                    .tracking(self.runicTheme.isTerminalHUD ? 0.8 : 0.4)
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

    private var titleFont: Font {
        self.runicTheme.isTerminalHUD ? self.fonts.headline.weight(.bold) : self.fonts.subheadline.weight(.semibold)
    }

    private var titleColor: Color {
        self.runicTheme.isTerminalHUD ? self.runicTheme.accent : self.runicTheme.secondaryText
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
        ZStack {
            LiquidMeshBackground()
                .ignoresSafeArea()
                .opacity(self.meshOpacity)

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
}
