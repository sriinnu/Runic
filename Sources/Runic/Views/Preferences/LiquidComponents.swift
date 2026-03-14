import AppKit
import SwiftUI

// MARK: - Ambient liquid mesh

@MainActor
struct LiquidMeshBackground: View {
    @State private var phase: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let palette: [Color] = [
        Color(red: 0.30, green: 0.52, blue: 0.96),
        Color(red: 0.62, green: 0.34, blue: 0.92),
        Color(red: 0.24, green: 0.78, blue: 0.76),
        Color(red: 0.44, green: 0.28, blue: 0.88),
        Color(red: 0.18, green: 0.60, blue: 0.94),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30.0, paused: self.reduceMotion)) { timeline in
            Canvas { context, size in
                let t = self.reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let cx = size.width / 2
                let cy = size.height / 2

                for (i, color) in Self.palette.enumerated() {
                    let fi = Double(i)
                    let angle = t * (0.12 + fi * 0.03) + fi * 1.25
                    let r = min(cx, cy) * (0.28 + 0.18 * sin(t * 0.15 + fi * 0.9))
                    let x = cx + cos(angle) * r * 0.6
                    let y = cy + sin(angle) * r * 0.5
                    let blob = min(size.width, size.height) * (0.52 + 0.12 * sin(t * 0.2 + fi))

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
            .blur(radius: 40)
        }
    }
}

// MARK: - Cursor spotlight overlay

@MainActor
private struct CursorSpotlight: View {
    let cursorPoint: UnitPoint
    let isActive: Bool

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
                .animation(.easeOut(duration: 0.15), value: self.isActive)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Shimmer sweep overlay

@MainActor
private struct ShimmerSweep: View {
    @State private var offset: CGFloat = -0.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stableDelay: Double

    var body: some View {
        GeometryReader { geo in
            if !self.reduceMotion {
                LinearGradient(
                    colors: [.clear, Color.primary.opacity(0.04), Color.primary.opacity(0.07), Color.primary.opacity(0.04), .clear],
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
            guard !self.reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 2.8)
                .repeatForever(autoreverses: false)
                .delay(self.stableDelay))
            {
                self.offset = 1.4
            }
        }
    }
}

// MARK: - Rotating gradient border (Magic Card)

@MainActor
private struct RotatingGradientBorder: View {
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
        if self.isActive && !self.reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 60.0, paused: !self.isActive)) { timeline in
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

    func body(content: Content) -> some View {
        content
            .padding(RunicSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: self.hovering ? Color.accentColor.opacity(0.12) : .black.opacity(0.04),
                        radius: self.hovering ? 12 : 4,
                        y: self.hovering ? 4 : 2))
            .overlay(
                RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(self.hovering ? 0.18 : 0.10),
                                Color.primary.opacity(self.hovering ? 0.06 : 0.03),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 0.5))
            .overlay { RotatingGradientBorder(cornerRadius: RunicCornerRadius.lg, isActive: self.hovering) }
            .overlay {
                GeometryReader { geo in
                    CursorSpotlight(
                        cursorPoint: UnitPoint(
                            x: geo.size.width > 0 ? self.cursorUnit.x : 0.5,
                            y: geo.size.height > 0 ? self.cursorUnit.y : 0.5),
                        isActive: self.hovering)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous))
            .overlay {
                ShimmerSweep(stableDelay: Double(self.shimmerIndex) * 0.8 + 1.0)
                    .clipShape(RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous))
            }
            .scaleEffect(self.hovering && !self.reduceMotion ? 1.01 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: self.hovering)
            .onContinuousHover { phase in
                switch phase {
                case .active(let pt):
                    self.hovering = true
                    self.cursorUnit = UnitPoint(x: pt.x, y: pt.y)
                case .ended:
                    self.hovering = false
                }
            }
    }
}

// MARK: - Public components using the shared core

@MainActor
struct LiquidSection<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            if let title {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.leading, RunicSpacing.xxs)
            }
            self.content
        }
        .modifier(LiquidGlassCore(shimmerIndex: self.title.hashValue & 0xF))
    }
}

@MainActor
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

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
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .scaleEffect(appeared ? 1 : 0.97, anchor: .top)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.78)
                .delay(Double(index) * 0.07),
                value: appeared)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
                .padding(.vertical, PreferencesLayoutMetrics.paneVertical)
            }
        }
    }
}
