# Runic Menubar Icon - Size Specifications

**Technical Reference for macOS Menubar Icon Rendering**

---

## macOS Menubar Guidelines

### Apple Human Interface Guidelines

**Recommended Sizes:**
- **Standard:** 18-22pt (square or proportional)
- **Detailed:** Up to 28pt for complex icons
- **Spacing:** 2pt padding from edges (safe area)

**Display Considerations:**
- **Retina (@2x):** All icons must provide 2× pixel density assets
- **Non-Retina (@1x):** Maintain backward compatibility
- **Dark Mode:** Template rendering adapts automatically
- **Positioning:** Vertically centered in menubar (22pt tall menubar)

**Template Image Requirements:**
- Single-channel alpha (black with alpha channel)
- System colorizes based on menubar theme
- No embedded colors (except in vibrant mode)
- Smooth anti-aliasing for curves

---

## Runic Icon Specifications

### Current Implementation

**File:** `IconRenderer.swift` (Lines 51-56)

```swift
private static let baseSize = NSSize(width: 38, height: 22)
private static let outputSize = NSSize(width: 38, height: 22)
private static let outputScale: CGFloat = 2
```

**Analysis:**
- **Points:** 38×22pt (width × height)
- **Pixels (@2x):** 76×44px
- **Aspect ratio:** ~1.73:1 (rectangular, not square)
- **Actual rendered height:** 22pt (matches macOS menubar height)

**Why Rectangular?**
- Wider icon provides more space for usage bars
- Horizontal orientation fits menubar layout
- Wave shape naturally extends horizontally

---

## Recommended Sizes by Design

### Option A: Infinity Symbol + Provider Icon

**Recommended Size:** 40×24pt (80×48px @2x)

#### Dimensions Breakdown

| Element | Points | Pixels @2x | Notes |
|---------|--------|------------|-------|
| **Total Width** | 40pt | 80px | +2pt from current for breathing room |
| **Total Height** | 24pt | 48px | +2pt from current for clarity |
| **Infinity Stroke** | 4pt | 8px | Thick enough to be visible, not overwhelming |
| **Loop Diameter** | 14pt | 28px | Per loop (left and right) |
| **Loop Radius** | 7pt | 14px | From center of each loop |
| **Center Gap Width** | 10-12pt | 20-24px | Space for provider icon |
| **Center Gap Height** | 12-14pt | 24-28px | Vertical space for provider icon |
| **Provider Icon** | 8×8pt | 16×16px | Fits comfortably in center gap |
| **Safe Padding** | 2pt | 4px | From edges to infinity loops |

#### Scaling Options

| Size Preset | Points | Use Case | Legibility |
|-------------|--------|----------|------------|
| **Small** | 36×20pt | Compact menubar | ★★★☆☆ |
| **Medium** | 40×24pt | Recommended | ★★★★★ |
| **Large** | 44×28pt | High-DPI/accessibility | ★★★★★ |

**Recommendation:** Use **40×24pt** as default for best balance.

---

### Option B: Wave Logo (Current)

**Current Size:** 38×22pt (76×44px @2x)

#### Refinement Proposal: 42×26pt (84×52px @2x)

| Element | Current | Proposed | Change |
|---------|---------|----------|--------|
| **Total Width** | 38pt | 42pt | +4pt |
| **Total Height** | 22pt | 26pt | +4pt |
| **Wave Stroke** | 18px | 20px | +2px (thicker) |
| **Center Circle** | 32px | 36px | +4px (larger) |
| **Bar Width** | 8px | 10px | +2px (more visible) |
| **Bar Max Height** | 22-26px | 26-32px | +4-6px (taller) |

**Rationale:**
- Larger bars easier to read
- More vertical space reduces cramping
- Maintains aspect ratio (~1.6:1)

---

### Option C: Hybrid

**Recommended Size:** 40×24pt (80×48px @2x)

#### Dimensions Breakdown

| Element | Points | Pixels @2x | Notes |
|---------|--------|------------|-------|
| **Total Width** | 40pt | 80px | Same as Option A |
| **Total Height** | 24pt | 48px | Same as Option A |
| **Infinity Stroke** | 3pt | 6px | Thinner outline (frame only) |
| **Loop Radius** | 7pt | 14px | Same as Option A |
| **Center Bar Width** | 8pt | 16px | Narrower than gap (10-12pt) |
| **Center Bar Height** | 12pt | 24px | Nearly full gap height |
| **Bar Corner Radius** | 3pt | 6px | Rounded for modern look |
| **Provider Badge** | 6×6pt | 12×12px | Small circle in corner |
| **Badge Stroke** | 1.5pt | 3px | Outline around badge |

---

## Pixel-Perfect Rendering

### Alignment Rules (@2x Scale)

**All coordinates must be even numbers at 2× to avoid sub-pixel rendering:**

```swift
// GOOD: Aligns to pixel grid
let x = 20.0 // → 40px @ 2x ✓
let y = 12.0 // → 24px @ 2x ✓

// BAD: Sub-pixel rendering (blurry)
let x = 20.5 // → 41px @ 2x (half-pixel) ✗
let y = 12.3 // → 24.6px @ 2x (fractional) ✗
```

**Helper Function (from IconRenderer.swift):**

```swift
private static func snap(_ value: CGFloat) -> CGFloat {
    (value * self.outputScale).rounded() / self.outputScale
}
```

**Usage:**
```swift
let iconX = snap(15.5) // → 16.0 (aligned)
let iconY = snap(11.7) // → 12.0 (aligned)
```

---

## SVG Viewbox Specifications

### Current Wave Logo

**File:** `RunicMenubarIcon.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="46 78 164 100" fill="none">
```

**Analysis:**
- **Viewbox:** 46,78 → 210,178 (164×100 effective area)
- **Aspect ratio:** 1.64:1
- **Renders to:** 38×22pt via IconRenderer scaling

### Recommended Infinity SVG

**File:** `RunicMenubarIconInfinity.svg` (new)

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 48" fill="none">
```

**Analysis:**
- **Viewbox:** 0,0 → 80,48 (80×48 total area)
- **Aspect ratio:** 1.67:1
- **Maps 1:1** to 40×24pt @ 2× (80×48px)
- **Simpler** than current (no offset origin)

**Advantages:**
- Clean origin at (0, 0)
- Direct pixel mapping
- Easier to edit and position elements

---

## Provider Icon Sizing

### In Infinity Design

**Available Space:** 10-12pt wide × 12-14pt tall (center gap)

**Recommended Icon Size:** 8×8pt (16×16px @2x)

**Padding:** 1-2pt around icon for breathing room

### Existing Provider Icons (from IconRenderer.swift)

| Provider | Sigil Type | Dimensions | Fits in 8×8pt? |
|----------|-----------|------------|----------------|
| **Claude** | Vertical slits | 2×6pt each | ✓ Yes |
| **Codex** | Square eyes | 3×3pt each | ✓ Yes |
| **Gemini** | Diamond | 8pt diagonal | ✓ Yes (exactly) |
| **Cursor** | Arrow | 6pt tall | ✓ Yes |
| **Copilot** | Circular eyes | 6pt diameter | ✓ Yes |
| **Minimax** | Triangles | 6×5pt | ✓ Yes |
| **OpenRouter** | Ring | 8pt diameter | ✓ Yes (exactly) |
| **Groq** | Slash | 2×8pt | ⚠ Tight (8pt tall) |
| **Zai** | Double slash | 7pt tall | ✓ Yes |

**Conclusion:** All existing provider sigils fit comfortably in 8×8pt space.

### In Hybrid Design (Badge)

**Badge Size:** 6×6pt (12×12px @2x)

**Icon Size:** 4×4pt (8×8px @2x) inside badge

**Challenge:** Icons need to scale down 50% from main design.

**Solution:**
- Simplify icons for badge (minimal detail)
- Use single dots or letters as fallback
- Example: Claude = "C", Codex = "<>"

---

## Display Testing Matrix

### Test on Real Devices

| Display | Resolution | Scale | Test Size | Expected Result |
|---------|-----------|-------|-----------|-----------------|
| **MacBook Air M1** | 2560×1600 | 2× | 40×24pt | Sharp, clear |
| **MacBook Pro 16"** | 3456×2234 | 2× | 40×24pt | Sharp, clear |
| **iMac 27" 5K** | 5120×2880 | 2× | 40×24pt | Sharp, clear |
| **Mac mini + 1080p** | 1920×1080 | 1× | 40×24pt | Clear, slight blur |
| **Mac Studio + 4K** | 3840×2160 | 2× | 40×24pt | Sharp, clear |

### Size Comparison at Different DPI

| Size | @1× (72 DPI) | @2× (144 DPI) | Visual Result |
|------|-------------|---------------|---------------|
| **18pt** | 18×18px | 36×36px | Minimum legible |
| **22pt** | 22×22px | 44×44px | Standard menubar |
| **24pt** | 24×24px | 48×48px | Recommended (clear) |
| **28pt** | 28×28px | 56×56px | Large (accessibility) |

**Runic Recommended:** 24pt height (Option A & C) or 26pt (Option B refined)

---

## Color & Opacity Specifications

### Template Mode (Default)

**Colors:**
- **Light Mode:** NSColor.labelColor (black ~85% opacity)
- **Dark Mode:** NSColor.labelColor (white ~85% opacity)
- **System Managed:** No manual color specification

**Opacity Modifiers:**
- **Normal State:** 100% (uses labelColor directly)
- **Stale Data:** 55% opacity
- **Disabled:** 30% opacity

### Vibrant Mode (Optional)

**Pressure Color Palette:**

| State | Usage Range | Hex Color | RGB | Opacity |
|-------|------------|-----------|-----|---------|
| **Safe** | 0-50% | #14B8A6 | (20, 184, 166) | 100% |
| **Warning** | 50-80% | #FFB84D | (255, 184, 77) | 100% |
| **Critical** | 80-100% | #FF4F70 | (255, 79, 112) | 100% |
| **Stale** | Any | (inherit) | — | 55% |

**Secondary Colors (from current design):**

| Element | Color | Hex | RGB |
|---------|-------|-----|-----|
| **Primary Stroke** | Teal 500 | #14B8A6 | (20, 184, 166) |
| **Accent Fill** | Teal 400 | #2DD4BF | (45, 212, 191) |
| **Dark Fill** | Teal 700 | #0F766E | (15, 118, 110) |

---

## Animation Specifications

### Morph Animations (Launch/Close)

**Current Implementation (Lines 668-755):**
- Duration: 0.5s (morphBucketCount = 200 frames)
- Frame rate: 60 FPS
- Easing: Linear (custom easing possible)

**Infinity Morph:**
- Start: Three separate ribbons
- End: Infinity symbol
- Method: Bezier curve interpolation

**Cache:**
- 200 morph frames × 3 designs = 600 cached images
- Limited by PerformanceConstants.morphCacheSize (512)

### Pulse Animations (Syncing)

**Parameters:**
```swift
// Subtle pulse during sync
let pulse = sin(CACurrentMediaTime() * 2) * 0.15 + 0.85
iconColor = baseColor.withAlphaComponent(pulse)
```

**Specs:**
- Frequency: 0.5 Hz (2-second period)
- Amplitude: ±15% opacity
- Baseline: 85% opacity

### Blink Animations (Errors)

**Current Implementation (Lines 204-205):**
```swift
// Disabled to prevent flicker
let opacityMultiplier = 1.0
```

**If Re-enabled:**
- Duration: 0.2s per blink
- Repetitions: 3× for critical errors
- Opacity: 100% ↔ 30%

---

## Accessibility Specifications

### High Contrast Mode

**macOS System Setting:** Increase Contrast

**Icon Adjustments:**
- **Stroke Width:** +1pt (thicker)
- **Opacity:** Boost to 100% (remove transparency)
- **Colors:** Use maximum saturation

**Example:**
```swift
if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
    strokeWidth = 5.0 // instead of 4.0
    opacity = 1.0 // instead of 0.85
}
```

### Reduced Motion

**macOS System Setting:** Reduce Motion

**Icon Adjustments:**
- Disable all animations (blink, pulse, morph)
- Use static icons only
- Instant state changes (no transitions)

**Example:**
```swift
if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
    // Skip morph animation, show final state immediately
    return IconRenderer.makeIcon(..., blink: 0, wiggle: 0, tilt: 0)
}
```

### VoiceOver

**Icon Description Template:**

**Option A:**
```
"Runic monitoring icon. Infinity symbol with [Provider Name] in center. Usage level: [Color] ([Percentage]%). [Status]."
```

**Example:**
```
"Runic monitoring icon. Infinity symbol with Claude in center. Usage level: Orange (65%). Data is current."
```

**Option B:**
```
"Runic monitoring icon. Session usage: [X]%, Weekly usage: [Y]%, Credits remaining: [Z]%. [Status]."
```

**Implementation:**
```swift
statusItem.button?.accessibilityLabel = """
    Runic monitoring icon. Infinity symbol with \(providerName) in center. \
    Usage level: \(pressureColorName) (\(percentage)%). \(staleness).
    """
```

---

## File Format Specifications

### SVG Export Settings

**For Infinity Icon:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     viewBox="0 0 80 48"
     fill="none"
     width="80"
     height="48">
  <!-- Icon content -->
</svg>
```

**Requirements:**
- **Encoding:** UTF-8
- **Namespace:** xmlns="http://www.w3.org/2000/svg"
- **ViewBox:** Match output pixels (80×48)
- **Precision:** 2 decimal places max
- **Optimization:** Remove metadata, comments in production

**Export Tools:**
- **Illustrator:** Export As → SVG → "Responsive" viewBox
- **Figma:** Export SVG → Outline stroke
- **Sketch:** Export SVG → "Use relative dimensions"

### NSImage Import

**IconRenderer.swift Pattern:**

```swift
private static let infinityLogoTemplate: NSImage? = {
    guard let url = Bundle.main.url(
        forResource: "RunicMenubarIconInfinity",
        withExtension: "svg"),
          let image = NSImage(contentsOf: url) else {
        return nil
    }
    return image
}()
```

**Rendering:**

```swift
infinityLogo.draw(
    in: rect,
    from: .zero,
    operation: .sourceOver,
    fraction: 1.0
)
```

---

## Testing Checklist

### Visual Testing

- [ ] Renders sharply on Retina display (@2x)
- [ ] Renders acceptably on non-Retina display (@1x)
- [ ] Template mode adapts to light menubar theme
- [ ] Template mode adapts to dark menubar theme
- [ ] Vibrant mode displays correct colors
- [ ] All provider icons visible and recognizable
- [ ] Stale state reduces opacity to 55%
- [ ] Status indicators (minor, major, critical) render correctly
- [ ] No blurry edges (pixel-aligned)
- [ ] Smooth anti-aliasing on curves

### Size Testing

- [ ] Legible at 18pt (minimum)
- [ ] Clear at 22pt (standard)
- [ ] Excellent at 24pt (recommended)
- [ ] Excellent at 28pt (large)
- [ ] Scales proportionally at all sizes
- [ ] No cropping at edges
- [ ] Maintains aspect ratio

### Accessibility Testing

- [ ] High contrast mode increases visibility
- [ ] Reduced motion disables animations
- [ ] VoiceOver announces icon state correctly
- [ ] Tooltip shows detailed information on hover
- [ ] Keyboard shortcut opens menu

### Performance Testing

- [ ] First render <10ms
- [ ] Cached render <0.5ms
- [ ] Cache hit rate >80%
- [ ] Memory footprint <5MB (cache + templates)
- [ ] No memory leaks (verify with Instruments)
- [ ] Animation maintains 60 FPS

---

## Summary

### Recommended Specifications

**Size:** 40×24pt (80×48px @2x)
- Optimal balance of clarity and menubar fit
- +2pt from current for improved legibility
- Works well for all three design options

**Rendering:**
- Template mode by default (system theme adaptation)
- Vibrant mode as user preference option
- 2× scale for Retina displays
- Pixel-perfect alignment

**Provider Icons:**
- 8×8pt in infinity center gap
- All existing sigils fit comfortably
- Clear visibility and recognition

**Colors:**
- Pressure mapping: Teal (safe) → Orange (warning) → Red (critical)
- Stale state: 55% opacity
- Template: NSColor.labelColor (automatic)

**Performance:**
- Cache 50-100 icon variations
- Render in <10ms (first) or <0.5ms (cached)
- 60 FPS animations

**Accessibility:**
- High contrast support
- Reduced motion compliance
- VoiceOver descriptions
- Keyboard shortcut access

---

## Reference Implementation

```swift
// Complete size configuration for Option A
private static let baseSize = NSSize(width: 40, height: 24)
private static let outputSize = NSSize(width: 40, height: 24)
private static let outputScale: CGFloat = 2

// Infinity path specifications
private static let infinityStrokeWidth: CGFloat = 4
private static let infinityLoopRadius: CGFloat = 7
private static let infinityCenterGapWidth: CGFloat = 12
private static let infinityCenterGapHeight: CGFloat = 14

// Provider icon specifications
private static let providerIconSize: CGFloat = 8
private static let providerIconPadding: CGFloat = 2

// Color specifications
private static let safeColor = NSColor(calibratedRed: 0.08, green: 0.72, blue: 0.65, alpha: 1.0) // #14B8A6
private static let warningColor = NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.30, alpha: 1.0) // #FFB84D
private static let criticalColor = NSColor(calibratedRed: 1.00, green: 0.31, blue: 0.44, alpha: 1.0) // #FF4F70
private static let staleOpacity: CGFloat = 0.55
```

This completes the comprehensive size specification document for Runic's menubar icon designs.
