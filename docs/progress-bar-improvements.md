# Progress Bar Design Improvements

## Overview

The `UsageProgressBar` component has been completely redesigned with modern visual effects and enhanced functionality.

## Key Improvements

### 1. Enhanced Gradient Effect
- **Before**: Simple 2-color gradient (top to bottom)
- **After**: 3-color gradient with depth, creating a more dimensional appearance
- The new gradient uses `[0.98, 0.85, 0.92]` opacity levels for a subtle wave effect

```swift
// Before
LinearGradient(
    colors: [
        base.opacity(0.95),
        base.opacity(0.75),
    ],
    startPoint: .top,
    endPoint: .bottom)

// After
LinearGradient(
    colors: [
        base.opacity(0.98),
        base.opacity(0.85),
        base.opacity(0.92),
    ],
    startPoint: .top,
    endPoint: .bottom)
```

### 2. Glow Effect
Added a subtle shadow that creates a soft glow around the filled portion:
- Radius: 40% of bar height (adaptive to size)
- Color: Matches the tint color at 30% opacity
- Automatically disabled when highlighted (menu selection state)

```swift
.shadow(
    color: tintColor.opacity(self.isHighlighted ? 0 : 0.3),
    radius: self.barHeight * 0.4,
    x: 0,
    y: 0)
```

### 3. Glossy Top Highlight
Added a subtle white highlight overlay on the top half for a glossy, polished look:

```swift
.overlay {
    Capsule()
        .fill(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.2),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .center))
        .frame(width: max(fillWidth, self.barHeight))
}
```

### 4. Enhanced Track Styling
The background track now has a subtle border for better definition:

```swift
Capsule()
    .fill(trackColor)
    .overlay {
        Capsule()
            .strokeBorder(
                trackColor.opacity(0.3),
                lineWidth: 0.5)
    }
```

### 5. Spring-Based Animation
Replaced linear easing with natural spring physics:

```swift
// Before
withAnimation(.easeOut(duration: 0.35)) {
    self.animatedPercent = newValue
}

// After
withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
    self.animatedPercent = newValue
}
```

**Benefits:**
- More natural, organic movement
- Subtle bounce adds personality
- Better matches macOS system animations

### 6. Height Options
Added three size variants for different contexts:

```swift
enum Height {
    case compact    // 6pt - dense layouts, team rows
    case regular    // 8pt - default, menu cards
    case large      // 10pt - prominent displays
}
```

**Usage Examples:**

```swift
// Compact - for team member rows
UsageProgressBar(
    percent: 75,
    tint: .blue,
    accessibilityLabel: "Quota usage",
    height: .compact)

// Regular - default, most menu cards (parameter optional)
UsageProgressBar(
    percent: 60,
    tint: .green,
    accessibilityLabel: "API usage")

// Large - for dashboard hero sections
UsageProgressBar(
    percent: 85,
    tint: .orange,
    accessibilityLabel: "Team usage",
    height: .large)
```

### 7. Enhanced Accessibility
Improved VoiceOver support:

```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel(self.accessibilityLabel)
.accessibilityValue("\(Int(self.clamped)) percent")
.accessibilityAddTraits(.updatesFrequently)
```

**Improvements:**
- Marks element as frequently updating for better screen reader experience
- Ignores child elements to prevent confusion
- Clear percentage value announcement

## Implementation Locations

### Files Updated

1. **`/Sources/Runic/UsageProgressBar.swift`**
   - Core component with all visual improvements
   - Added height enum and gradient enhancements

2. **`/Sources/Runic/Views/Team/TeamMemberRow.swift`**
   - Updated to use `.compact` height for dense layout

3. **`/Sources/Runic/Views/Team/TeamDashboardView.swift`**
   - Updated to use `.large` height for prominent display

4. **`/Sources/Runic/Views/Team/TeamManagementView.swift`**
   - Updated to use `.regular` height explicitly

### Usage Across Codebase

The progress bar is used in these contexts:

| Location | Purpose | Height |
|----------|---------|--------|
| `MenuCardView.swift` | Provider usage metrics | Regular (default) |
| `ProjectBudgetMenuView.swift` | Budget tracking | Regular (default) |
| `TeamMemberRow.swift` | Member quota in list | Compact |
| `TeamDashboardView.swift` | Team overview hero | Large |
| `TeamManagementView.swift` | Team quota summary | Regular |

## Visual Comparison

### Before
- Flat gradient (2 colors)
- No glow or shadow
- Simple easeOut animation
- Fixed 8pt height
- Basic track background

### After
- Rich 3-color gradient with depth
- Subtle glow effect (shadow radius: 3.2pt @ 8pt height)
- Glossy top highlight overlay
- Spring physics animation (response: 0.5s, damping: 0.8)
- Three height options (6pt, 8pt, 10pt)
- Enhanced track with subtle border
- Improved accessibility traits

## Performance Considerations

All visual effects use:
- `drawingGroup()` for GPU acceleration
- Efficient SwiftUI modifiers
- No runtime calculations in body
- Smooth 60fps animations

## Design Principles

1. **Subtle but Refined**: Effects are noticeable but not distracting
2. **Context-Aware**: Adapts to menu highlight state automatically
3. **Accessible**: Full VoiceOver support with proper traits
4. **Consistent**: Uses MenuHighlightStyle for color consistency
5. **Performant**: GPU-accelerated rendering
6. **Flexible**: Height options for different contexts

## Migration Guide

Existing code continues to work with no changes required. The `height` parameter is optional and defaults to `.regular` (8pt).

**Optional Enhancement:**
To take advantage of the new height options:

```swift
// For compact layouts (was .frame(height: 4-6))
UsageProgressBar(..., height: .compact)

// For default layouts (was .frame(height: 8))
UsageProgressBar(...) // or height: .regular

// For prominent displays (was .frame(height: 10-12))
UsageProgressBar(..., height: .large)
```

## Future Enhancements

Potential future additions:
- [ ] Animated shimmer effect for loading states
- [ ] Pulsing animation for critical thresholds
- [ ] Color transitions when crossing thresholds
- [ ] Custom height values beyond presets
- [ ] Striped pattern option for different data types
