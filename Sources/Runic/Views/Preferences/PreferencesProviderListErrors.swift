import AppKit
import SwiftUI

struct ProviderErrorDisplay {
    let preview: String
    let full: String
}

@MainActor
struct ProviderErrorView: View {
    @Environment(\.runicFonts) private var fonts
    let title: String
    let display: ProviderErrorDisplay
    @Binding var isExpanded: Bool
    let onCopy: () -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(alignment: .center, spacing: RunicSpacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(self.fonts.caption)
                    .foregroundStyle(.orange)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                Text(self.title)
                    .font(self.fonts.callout.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Button {
                    self.onCopy()
                } label: {
                    HStack(alignment: .center, spacing: RunicSpacing.xxs) {
                        Image(systemName: "doc.on.doc")
                            .font(self.fonts.caption)
                        Text("Copy")
                            .font(self.fonts.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copy error to clipboard")
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
            }

            Text(self.display.preview)
                .font(self.fonts.callout)
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(RunicSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .fill(Color.orange.opacity(0.08)))

            if self.display.preview != self.display.full {
                Button(self.isExpanded ? "Hide details" : "Show details") { self.isExpanded.toggle() }
                    .buttonStyle(.link)
                    .font(self.fonts.callout)
            }

            if self.isExpanded {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(self.display.full)
                        .font(self.fonts.caption)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(ProviderListMetrics.errorCardPadding)
                }
                .frame(maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(ProviderListMetrics.errorCardPadding)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.03)))
    }
}

@MainActor
struct ProviderListScrollInsetFixer: NSViewRepresentable {
    private final class HitTestIgnoringView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }

    func makeNSView(context: Context) -> NSView {
        HitTestIgnoringView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            guard let scrollView = Self.findScrollView(from: nsView) else { return }
            if scrollView.automaticallyAdjustsContentInsets {
                scrollView.automaticallyAdjustsContentInsets = false
            }
            let zeroInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            let currentContentInsets = scrollView.contentInsets
            if currentContentInsets.top != 0 || currentContentInsets.left != 0 ||
                currentContentInsets.bottom != 0 || currentContentInsets.right != 0
            {
                scrollView.contentInsets = zeroInsets
            }
            let currentScrollerInsets = scrollView.scrollerInsets
            if currentScrollerInsets.top != 0 || currentScrollerInsets.left != 0 ||
                currentScrollerInsets.bottom != 0 || currentScrollerInsets.right != 0
            {
                scrollView.scrollerInsets = zeroInsets
            }
        }
    }

    private static func findScrollView(from view: NSView) -> NSScrollView? {
        var current: NSView? = view
        while let candidate = current {
            if let scroll = candidate as? NSScrollView { return scroll }
            if let found = candidate.subviews.compactMap({ $0 as? NSScrollView }).first {
                return found
            }
            current = candidate.superview
        }
        return nil
    }
}
