import SwiftUI

/// Visual test cases for the improved UsageProgressBar
/// Copy this into a SwiftUI preview or test view to see all variants

struct ProgressBarShowcase: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            Text("UsageProgressBar Improvements")
                .font(.title.bold())

            // MARK: - Height Variants
            VStack(alignment: .leading, spacing: 16) {
                Text("Height Variants")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Compact (6pt) - Team member rows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    UsageProgressBar(
                        percent: 75,
                        tint: .blue,
                        accessibilityLabel: "Compact example",
                        height: .compact)

                    Text("Regular (8pt) - Default menu cards")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    UsageProgressBar(
                        percent: 60,
                        tint: .green,
                        accessibilityLabel: "Regular example",
                        height: .regular)

                    Text("Large (10pt) - Dashboard hero sections")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    UsageProgressBar(
                        percent: 85,
                        tint: .orange,
                        accessibilityLabel: "Large example",
                        height: .large)
                }
            }

            Divider()

            // MARK: - Percentage Variants
            VStack(alignment: .leading, spacing: 16) {
                Text("Different Percentages (Regular)")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("10%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 50, alignment: .trailing)
                        UsageProgressBar(
                            percent: 10,
                            tint: .green,
                            accessibilityLabel: "10 percent")
                    }

                    HStack {
                        Text("25%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 50, alignment: .trailing)
                        UsageProgressBar(
                            percent: 25,
                            tint: .green,
                            accessibilityLabel: "25 percent")
                    }

                    HStack {
                        Text("50%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 50, alignment: .trailing)
                        UsageProgressBar(
                            percent: 50,
                            tint: .blue,
                            accessibilityLabel: "50 percent")
                    }

                    HStack {
                        Text("75%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 50, alignment: .trailing)
                        UsageProgressBar(
                            percent: 75,
                            tint: .orange,
                            accessibilityLabel: "75 percent")
                    }

                    HStack {
                        Text("90%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 50, alignment: .trailing)
                        UsageProgressBar(
                            percent: 90,
                            tint: .red,
                            accessibilityLabel: "90 percent")
                    }

                    HStack {
                        Text("100%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 50, alignment: .trailing)
                        UsageProgressBar(
                            percent: 100,
                            tint: .red,
                            accessibilityLabel: "100 percent")
                    }
                }
            }

            Divider()

            // MARK: - Color Variants
            VStack(alignment: .leading, spacing: 16) {
                Text("Color Variants")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Blue")
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        UsageProgressBar(
                            percent: 65,
                            tint: .blue,
                            accessibilityLabel: "Blue")
                    }

                    HStack {
                        Text("Green")
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        UsageProgressBar(
                            percent: 45,
                            tint: .green,
                            accessibilityLabel: "Green")
                    }

                    HStack {
                        Text("Orange")
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        UsageProgressBar(
                            percent: 75,
                            tint: .orange,
                            accessibilityLabel: "Orange")
                    }

                    HStack {
                        Text("Red")
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        UsageProgressBar(
                            percent: 90,
                            tint: .red,
                            accessibilityLabel: "Red")
                    }

                    HStack {
                        Text("Purple")
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        UsageProgressBar(
                            percent: 55,
                            tint: .purple,
                            accessibilityLabel: "Purple")
                    }

                    HStack {
                        Text("Custom")
                            .font(.caption)
                            .frame(width: 80, alignment: .leading)
                        UsageProgressBar(
                            percent: 70,
                            tint: Color(red: 0.3, green: 0.7, blue: 0.9),
                            accessibilityLabel: "Custom color")
                    }
                }
            }

            Divider()

            // MARK: - Animation Demo
            VStack(alignment: .leading, spacing: 16) {
                Text("Animation Test")
                    .font(.headline)

                AnimatedProgressDemo()
            }

            Divider()

            // MARK: - Real-World Examples
            VStack(alignment: .leading, spacing: 16) {
                Text("Real-World Examples")
                    .font(.headline)

                // API Usage Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("API Usage")
                            .font(.body.weight(.medium))
                        Spacer()
                        Text("1,234 / 2,000")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    UsageProgressBar(
                        percent: 61.7,
                        tint: .blue,
                        accessibilityLabel: "API usage")

                    HStack {
                        Text("61.7% used")
                            .font(.caption)
                        Spacer()
                        Text("Resets in 12 days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor)))

                // Budget Tracking
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Project Budget")
                            .font(.body.weight(.medium))
                        Spacer()
                        Text("$45 / $50")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    UsageProgressBar(
                        percent: 90,
                        tint: .orange,
                        accessibilityLabel: "Budget usage")

                    HStack {
                        Text("90% spent")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("Near limit")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fontWeight(.medium)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor)))

                // Team Member Quota
                HStack(spacing: 12) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text("JD")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("John Doe")
                            .font(.body.weight(.medium))

                        HStack(spacing: 4) {
                            Text("8,500 / 10,000")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            UsageProgressBar(
                                percent: 85,
                                tint: .red,
                                accessibilityLabel: "John Doe quota",
                                height: .compact)
                                .frame(maxWidth: 100)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor)))
            }
        }
        .padding(32)
        .frame(width: 500)
    }
}

/// Demonstrates the smooth spring animation
private struct AnimatedProgressDemo: View {
    @State private var percent: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spring animation (tap to randomize)")
                .font(.caption)
                .foregroundStyle(.secondary)

            UsageProgressBar(
                percent: self.percent,
                tint: .purple,
                accessibilityLabel: "Animation demo")
                .onTapGesture {
                    self.percent = Double.random(in: 10...100)
                }

            HStack {
                Button("0%") { self.percent = 0 }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                Button("25%") { self.percent = 25 }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                Button("50%") { self.percent = 50 }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                Button("75%") { self.percent = 75 }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                Button("100%") { self.percent = 100 }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProgressBarShowcase()
}

// MARK: - Usage Instructions

/*
 To test the improved progress bar:

 1. Create a new SwiftUI view in Xcode
 2. Copy this entire file content
 3. Use the #Preview to see all variants
 4. Test the animation by clicking buttons
 5. Verify VoiceOver reads percentages correctly

 Key improvements to observe:
 - Glossy top highlight (white gradient)
 - Subtle glow/shadow around filled portion
 - 3-color gradient for depth
 - Smooth spring animation (natural bounce)
 - Track border for definition
 - Three distinct size options

 Compare with the old version:
 - Smoother, more refined appearance
 - Better visual hierarchy
 - More professional and modern
 - Maintains accessibility
 */
