# Runic Menubar Icon Design Concepts

**Date:** February 1, 2026
**Status:** Design Proposal
**Author:** Design Review

## Executive Summary

This document compares three design concepts for the Runic menubar icon:
- **Option A:** Infinity Symbol + Provider Icon (monitoring eyes concept)
- **Option B:** Wave Logo (current design)
- **Option C:** Hybrid - Infinity + Usage Indicators

Each concept is evaluated for symbolism, usability, technical feasibility, and visual clarity at macOS menubar scale.

---

## Current State Analysis

### Current Wave Logo (RunicMenubarIcon.svg)

**Specifications:**
- Viewport: 46×78 to 210×178 (164×100 effective)
- Current render size: 38×22pt (76×44px @2x)
- Elements:
  - Wave/knot path (stroke: #14B8A6, 18px thick)
  - Center circle accent (32×32px, fill: #2DD4BF)
  - Three usage bars (8px wide, varying heights, fill: #0F766E)

**Strengths:**
- Shows live usage data through bar heights
- Distinctive wave/infinity-like shape
- Good color gradation (teal palette)
- Already implemented and rendered efficiently

**Weaknesses:**
- Complex at small size (22pt height = 44px @2x)
- Wave pattern can blur on non-Retina displays
- Limited symbolic meaning (abstract wave shape)
- No clear provider identification
- Bars too small to read precise values

---

## Design Concepts

### Option A: Infinity Symbol + Provider Icon

**Core Concept:**
The infinity symbol (∞) represents "eyes watching" your AI usage. The space between the loops displays the active provider's icon, creating a visual metaphor of Runic monitoring your AI provider.

#### Visual Design

**Infinity Symbol Specifications:**
- **Overall size:** 38×22pt (width × height)
- **Infinity stroke:** 4pt thick line
- **Loop radius:** 7pt per loop
- **Center gap:** 10pt wide × 12pt tall (for provider icon)
- **Provider icon:** 8×8pt (16×16px @2x)

**Layout:**
```
┌────────────────────────────────────┐
│                                    │
│    ╭──╮         ╭──╮              │
│   │    │   👁   │    │             │
│    ╰──╯         ╰──╯              │
│                                    │
└────────────────────────────────────┘
```

#### States & Variations

1. **Default State:**
   - Monochrome template rendering (adapts to light/dark mode)
   - Provider icon in center (full opacity)
   - Infinity loops at 100% opacity

2. **Usage Pressure Coloring:**
   - Safe (0-50% used): Teal (#14B8A6)
   - Warning (50-80% used): Orange (#FFB84D)
   - Critical (80-100% used): Red (#FF4F70)
   - Apply color to infinity loops, keep provider icon white/black

3. **Stale Data:**
   - Reduce opacity to 55%
   - Slight desaturation

4. **Multiple Providers Active:**
   - Show "combined" icon (perhaps stacked dots or merged symbol)
   - Alternative: cycle between provider icons every 3 seconds

#### Pros

**Symbolic Strength:**
- Clear metaphor: "eyes watching" = monitoring
- Infinity = continuous tracking
- Immediately communicates app purpose

**Visual Clarity:**
- Simple, bold shape recognizable at 18-26pt
- Provider icon clearly visible in center
- Less visual noise than current wave design

**Scalability:**
- Works well from 18pt to 32pt
- Clean lines render sharply on all displays
- Template rendering ensures perfect dark/light mode adaptation

**Brand Identity:**
- Memorable, unique icon
- "Eyes on your AI" tagline potential
- Strong conceptual foundation

#### Cons

**Limited Data Visualization:**
- Doesn't show live usage bars
- No immediate visual feedback on quota consumption
- User must click to see detailed metrics

**Provider Icon Constraints:**
- Center area limited to 8-10pt icons
- Some provider logos may not scale well
- Requires maintaining clear provider icons

**Less Informative:**
- Loses at-a-glance usage information
- More symbolic, less functional
- User must memorize color meaning

#### Implementation Complexity

**Medium Complexity:**

1. **SVG Creation:**
   - Simple infinity curve path (Bézier curves)
   - Template rendering for color adaptation
   - Provider icon overlay (multiply blend mode)

2. **Dynamic Rendering:**
   ```swift
   static func drawInfinityWithProvider(
       providerIcon: NSImage,
       pressure: Double,
       appearance: IconAppearance
   ) -> NSImage {
       // Draw infinity path
       // Apply pressure coloring
       // Composite provider icon in center
       // Return template or vibrant image
   }
   ```

3. **Performance:**
   - Cache infinity base shapes
   - Cache per-provider compositions
   - ~50-100 cached variations (providers × pressure levels)

---

### Option B: Wave Logo (Current Design)

**Keep the current design with potential refinements.**

#### Proposed Refinements

1. **Size Optimization:**
   - Increase to 40×24pt (from 38×22pt) for better bar visibility
   - Maintain 2× scale for Retina clarity

2. **Simplified Color Palette:**
   - Reduce to 2-color scheme for template mode
   - Make bars more prominent (wider: 10px instead of 8px)

3. **Usage Bar Enhancements:**
   - Animate bars on hover (subtle pulse)
   - Add tooltips showing exact percentages
   - Color-code bars by pressure level

#### Pros

**Data-Rich:**
- Shows live usage at a glance
- Three bars = session/weekly/credits data
- Instant visual feedback

**Already Implemented:**
- No redesign required
- Proven performance
- Existing cache system optimized

**Informative:**
- Power users can monitor usage without clicking
- Visual trends over time
- Multiple data dimensions

#### Cons

**Visual Complexity:**
- Bars hard to read at 22pt height
- Wave pattern adds visual noise
- Not immediately recognizable

**Weak Symbolism:**
- Abstract wave shape
- No clear connection to "monitoring" or "AI"
- Generic technology aesthetic

**Scaling Issues:**
- Bars become illegible below 20pt
- Wave detail lost on low-DPI displays
- Template rendering flattens detail

---

### Option C: Hybrid - Infinity + Usage Indicators

**Best of both worlds: symbolic infinity with functional usage display.**

#### Visual Design

**Concept:**
- Infinity symbol outline (3pt stroke)
- Single consolidated usage bar overlaid in the center gap
- Provider badge in corner (6×6pt)

**Layout:**
```
┌────────────────────────────────────┐
│                                    │
│    ╭──╮   ███   ╭──╮   [C]        │
│   │    │  ███  │    │              │
│    ╰──╯   ███   ╰──╯              │
│                                    │
└────────────────────────────────────┘
```

**Specifications:**
- Infinity loops: 3pt stroke, 6pt radius each
- Center bar: 10pt wide × 12pt tall, fill indicates usage %
- Provider badge: 6×6pt circle in top-right corner

#### States & Variations

1. **Usage Bar Fill:**
   - Empty state: 10% fill (show container outline)
   - Progressive fill from bottom to top
   - Color transitions: teal → orange → red

2. **Provider Badge:**
   - Small provider icon or colored dot
   - Indicates active provider
   - Subtle glow when actively syncing

3. **Infinity Outline:**
   - Always visible (base color)
   - Optional: pulse animation during sync

#### Pros

**Balanced Design:**
- Maintains symbolic "eyes watching" concept
- Shows usage data in center bar
- Provider identification via badge

**Functional:**
- At-a-glance usage percentage
- Simpler than three bars (one consolidated metric)
- Clear visual hierarchy

**Scalable:**
- Works from 20-28pt
- Both elements remain visible at small sizes
- Better than current wave complexity

#### Cons

**Compromised Simplicity:**
- More complex than pure infinity symbol
- Bar may compete with infinity shape
- Provider badge might be too small

**Reduced Data:**
- Only one bar (vs. three in current design)
- Loses session/weekly/credits breakdown
- Must consolidate metrics (show most critical)

**Implementation Effort:**
- New design and testing required
- Hybrid rendering logic
- More cache permutations

---

## Size Recommendations & Technical Specifications

### macOS Menubar Icon Guidelines

**Standard Sizes:**
- **Recommended:** 22pt square (44×44px @2x)
- **Apple HIG:** 18-22pt for simple icons, up to 28pt for detailed
- **Runic current:** 38×22pt (rectangular, not square)

**Rendering Requirements:**
- Must provide @2x (Retina) and @1x (legacy) bitmaps
- Template rendering: use alpha channel, system colors
- Safe area: 2pt padding from edges
- Pixel grid alignment at @2x scale

### Recommended Sizes by Concept

#### Option A: Infinity Symbol
- **Optimal height:** 20-24pt
- **Width:** 36-42pt (to fit provider icon)
- **Rationale:** Simple geometric shape scales well, needs width for two loops

**Proposed:** 40×24pt
- Infinity loops: 8pt radius each, 4pt stroke
- Center gap: 12pt wide (fits 8pt provider icon comfortably)
- Provider icon: 8×8pt (16×16px @2x) with 2pt padding

#### Option B: Wave Logo (Current)
- **Current:** 38×22pt (adequate but cramped)
- **Recommended:** 40×24pt or 42×26pt
- **Rationale:** More vertical space for bars, clearer wave detail

**Proposed:** 42×26pt
- Wave path: 20pt stroke
- Center circle: 36×36pt
- Usage bars: 10pt wide × 20-28pt tall (varies)

#### Option C: Hybrid
- **Optimal:** 40×24pt
- **Rationale:** Balances infinity outline and center bar

**Proposed:** 40×24pt
- Infinity: 3pt stroke, 7pt radius loops
- Center bar: 10×14pt
- Provider badge: 6×6pt in corner

### Retina Display Considerations

**2× Scale (@2x):**
- All dimensions double in pixels
- 24pt height = 48px bitmap height
- Ensures sharp rendering on MacBook Pro/Air displays

**Anti-aliasing:**
- Use sub-pixel rendering for smooth curves
- Align vertical/horizontal edges to pixel grid
- Avoid fractional pixel positions at @2x scale

**Color Depth:**
- 32-bit RGBA (8 bits per channel)
- Alpha channel for template rendering
- sRGB color space

---

## Color Schemes & Template Rendering

### Template Mode (Recommended)

**What is Template Rendering?**
- macOS automatically adapts icon to menubar theme
- Light mode: dark icon on light background
- Dark mode: light icon on dark background
- System handles all color adaptation

**Implementation:**
```swift
image.isTemplate = true
```

**Benefits:**
- Perfect theme integration
- No manual light/dark variants
- System-level accessibility support
- Consistent with other menubar apps

**Limitations:**
- Single color (no multi-color icons)
- Alpha channel defines shape only
- Cannot show colored provider icons in template mode

### Vibrant Mode (Optional)

**Full Color Rendering:**
- Custom color palette preserved
- Pressure coloring (teal → orange → red)
- Colored provider icons

**Use Cases:**
- User preference toggle in settings
- High-priority alerts (critical usage)
- Branding emphasis over integration

**Implementation:**
```swift
image.isTemplate = false
// Apply custom colors during rendering
```

### Recommended Approach

**Default: Template Mode**
- Clean, professional appearance
- Perfect system integration
- Accessibility compliant

**Optional: Vibrant Mode**
- User-configurable in preferences
- Fallback for alerts (flash red when critical)
- Provider-specific colors if desired

---

## Usage Indicator Integration

### Option A: Infinity Symbol - How to Show Usage?

Since the infinity symbol doesn't inherently display data, here are options:

#### 1. **Color Pressure Mapping**
- **0-50% used:** Teal infinity loops (#14B8A6)
- **50-80% used:** Orange loops (#FFB84D)
- **80-100% used:** Red loops (#FF4F70)
- **Pros:** Subtle, doesn't clutter icon
- **Cons:** Requires user to learn color meaning

#### 2. **Accent Dot**
- Small dot (4×4pt) on infinity curve
- Position along curve indicates usage percentage
- Color indicates pressure level
- **Pros:** Visual metaphor (progress indicator)
- **Cons:** Tiny, may be hard to notice

#### 3. **No Direct Indicator**
- Icon remains symbolic only
- User clicks to see detailed usage
- Menubar tooltip shows percentage on hover
- **Pros:** Cleanest design
- **Cons:** Less functional than current wave

**Recommendation:** Use **Color Pressure Mapping** for Option A. It's subtle, doesn't add visual complexity, and provides at-a-glance status.

### Option B: Wave Logo - Current Approach

- Three vertical bars show session/weekly/credits usage
- Bar height = percentage used or remaining
- Bars are color-coded or use same teal palette

**Keep as-is or enhance:**
- Make bars 2pt wider (10pt instead of 8pt)
- Add subtle glow when nearing limits
- Animate on hover (optional)

### Option C: Hybrid - Center Bar

- Single bar in infinity center gap
- Shows most critical metric (lowest remaining percentage)
- Fill level = usage percentage
- Color = pressure level

**Advantages:**
- Simpler than three bars
- Consolidated "worst-case" metric
- More visible than Option A color coding

---

## Provider Icon Considerations

### Option A: Center Icon (8-10pt)

**Requirements:**
- **Size:** 8×8pt minimum (16×16px @2x)
- **Clarity:** Must be recognizable at small scale
- **Contrast:** Must work on both light and dark backgrounds

**Design Guidelines for Provider Icons:**

1. **Simple Geometry:**
   - Avoid fine details
   - Use bold shapes
   - Prefer geometric symbols over text

2. **High Contrast:**
   - Solid fills or thick strokes (2pt+)
   - Avoid gradients or textures
   - White outline for dark backgrounds (optional)

3. **Example Provider Icons:**
   - **Claude:** Two vertical slits (current design: 2×6pt)
   - **Codex:** Two square eyes (3×3pt)
   - **Gemini:** Diamond shape (8pt diagonal)
   - **Cursor:** Arrow/pointer (6pt)
   - **Copilot:** Circular eyes with bridge

**Existing Icons:** Already well-designed at small scale (see IconRenderer.swift, lines 300-473)

### Option C: Corner Badge (6×6pt)

**Smaller but less critical:**
- Simple colored dot or 1-letter abbreviation
- Background circle with contrasting icon
- Examples:
  - **Claude:** Orange dot with "C"
  - **Codex:** Purple dot with "<>"
  - **Gemini:** Blue dot with star

**Trade-off:** Less recognizable but saves center space for usage bar

---

## Implementation Recommendations

### Option A: Infinity Symbol + Provider Icon

#### SVG Structure
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 48">
  <!-- Infinity loops -->
  <path d="M20,24 C20,15 30,15 35,24 C40,33 50,33 50,24
           C50,15 40,15 35,24 C30,33 20,33 20,24"
        stroke="#14B8A6" stroke-width="8"
        fill="none" stroke-linecap="round"/>

  <!-- Provider icon placeholder (replace with actual icon) -->
  <circle cx="40" cy="24" r="4" fill="#FFFFFF"/>
</svg>
```

#### Swift Rendering Code
```swift
static func drawInfinityIcon(
    provider: UsageProvider,
    pressure: Double,
    appearance: IconAppearance
) -> NSImage {
    let color = vibrantAccentColor(pressure: pressure, stale: false)
    let baseColor = appearance == .template ? NSColor.labelColor : color

    return renderImage(isTemplate: appearance == .template) {
        // Draw infinity path
        drawInfinityPath(color: baseColor)

        // Composite provider icon in center
        if let providerIcon = loadProviderIcon(provider) {
            drawProviderIcon(providerIcon, center: centerPoint)
        }
    }
}

private static func drawInfinityPath(color: NSColor) {
    let path = NSBezierPath()
    // Left loop
    path.appendArc(
        withCenter: NSPoint(x: 15, y: 12),
        radius: 7,
        startAngle: 0,
        endAngle: 360
    )
    // Right loop
    path.appendArc(
        withCenter: NSPoint(x: 25, y: 12),
        radius: 7,
        startAngle: 0,
        endAngle: 360
    )
    // Connect loops to form infinity
    // (simplified - actual Bézier curves needed for smooth infinity shape)

    path.lineWidth = 4
    color.setStroke()
    path.stroke()
}
```

#### Caching Strategy
- Cache base infinity shapes (one per pressure color)
- Cache provider icon compositions
- Key: `InfinityCacheKey(provider, pressure, appearance)`
- Estimated cache size: ~50 variations (10 providers × 5 pressure levels)

### Option B: Wave Logo Enhancements

#### Minimal Changes
```swift
// Increase bar width from 8 to 10
static let barWidth = 10.0

// Increase overall height from 22 to 24
static let outputSize = NSSize(width: 40, height: 24)
```

#### Optional Animations
```swift
// Add subtle pulse to bars when nearing limit
if pressure > 0.8 {
    let pulse = sin(CACurrentMediaTime() * 2) * 0.15 + 0.85
    barColor = barColor.withAlphaComponent(pulse)
}
```

### Option C: Hybrid Implementation

#### Combined Rendering
```swift
static func drawHybridIcon(
    provider: UsageProvider,
    primaryUsage: Double,
    appearance: IconAppearance
) -> NSImage {
    return renderImage(isTemplate: appearance == .template) {
        // 1. Draw infinity outline
        drawInfinityOutline(color: baseColor.withAlphaComponent(0.3))

        // 2. Draw center usage bar
        drawCenterBar(fillPercent: primaryUsage / 100, color: pressureColor)

        // 3. Draw provider badge
        drawProviderBadge(provider: provider, position: .topRight)
    }
}
```

---

## Comparison Matrix

| Criterion | Option A: Infinity | Option B: Wave | Option C: Hybrid |
|-----------|-------------------|----------------|------------------|
| **Symbolism** | ★★★★★ Eyes watching | ★★☆☆☆ Abstract | ★★★★☆ Balanced |
| **Data Visibility** | ★★☆☆☆ Color only | ★★★★★ 3 bars | ★★★☆☆ 1 bar |
| **Clarity (18-22pt)** | ★★★★★ Simple shape | ★★★☆☆ Complex | ★★★★☆ Moderate |
| **Provider ID** | ★★★★★ Center icon | ★☆☆☆☆ None | ★★★☆☆ Badge |
| **Implementation** | ★★★☆☆ Medium | ★★★★★ Done | ★★☆☆☆ Complex |
| **Brand Identity** | ★★★★★ Memorable | ★★★☆☆ Generic | ★★★★☆ Good |
| **User Learning** | ★★★☆☆ Color meaning | ★★★★☆ Intuitive | ★★★★☆ Balanced |
| **Scalability** | ★★★★★ 18-32pt | ★★★☆☆ 22-28pt | ★★★★☆ 20-26pt |

**Rating Scale:** ★★★★★ Excellent | ★★★★☆ Good | ★★★☆☆ Acceptable | ★★☆☆☆ Poor | ★☆☆☆☆ Inadequate

---

## Recommendations

### Primary Recommendation: **Option A - Infinity Symbol + Provider Icon**

**Rationale:**
1. **Strong Conceptual Foundation:** The "eyes watching" metaphor immediately communicates Runic's purpose
2. **Memorable Brand Identity:** Unique, recognizable icon that stands out in the menubar
3. **Scalable Design:** Works well from 18pt to 32pt, crucial for different Mac displays
4. **Provider Clarity:** Center icon clearly shows which provider is active
5. **Modern Aesthetics:** Clean, minimalist design aligns with macOS Big Sur+ design language

**Trade-off Acknowledgment:**
- Loses immediate usage data visibility
- Users must click to see detailed metrics
- **Mitigation:** Use color pressure mapping (teal → orange → red) and rich tooltip on hover

**Recommended Specifications:**
- Size: 40×24pt (80×48px @2x)
- Infinity stroke: 4pt
- Loop radius: 7pt each
- Provider icon: 8×8pt in center
- Color mapping: pressure-based for at-a-glance status

### Secondary Recommendation: **Option C - Hybrid** (if data visibility is critical)

**When to Choose:**
- User feedback demands at-a-glance usage data
- Power users prioritize metrics over symbolism
- A/B testing shows higher engagement with visible bars

**Recommended Specifications:**
- Size: 40×24pt
- Infinity outline: 3pt stroke
- Center bar: 10×14pt
- Provider badge: 6×6pt in corner

### Not Recommended: **Option B - Current Wave Logo**

**Reasoning:**
- Weak symbolic connection to monitoring/AI
- Visual complexity reduces clarity at small sizes
- Generic technology aesthetic
- Already implemented, so no forward progress

**Exception:** If development timeline is critical and redesign is not feasible, enhance current design with:
- Increased size to 42×26pt
- Wider bars (10pt instead of 8pt)
- Simplified color scheme

---

## Implementation Plan

### Phase 1: Prototyping (Week 1)
1. Create SVG mockups for all three options
2. Implement basic rendering in IconRenderer
3. Test at 18pt, 22pt, 26pt sizes
4. Gather internal feedback

### Phase 2: Refinement (Week 2)
5. Refine chosen design based on feedback
6. Implement caching system
7. Add animation states (sync pulse, error flash)
8. Test on multiple Mac displays (Retina, non-Retina)

### Phase 3: Integration (Week 3)
9. Replace current wave logo in Resources/
10. Update IconRenderer.swift rendering logic
11. Add user preference toggle (template vs. vibrant mode)
12. Update documentation and changelog

### Phase 4: User Testing (Week 4)
13. Beta release with new icon
14. Collect user feedback
15. A/B testing if possible (show different icons to user segments)
16. Iterate based on data

---

## Future Enhancements

### Dynamic Animations
- **Sync Pulse:** Subtle pulse during active data fetch
- **Alert Flash:** Red flash when usage exceeds threshold
- **Provider Switch:** Smooth morph animation when switching providers

### Accessibility
- **VoiceOver Support:** Descriptive labels for icon states
- **High Contrast Mode:** Thicker strokes, higher contrast colors
- **Reduced Motion:** Disable animations if system preference set

### Customization
- **User-Selectable Icons:** Option A, B, or C in preferences
- **Color Themes:** Custom color schemes beyond default teal
- **Size Options:** Small (20pt), Medium (24pt), Large (28pt)

---

## Appendices

### Appendix A: SVG Mockup Files
- `InfinityIconConcept.svg` - Option A full design
- `InfinityIconStates.svg` - Option A with all states
- `WaveLogoRefined.svg` - Option B with enhancements
- `HybridIconConcept.svg` - Option C design

### Appendix B: Technical References
- Apple Human Interface Guidelines - Menubar Extras
- macOS Template Image Best Practices
- IconRenderer.swift (current implementation)
- NSImage Template Rendering Documentation

### Appendix C: Color Specifications

**Teal Palette (Current):**
- Primary: #14B8A6 (teal-500)
- Light: #2DD4BF (teal-400)
- Dark: #0F766E (teal-700)

**Pressure Palette (Recommended):**
- Safe: #14B8A6 (teal-500) - 0-50% usage
- Warning: #FFB84D (orange-400) - 50-80% usage
- Critical: #FF4F70 (red-500) - 80-100% usage
- Stale: 55% opacity on any color

**Template Colors:**
- Light mode: NSColor.labelColor (black ~85% opacity)
- Dark mode: NSColor.labelColor (white ~85% opacity)
- System-managed, no manual specification needed

---

## Conclusion

The **Infinity Symbol + Provider Icon** design offers the strongest conceptual foundation, best scalability, and most memorable brand identity for Runic. While it sacrifices immediate data visibility compared to the current wave logo, this trade-off is acceptable given:

1. Users can hover for tooltip or click for full details
2. Color pressure mapping provides at-a-glance status
3. Provider icon adds valuable context missing in current design
4. Simpler shape ensures clarity across all display sizes

**Next Steps:**
1. Create SVG mockups (see attached files)
2. Stakeholder review and decision
3. Implement chosen design in IconRenderer.swift
4. Beta test with users
5. Iterate based on feedback

**Timeline:** 3-4 weeks from concept approval to production deployment.
