# Runic Menubar Icon - Implementation Guide

**Target:** IconRenderer.swift
**Current File:** `/Users/srinivaspendela/Sriinnu/AI/Runic/Sources/Runic/Core/Rendering/IconRenderer.swift`

---

## Overview

This guide provides step-by-step instructions for implementing the recommended **Infinity Symbol + Provider Icon** design in the existing IconRenderer architecture.

---

## Current Architecture Analysis

### Existing Components

**IconRenderer.swift Key Elements:**

1. **Output Specifications (Lines 51-56):**
   ```swift
   private static let baseSize = NSSize(width: 38, height: 22)
   private static let outputSize = NSSize(width: 38, height: 22)
   private static let outputScale: CGFloat = 2
   ```

2. **Wave Logo Template (Lines 57-64):**
   ```swift
   private static let waveLogoTemplate: NSImage? = {
       guard let url = Bundle.main.url(forResource: "RunicMenubarIcon", withExtension: "svg"),
             let image = NSImage(contentsOf: url) else {
           return nil
       }
       return image
   }()
   ```

3. **Icon Cache System (Lines 84-143):**
   - `IconCacheKey` struct with hashable properties
   - `IconCacheStore` class with LRU eviction
   - Cache limit: `PerformanceConstants.iconCacheSize`

4. **Main Rendering Function (Lines 177-247):**
   - `makeIcon()` - Entry point for icon generation
   - Supports pressure colors, stale states, animations
   - Returns cached icons when possible

5. **Drawing Functions:**
   - `drawWaveLogo()` (Lines 516-546) - Current wave rendering
   - `drawStatusOverlay()` (Lines 781-813) - Error/status indicators
   - `drawUnbraidMorph()` (Lines 668-755) - Animation morphs

---

## Implementation Plan

### Phase 1: Add Infinity Symbol SVG Resource

**Step 1.1: Create Infinity Icon SVG**

Create: `/Users/srinivaspendela/Sriinnu/AI/Runic/Sources/Runic/Resources/RunicMenubarIconInfinity.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 48" fill="none">
  <!-- Infinity path optimized for template rendering -->
  <path d="M 12,24
           C 12,14 20,10 28,14
           C 36,18 36,24 40,24
           C 44,24 44,18 52,14
           C 60,10 68,14 68,24
           C 68,34 60,38 52,34
           C 44,30 44,24 40,24
           C 36,24 36,30 28,34
           C 20,38 12,34 12,24 Z"
        stroke="#14B8A6"
        stroke-width="8"
        fill="none"
        stroke-linecap="round"
        stroke-linejoin="round"/>
</svg>
```

**Step 1.2: Update Bundle Resources**

Ensure SVG is included in `Package.swift` or Xcode target resources.

---

### Phase 2: Modify IconRenderer.swift

**Step 2.1: Add Infinity Logo Template**

Add after line 64 (after `waveLogoTemplate`):

```swift
// Infinity logo base template - loaded lazily from Resources
private static let infinityLogoTemplate: NSImage? = {
    guard let url = Bundle.main.url(forResource: "RunicMenubarIconInfinity", withExtension: "svg"),
          let image = NSImage(contentsOf: url) else {
        return nil
    }
    return image
}()
```

**Step 2.2: Update Output Size (Optional)**

Increase size from 38×22 to 40×24 for better clarity (line 51-52):

```swift
private static let baseSize = NSSize(width: 40, height: 24)
private static let outputSize = NSSize(width: 40, height: 24)
```

**Step 2.3: Add Icon Style Enum**

Add new enum to control which icon design to use:

```swift
enum IconDesign: Sendable {
    case wave           // Current wave logo
    case infinity       // Infinity symbol with provider icon
    case hybrid         // Infinity outline with center bar
}
```

**Step 2.4: Update makeIcon() Signature**

Modify `makeIcon()` function (line 177) to accept design parameter:

```swift
static func makeIcon(
    primaryRemaining: Double?,
    weeklyRemaining: Double?,
    creditsRemaining: Double?,
    stale: Bool,
    style: IconStyle,
    design: IconDesign = .infinity,  // NEW PARAMETER
    blink: CGFloat = 0,
    wiggle: CGFloat = 0,
    tilt: CGFloat = 0,
    statusIndicator: ProviderStatusIndicator = .none,
    appearance: IconAppearance = .template,
    dataMode: IconDataMode = .remaining) -> NSImage
```

**Step 2.5: Add Design Routing Logic**

Inside `makeIcon()`, route to appropriate drawing function:

```swift
let render = {
    self.renderImage(isTemplate: appearance == .template) {
        let topValue = primaryRemaining
        let bottomValue = weeklyRemaining
        let creditsRatio = creditsRemaining.map { min($0 / Self.creditsCap * 100, 100) }
        let pressure = Self.usagePressure(
            primary: topValue,
            weekly: bottomValue,
            credits: creditsRatio,
            dataMode: dataMode)
        let accentColor = Self.vibrantAccentColor(pressure: pressure, stale: stale)
        let baseColor = appearance == .template ? NSColor.labelColor : accentColor

        // NEW: Route based on design type
        switch design {
        case .wave:
            let fillPercent = Self.iconFillPercent(
                primary: topValue,
                weekly: bottomValue,
                credits: creditsRatio,
                dataMode: dataMode)
            Self.drawWaveLogo(
                fillPercent: fillPercent,
                baseColor: baseColor.withAlphaComponent(stale ? 0.18 : 0.28),
                fillColor: baseColor.withAlphaComponent(stale ? 0.55 : 1.0))

        case .infinity:
            Self.drawInfinityLogo(
                providerStyle: Self.sigilStyle(for: style),
                pressure: pressure,
                stale: stale,
                baseColor: baseColor,
                appearance: appearance)

        case .hybrid:
            let fillPercent = Self.iconFillPercent(
                primary: topValue,
                weekly: bottomValue,
                credits: creditsRatio,
                dataMode: dataMode)
            Self.drawHybridLogo(
                providerStyle: Self.sigilStyle(for: style),
                fillPercent: fillPercent,
                pressure: pressure,
                stale: stale,
                baseColor: baseColor,
                appearance: appearance)
        }

        // Status overlay remains the same
        let overlayColor = appearance == .template
            ? NSColor.labelColor
            : NSColor.white.withAlphaComponent(0.92)
        Self.drawStatusOverlay(indicator: statusIndicator, color: overlayColor)
    }
}
```

---

### Phase 3: Implement Drawing Functions

**Step 3.1: Create drawInfinityLogo() Function**

Add new function after `drawWaveLogo()`:

```swift
/// Draws infinity symbol with provider icon in center
private static func drawInfinityLogo(
    providerStyle: SigilStyle,
    pressure: Double,
    stale: Bool,
    baseColor: NSColor,
    appearance: IconAppearance)
{
    guard let infinityLogo = self.infinityLogoTemplate,
          let ctx = NSGraphicsContext.current?.cgContext else {
        return
    }

    let rect = CGRect(origin: .zero, size: self.outputSize)
    let opacity: CGFloat = stale ? 0.55 : 1.0

    // Draw infinity path
    ctx.saveGState()
    infinityLogo.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    ctx.setBlendMode(.sourceIn)
    baseColor.setFill()
    ctx.fill(rect)
    ctx.restoreGState()

    // Draw provider icon in center gap
    let centerX = rect.midX
    let centerY = rect.midY
    let iconSize: CGFloat = 16 // 8pt @ 2x scale
    let iconRect = RectPx(
        x: Int((centerX - iconSize / 2) * outputScale),
        y: Int((centerY - iconSize / 2) * outputScale),
        w: Int(iconSize * outputScale),
        h: Int(iconSize * outputScale))

    // Create white background circle for icon visibility
    let bgCircleRadius: CGFloat = 10
    let bgCircle = NSBezierPath(
        ovalIn: CGRect(
            x: centerX - bgCircleRadius,
            y: centerY - bgCircleRadius,
            width: bgCircleRadius * 2,
            height: bgCircleRadius * 2))
    NSColor.white.withAlphaComponent(appearance == .template ? 0.0 : 0.9).setFill()
    bgCircle.fill()

    // Draw provider sigil
    ctx.saveGState()
    ctx.setBlendMode(appearance == .template ? .clear : .normal)
    self.drawSigil(providerStyle, in: iconRect)
    ctx.restoreGState()
}
```

**Step 3.2: Create drawHybridLogo() Function**

Add hybrid variant combining infinity outline with center bar:

```swift
/// Draws infinity outline with usage bar in center and provider badge
private static func drawHybridLogo(
    providerStyle: SigilStyle,
    fillPercent: Double,
    pressure: Double,
    stale: Bool,
    baseColor: NSColor,
    appearance: IconAppearance)
{
    guard let infinityLogo = self.infinityLogoTemplate,
          let ctx = NSGraphicsContext.current?.cgContext else {
        return
    }

    let rect = CGRect(origin: .zero, size: self.outputSize)
    let opacity: CGFloat = stale ? 0.55 : 1.0

    // Draw infinity outline (lighter opacity)
    ctx.saveGState()
    infinityLogo.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    ctx.setBlendMode(.sourceIn)
    baseColor.withAlphaComponent(0.3 * opacity).setFill()
    ctx.fill(rect)
    ctx.restoreGState()

    // Draw center usage bar
    let centerX = rect.midX
    let centerY = rect.midY
    let barWidth: CGFloat = 16
    let barHeight: CGFloat = 16
    let barX = centerX - barWidth / 2
    let barY = centerY - barHeight / 2

    // Bar background
    let barBgPath = NSBezierPath(
        roundedRect: CGRect(x: barX, y: barY, width: barWidth, height: barHeight),
        xRadius: 3,
        yRadius: 3)
    baseColor.withAlphaComponent(0.15 * opacity).setFill()
    barBgPath.fill()

    // Bar fill (from bottom)
    let fillHeight = barHeight * CGFloat(max(0, min(fillPercent, 1)))
    let barFillPath = NSBezierPath(
        roundedRect: CGRect(x: barX, y: barY + barHeight - fillHeight, width: barWidth, height: fillHeight),
        xRadius: 3,
        yRadius: 3)
    baseColor.withAlphaComponent(opacity).setFill()
    barFillPath.fill()

    // Draw provider badge in corner
    let badgeX: CGFloat = rect.maxX - 14
    let badgeY: CGFloat = 8
    let badgeRadius: CGFloat = 6

    let badgeBg = NSBezierPath(
        ovalIn: CGRect(x: badgeX, y: badgeY, width: badgeRadius * 2, height: badgeRadius * 2))
    NSColor.white.withAlphaComponent(appearance == .template ? 0.0 : 0.9).setFill()
    badgeBg.fill()

    let badgeStroke = NSBezierPath(
        ovalIn: CGRect(x: badgeX, y: badgeY, width: badgeRadius * 2, height: badgeRadius * 2))
    badgeStroke.lineWidth = 1.5
    baseColor.withAlphaComponent(opacity).setStroke()
    badgeStroke.stroke()

    // Draw mini provider sigil in badge
    let badgeIconRect = RectPx(
        x: Int((badgeX + badgeRadius - 2) * outputScale),
        y: Int((badgeY + badgeRadius - 2) * outputScale),
        w: Int(4 * outputScale),
        h: Int(4 * outputScale))
    ctx.saveGState()
    ctx.setBlendMode(appearance == .template ? .clear : .normal)
    self.drawSigil(providerStyle, in: badgeIconRect)
    ctx.restoreGState()
}
```

---

### Phase 4: Update Cache Key

**Step 4.1: Add Design to IconCacheKey**

Modify `IconCacheKey` struct (line 84) to include design:

```swift
private struct IconCacheKey: Hashable {
    let primary: Int
    let weekly: Int
    let credits: Int
    let stale: Bool
    let style: Int
    let indicator: Int
    let appearance: Int
    let dataMode: Int
    let design: Int  // NEW
}
```

**Step 4.2: Add Design Key Helper**

Add helper function after other key helpers:

```swift
private static func designKey(_ design: IconDesign) -> Int {
    switch design {
    case .wave: 0
    case .infinity: 1
    case .hybrid: 2
    }
}
```

**Step 4.3: Update Cache Key Creation**

Modify cache key creation in `makeIcon()`:

```swift
let key = IconCacheKey(
    primary: self.quantizedPercent(primaryRemaining),
    weekly: self.quantizedPercent(weeklyRemaining),
    credits: self.quantizedCredits(creditsRemaining),
    stale: stale,
    style: self.styleKey(style),
    indicator: self.indicatorKey(statusIndicator),
    appearance: self.appearanceKey(appearance),
    dataMode: self.dataModeKey(dataMode),
    design: self.designKey(design))  // NEW
```

---

### Phase 5: Integrate with Settings

**Step 5.1: Add User Preference in SettingsStore**

Add to `SettingsStore.swift`:

```swift
@AppStorage("iconDesign") var iconDesign: IconDesign = .infinity
```

**Step 5.2: Add Preference UI**

In preferences pane (e.g., `PreferencesGeneralPane.swift`), add picker:

```swift
Picker("Menubar Icon Style", selection: $settings.iconDesign) {
    Text("Infinity Symbol").tag(IconDesign.infinity)
    Text("Wave Logo (Classic)").tag(IconDesign.wave)
    Text("Hybrid").tag(IconDesign.hybrid)
}
.pickerStyle(.segmented)
```

**Step 5.3: Pass Design to makeIcon()**

Update all calls to `makeIcon()` to use user preference:

```swift
let icon = IconRenderer.makeIcon(
    primaryRemaining: snap.sessionRemaining,
    weeklyRemaining: snap.weeklyRemaining,
    creditsRemaining: snap.creditsRemaining,
    stale: isStale,
    style: iconStyle,
    design: settings.iconDesign,  // NEW
    statusIndicator: statusIndicator,
    appearance: settings.iconAppearance,
    dataMode: settings.iconDataMode)
```

---

## Testing Plan

### Visual Testing

**Test Matrix:**

| Size | Design | Provider | Pressure | Stale | Template | Expected |
|------|--------|----------|----------|-------|----------|----------|
| 40×24pt | Infinity | Claude | 0% | No | Yes | Clear infinity with Claude slits |
| 40×24pt | Infinity | Codex | 50% | No | Yes | Orange infinity with square eyes |
| 40×24pt | Infinity | Gemini | 90% | No | Yes | Red infinity with diamond |
| 40×24pt | Infinity | Claude | 30% | Yes | Yes | Teal infinity at 55% opacity |
| 40×24pt | Wave | — | 65% | No | Yes | Current wave with bars |
| 40×24pt | Hybrid | Cursor | 75% | No | Yes | Infinity outline + bar + badge |

**Manual Test Steps:**

1. **Build and Run:**
   ```bash
   swift build -c release
   open .build/release/Runic.app
   ```

2. **Test Provider Switching:**
   - Enable multiple providers (Claude, Codex, Gemini)
   - Verify icon updates when switching active provider
   - Check provider icon visibility in center

3. **Test Pressure Colors:**
   - Simulate different usage levels (0%, 50%, 80%, 100%)
   - Verify color transitions: teal → orange → red
   - Check template mode adapts to system theme

4. **Test Display Sizes:**
   - Test on Retina (2×) and non-Retina displays
   - Verify clarity at 18pt, 22pt, 24pt, 28pt
   - Check pixel alignment (no blurry edges)

5. **Test Dark Mode:**
   - Switch system appearance light ↔ dark
   - Verify template rendering adapts correctly
   - Check vibrant mode colors remain consistent

6. **Test Stale State:**
   - Disconnect network or pause auto-refresh
   - Wait >5 minutes for data to become stale
   - Verify 55% opacity applied correctly

### Performance Testing

**Cache Efficiency:**

```swift
// Add debug logging to IconCacheStore
func cachedIcon(for key: IconCacheKey) -> NSImage? {
    self.lock.lock()
    defer { self.lock.unlock() }
    let hit = self.cache[key] != nil
    print("Cache \(hit ? "HIT" : "MISS") for key: \(key)")
    return self.cache[key]
}
```

**Expected Results:**
- Cache hit rate >80% during normal operation
- Cache size stays <100 entries (PerformanceConstants.iconCacheSize = 64)
- No memory leaks (check with Instruments)

**Rendering Speed:**

```swift
// Measure rendering time
let start = CFAbsoluteTimeGetCurrent()
let icon = IconRenderer.makeIcon(...)
let elapsed = CFAbsoluteTimeGetCurrent() - start
assert(elapsed < 0.016, "Icon rendering exceeded 16ms (60 FPS)")
```

**Expected Results:**
- First render (cache miss): <10ms
- Cached render: <0.5ms
- No dropped frames during animations

---

## Migration Strategy

### Rollout Plan

**Option 1: Immediate Switch (Recommended)**

- Default to `IconDesign.infinity` for all users
- Keep wave logo available as preference option
- Announce change in release notes

**Option 2: Gradual Rollout**

- Default to wave logo for existing users
- Default to infinity for new installs
- Encourage switch via in-app notification

**Option 3: A/B Testing**

- Randomly assign 50% of users to infinity design
- Track engagement metrics (menu opens, preference changes)
- Choose winner after 2 weeks

### Backward Compatibility

Maintain wave logo indefinitely:
- Keep `drawWaveLogo()` function
- Keep `RunicMenubarIcon.svg` resource
- Allow users to switch back in preferences

### Release Notes Template

```markdown
## New Menubar Icon Design

We've redesigned Runic's menubar icon with a fresh "infinity symbol" concept that:

- **Symbolizes continuous monitoring** - The infinity loops represent Runic's eyes watching your AI usage
- **Shows your active provider** - The icon in the center indicates which AI service you're currently using
- **Adapts to usage levels** - Color changes from teal (safe) to orange (warning) to red (critical)
- **Clearer at all sizes** - Simpler design ensures visibility on any display

**Prefer the classic wave design?** You can switch back in Preferences → General → Menubar Icon Style.
```

---

## Troubleshooting

### Common Issues

**Issue 1: Provider Icon Not Visible**

**Symptom:** Infinity loops render, but center icon is missing

**Solution:**
- Check `drawSigil()` is being called with correct `RectPx`
- Verify blend mode is set correctly (`.clear` for template, `.normal` for vibrant)
- Ensure provider style matches available cases in `SigilStyle` enum

**Issue 2: Blurry Rendering**

**Symptom:** Icon edges appear fuzzy or aliased

**Solution:**
- Verify `outputScale = 2` for Retina displays
- Check pixel alignment: all coordinates should be integers at 2× scale
- Use `snap()` function to align to pixel grid

**Issue 3: Wrong Colors in Dark Mode**

**Symptom:** Icon is too dark or invisible in dark menubar

**Solution:**
- Ensure `isTemplate = true` for template rendering
- Check `NSColor.labelColor` is used for template mode
- Verify system appearance detection is working

**Issue 4: Cache Growing Too Large**

**Symptom:** Memory usage increases over time

**Solution:**
- Check `iconCacheLimit` is set correctly
- Verify LRU eviction is working in `IconCacheStore.storeIcon()`
- Consider reducing quantization levels if cache still grows

**Issue 5: Animation Stuttering**

**Symptom:** Icon animations drop frames

**Solution:**
- Profile with Instruments (Time Profiler)
- Check cache hit rate during animations
- Pre-cache morph frames in `MorphCache`
- Reduce animation complexity

---

## Future Enhancements

### Phase 2 Features (Post-Launch)

1. **Animated Provider Switching:**
   - Smooth cross-fade when provider changes
   - Morph old icon into new icon over 0.3s

2. **Usage Percentage Tooltip:**
   - On hover, show exact percentages
   - Display provider name and sync status

3. **Custom Icon Colors:**
   - User-selectable color schemes
   - Match system accent color option

4. **Accessibility Improvements:**
   - VoiceOver descriptions for all states
   - High contrast mode support
   - Reduced motion alternative

5. **Icon Animation Library:**
   - Pulse during sync
   - Flash on quota alerts
   - Subtle breathing effect when idle

---

## Appendix: Code Snippets

### Complete drawInfinityLogo() with Error Handling

```swift
private static func drawInfinityLogo(
    providerStyle: SigilStyle,
    pressure: Double,
    stale: Bool,
    baseColor: NSColor,
    appearance: IconAppearance)
{
    guard let infinityLogo = self.infinityLogoTemplate else {
        // Fallback: draw simple circle if template fails to load
        let fallbackPath = NSBezierPath(ovalIn: CGRect(x: 8, y: 6, width: 24, height: 12))
        fallbackPath.lineWidth = 4
        baseColor.setStroke()
        fallbackPath.stroke()
        return
    }

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        return
    }

    let rect = CGRect(origin: .zero, size: self.outputSize)
    let opacity: CGFloat = stale ? 0.55 : 1.0

    // Draw infinity path
    ctx.saveGState()
    infinityLogo.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    ctx.setBlendMode(.sourceIn)
    baseColor.withAlphaComponent(opacity).setFill()
    ctx.fill(rect)
    ctx.restoreGState()

    // Draw provider icon in center gap
    let centerX = rect.midX
    let centerY = rect.midY
    let iconSize: CGFloat = 16 // 8pt @ 2x scale
    let iconRect = RectPx(
        x: Int((centerX - iconSize / 2) * outputScale),
        y: Int((centerY - iconSize / 2) * outputScale),
        w: Int(iconSize * outputScale),
        h: Int(iconSize * outputScale))

    // Create white background circle for icon visibility (vibrant mode only)
    if appearance == .vibrant {
        let bgCircleRadius: CGFloat = 10
        let bgCircle = NSBezierPath(
            ovalIn: CGRect(
                x: centerX - bgCircleRadius,
                y: centerY - bgCircleRadius,
                width: bgCircleRadius * 2,
                height: bgCircleRadius * 2))
        NSColor.white.withAlphaComponent(0.9).setFill()
        bgCircle.fill()
    }

    // Draw provider sigil
    ctx.saveGState()
    ctx.setBlendMode(appearance == .template ? .clear : .normal)
    self.drawSigil(providerStyle, in: iconRect)
    ctx.restoreGState()
}
```

### Settings Integration Example

```swift
// In SettingsStore.swift
@AppStorage("iconDesign") var iconDesign: IconDesign = .infinity
@AppStorage("iconAppearance") var iconAppearance: IconAppearance = .template
@AppStorage("iconDataMode") var iconDataMode: IconDataMode = .remaining

// In StatusItemController.swift
func updateIcon() {
    let icon = IconRenderer.makeIcon(
        primaryRemaining: self.store.sessionRemaining,
        weeklyRemaining: self.store.weeklyRemaining,
        creditsRemaining: self.store.creditsRemaining,
        stale: self.store.isStale,
        style: self.store.activeProvider.iconStyle,
        design: self.settings.iconDesign,
        statusIndicator: self.statusIndicator,
        appearance: self.settings.iconAppearance,
        dataMode: self.settings.iconDataMode)

    self.statusItem.button?.image = icon
}
```

---

## Summary

This implementation guide provides a complete roadmap for adding the infinity symbol icon design to Runic while:

- Maintaining backward compatibility with the wave logo
- Preserving existing performance characteristics
- Adding minimal code complexity
- Enabling user choice through preferences
- Supporting future enhancements

**Estimated Implementation Time:** 8-12 hours for experienced Swift developer

**Key Files to Modify:**
1. `IconRenderer.swift` - Core rendering logic
2. `SettingsStore.swift` - User preferences
3. `PreferencesGeneralPane.swift` - UI controls
4. `StatusItemController.swift` - Icon updates

**New Files to Create:**
1. `RunicMenubarIconInfinity.svg` - Infinity template
2. Unit tests for new rendering functions

**Testing Checklist:**
- [ ] Visual testing on Retina display
- [ ] Visual testing on non-Retina display
- [ ] Dark mode rendering
- [ ] Light mode rendering
- [ ] All provider icons visible
- [ ] Pressure colors correct
- [ ] Stale state rendering
- [ ] Cache hit rate >80%
- [ ] No memory leaks
- [ ] Animation performance >60 FPS
- [ ] User preference persistence
- [ ] A/B testing data collected (optional)
