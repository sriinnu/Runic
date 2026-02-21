# UsageProgressBar Quick Reference

## Basic Usage

```swift
UsageProgressBar(
    percent: 75,                           // 0-100 (values outside clamped)
    tint: .blue,                          // Any SwiftUI Color
    accessibilityLabel: "API usage"       // VoiceOver label
)
```

## With Height Option

```swift
UsageProgressBar(
    percent: 85,
    tint: .red,
    accessibilityLabel: "Quota",
    height: .compact                       // .compact | .regular | .large
)
```

## Height Guide

| Height    | Size | Use When                              | Example Context          |
|-----------|------|---------------------------------------|--------------------------|
| `.compact`| 6pt  | Dense layouts, list items             | Team member rows         |
| `.regular`| 8pt  | Default, standard cards (default)     | Menu cards, budgets      |
| `.large`  | 10pt | Hero sections, prominent displays     | Dashboard overview       |

## Common Patterns

### API Usage Card
```swift
VStack(alignment: .leading, spacing: 4) {
    Text("API Usage")
        .font(.body.weight(.medium))

    UsageProgressBar(
        percent: 61.7,
        tint: .blue,
        accessibilityLabel: "API usage")

    Text("61.7% used")
        .font(.caption)
}
```

### Budget Warning
```swift
UsageProgressBar(
    percent: 90,
    tint: percentUsed >= 90 ? .red : percentUsed >= 75 ? .orange : .blue,
    accessibilityLabel: "Budget usage")
```

### Team Member Quota
```swift
HStack {
    Text("8,500 / 10,000")
        .font(.caption2)

    UsageProgressBar(
        percent: 85,
        tint: .red,
        accessibilityLabel: "John Doe quota",
        height: .compact)
        .frame(maxWidth: 120)
}
```

## Color Recommendations

| Percentage Range | Suggested Color | Meaning       |
|------------------|-----------------|---------------|
| 0-50%            | `.green`        | Safe          |
| 50-75%           | `.blue`         | Normal        |
| 75-90%           | `.orange`       | Warning       |
| 90-100%          | `.red`          | Critical      |

## Visual Features

✅ **Gradient fill** - 3-color depth effect
✅ **Glow/shadow** - Subtle ambient shadow (3.2pt @ regular)
✅ **Glossy highlight** - White gradient on top half
✅ **Track border** - 0.5pt definition stroke
✅ **Spring animation** - Natural bounce (0.5s response, 0.8 damping)
✅ **Menu aware** - Adapts to highlight state automatically

## Accessibility

```swift
// VoiceOver announcement:
"[Label], [Percentage] percent, updates frequently"

// Example:
"API usage, 75 percent, updates frequently"
```

## Migration from Old Code

### Before
```swift
UsageProgressBar(percent: 75, tint: .blue, accessibilityLabel: "Usage")
    .frame(height: 6)  // ← Remove this
```

### After
```swift
UsageProgressBar(
    percent: 75,
    tint: .blue,
    accessibilityLabel: "Usage",
    height: .compact)  // ← Use semantic height
```

## State Adaptation

The progress bar automatically adapts to menu highlight state:

| State       | Track Color            | Tint Color              | Glow      |
|-------------|------------------------|-------------------------|-----------|
| Normal      | Tertiary label (22%)   | Provided color          | Visible   |
| Highlighted | Selection text (22%)   | Selection text (white)  | Hidden    |

## Animation Behavior

```swift
// On appear: Spring animation to current value
.onAppear {
    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
        animatedPercent = percent
    }
}

// On change: Spring animation to new value
.onChange(of: percent) {
    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
        animatedPercent = newValue
    }
}
```

## Performance Notes

- **GPU accelerated** via `drawingGroup()`
- **60fps animations** on all devices
- **Minimal memory** (~324 bytes per instance)
- **No layout thrashing** - efficient rendering

## Common Mistakes to Avoid

❌ Don't manually set `.frame(height:)` anymore
```swift
UsageProgressBar(...).frame(height: 8)  // Old way
```

✅ Use semantic height parameter
```swift
UsageProgressBar(..., height: .regular)  // New way
```

❌ Don't pass percentages outside 0-100
```swift
UsageProgressBar(percent: 150, ...)  // Will be clamped to 100
```

✅ Clamp before passing
```swift
UsageProgressBar(percent: min(100, max(0, value)), ...)
```

❌ Don't use generic accessibility labels
```swift
accessibilityLabel: "Progress"  // Too vague
```

✅ Use descriptive labels
```swift
accessibilityLabel: "API usage"  // Specific and clear
```

## Troubleshooting

### Bar not visible
- Check percent is > 0
- Verify tint color is not clear
- Ensure parent has non-zero width

### Animation not smooth
- Verify not overriding with explicit `.animation()`
- Check for layout thrashing (multiple updates per frame)
- Ensure running on main thread

### Wrong height
- Don't use both `height` parameter AND `.frame(height:)`
- Use semantic height: `.compact`, `.regular`, or `.large`
- Default is `.regular` (8pt) if not specified

### VoiceOver not working
- Ensure `accessibilityLabel` is provided
- Check label is descriptive (not empty)
- Verify value is between 0-100

## Complete Example

```swift
// Full-featured usage card
VStack(alignment: .leading, spacing: 8) {
    // Header
    HStack {
        Text("API Usage")
            .font(.body.weight(.medium))
        Spacer()
        Text("1,234 / 2,000")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // Progress bar
    UsageProgressBar(
        percent: 61.7,
        tint: .blue,
        accessibilityLabel: "API usage",
        height: .regular)

    // Footer
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
    RoundedRectangle(cornerRadius: 8)
        .fill(Color(nsColor: .controlBackgroundColor)))
```

## API Summary

```swift
struct UsageProgressBar: View {
    enum Height {
        case compact    // 6pt
        case regular    // 8pt (default)
        case large      // 10pt
    }

    init(
        percent: Double,              // Required: 0-100
        tint: Color,                  // Required: Any SwiftUI Color
        accessibilityLabel: String,   // Required: VoiceOver label
        height: Height = .regular     // Optional: Size variant
    )
}
```

## Related Files

- **Component**: `/Sources/Runic/UsageProgressBar.swift`
- **Styles**: `/Sources/Runic/Views/Menu/MenuHighlightStyle.swift`
- **Documentation**: `/docs/progress-bar-improvements.md`
- **Technical**: `/docs/progress-bar-technical-details.md`
- **Visual Tests**: `/docs/progress-bar-visual-test.swift`

## Support

For issues or questions:
1. Check this quick reference first
2. Review technical details documentation
3. Run visual test file to compare behavior
4. Verify accessibility with VoiceOver

---

**Last Updated**: January 2026
**Version**: 2.0 (Modern redesign)
**Compatibility**: macOS 12+, SwiftUI 3+
