# Runic Menubar Icon Design Documentation

**Complete design review and implementation guide for Runic's menubar icon redesign.**

---

## Overview

This directory contains comprehensive design concepts, technical specifications, and implementation guidance for Runic's menubar icon. The documentation evaluates three design options and provides detailed recommendations for the "infinity symbol + provider icon" concept.

**Vision:** An infinity symbol (∞) representing "eyes watching" your AI usage, with the active provider icon displayed in the center gap.

---

## Documents

### 1. MenubarIconDesignConcepts.md
**Primary design document** with detailed analysis of all three options.

**Contents:**
- Current state analysis (wave logo)
- Option A: Infinity Symbol + Provider Icon (recommended)
- Option B: Wave Logo refinements (current design)
- Option C: Hybrid - Infinity + Usage Indicators
- Comparison matrix (symbolism, usability, technical feasibility)
- Size recommendations (18-28pt range)
- Color schemes and template rendering
- Usage indicator integration strategies
- Implementation recommendations
- Future enhancements

**Read this first** for the full design rationale.

### 2. DesignComparisonChart.md
**Quick reference guide** for decision-making.

**Contents:**
- At-a-glance comparison table (10 criteria)
- Weighted scoring matrix (quantitative analysis)
- Use case scenarios (power user, casual user, multi-provider, etc.)
- Final recommendation with justification
- User feedback survey template
- Decision-making framework

**Read this** for a fast summary and data-driven comparison.

### 3. ImplementationGuide.md
**Step-by-step technical implementation** for developers.

**Contents:**
- Current architecture analysis (IconRenderer.swift)
- Phase-by-phase implementation plan
- Code snippets for all new functions
- Cache key updates
- Settings integration
- Testing plan (visual, performance, accessibility)
- Troubleshooting guide
- Migration strategy (rollout options)

**Use this** to implement the chosen design in the codebase.

### 4. SizeSpecifications.md
**Technical reference** for all sizing and rendering details.

**Contents:**
- macOS menubar guidelines (Apple HIG)
- Recommended sizes by design option
- Pixel-perfect rendering rules (@2x scale)
- SVG viewbox specifications
- Provider icon sizing constraints
- Display testing matrix (Retina, non-Retina, etc.)
- Color and opacity specifications
- Animation specifications
- Accessibility specifications (high contrast, reduced motion, VoiceOver)
- Testing checklist

**Use this** for precise technical specifications during implementation.

---

## SVG Mockups

Located in `docs/design/mockups/`:

### InfinityIconConcept.svg
Single infinity symbol icon with provider icon placeholder.

**Specifications:**
- Size: 40×24pt (80×48px @2x)
- Infinity stroke: 8px (@2x)
- Center gap: 20×16px for provider icon
- Template rendering ready

### InfinityIconStates.svg
Complete state demonstration grid (12 variations).

**Shows:**
- Pressure states: Safe, Warning, Critical, Stale
- Provider variations: Claude, Codex, Gemini, Cursor
- Template modes: Light background, Dark background
- Special states: Multiple providers, Syncing animation

**Use this** to visualize all possible icon states.

### WaveLogoRefined.svg
Enhanced version of current wave logo.

**Improvements:**
- Increased size: 42×26pt (84×52px @2x)
- Thicker bars: 10px wide (up from 8px)
- Larger center circle: 36px (up from 32px)
- Better clarity at small sizes

### HybridIconConcept.svg
Combination design: infinity outline + usage bar + provider badge.

**Features:**
- Infinity outline: 6px stroke (@2x)
- Center bar: 16×24px (shows usage percentage)
- Provider badge: 12×12px circle in corner
- Balanced information density

---

## Design Options Summary

### Option A: Infinity Symbol + Provider Icon (Recommended)

**Strengths:**
- Strong symbolic metaphor ("eyes watching")
- Clear provider identification (8×8pt center icon)
- Excellent scalability (18-32pt)
- Memorable brand identity
- Simple, clean design

**Trade-offs:**
- No direct usage data display (uses color pressure mapping instead)
- Requires brief user education (color meanings)

**Best for:**
- Brand differentiation
- Provider clarity
- Visual simplicity
- Long-term growth

**Implementation Time:** 8-12 hours

---

### Option B: Wave Logo (Current Design)

**Strengths:**
- Already implemented (no development cost)
- Shows live usage data (3 bars)
- Intuitive for existing users
- Proven performance

**Trade-offs:**
- Weak symbolism (abstract wave shape)
- No provider identification
- Complex at small sizes
- Generic appearance

**Best for:**
- Zero implementation budget
- Existing user retention
- Data-first approach

**Implementation Time:** 0 hours (2-4 hours for refinements)

---

### Option C: Hybrid Design

**Strengths:**
- Balances symbolism and data
- Shows usage percentage (center bar)
- Provider badge for identification
- Moderate complexity

**Trade-offs:**
- More complex implementation
- Smaller provider badge (6×6pt)
- Compromised simplicity

**Best for:**
- Users demanding both form and function
- Power user scenarios
- Maximum information density

**Implementation Time:** 12-16 hours

---

## Recommendation

### Primary: Option A - Infinity Symbol + Provider Icon

**Rationale:**
1. Strongest conceptual foundation ("eyes watching" metaphor)
2. Unique brand identity (stands out in menubar)
3. Excellent provider identification
4. Scales well across all display sizes
5. Simple, professional aesthetic

**Score:** 4.10/5.00 (weighted criteria)

**Mitigation for data visibility:**
- Color pressure mapping (teal → orange → red)
- Rich tooltip on hover (shows exact percentages)
- One-click menu access for full details

### Implementation Strategy

**Recommended Approach:**
1. Implement Option A as default design
2. Keep Option B (wave) as user preference option
3. Add preference toggle: "Menubar Icon Style"
4. Beta test with selected users
5. Iterate based on feedback

**Rollout Timeline:**
- Week 1: Prototyping and SVG finalization
- Week 2: Implementation and caching system
- Week 3: Integration and preferences UI
- Week 4: Beta testing and iteration

---

## Quick Start

### For Designers

1. **Review design concepts:** Read `MenubarIconDesignConcepts.md`
2. **View mockups:** Open SVG files in `mockups/` directory
3. **Check specifications:** Refer to `SizeSpecifications.md` for exact dimensions
4. **Iterate:** Create variations based on feedback

### For Developers

1. **Understand current system:** Review `ImplementationGuide.md` architecture section
2. **Plan implementation:** Follow phase-by-phase guide
3. **Check specifications:** Use `SizeSpecifications.md` for precise values
4. **Test thoroughly:** Follow testing checklist in both guides

### For Product Managers

1. **Compare options:** Read `DesignComparisonChart.md`
2. **Review scoring:** Check weighted matrix (section 10)
3. **Consider use cases:** Match to user personas (section 9)
4. **Make decision:** Use recommendation in final section
5. **Plan rollout:** Reference migration strategy in implementation guide

### For Stakeholders

1. **Executive summary:** Read "Overview" and "Recommendation" sections above
2. **Visual review:** Open `InfinityIconStates.svg` to see all variations
3. **Quick comparison:** Review comparison table in `DesignComparisonChart.md`
4. **Timeline:** Check implementation plan (Week 1-4 breakdown)

---

## Testing & Validation

### Before Implementation

- [ ] Review all design documents
- [ ] Stakeholder approval on chosen design
- [ ] User survey (optional - template in DesignComparisonChart.md)
- [ ] A/B testing plan (if desired)

### During Implementation

- [ ] Visual testing at 18pt, 22pt, 24pt, 28pt
- [ ] Retina display testing (@2x)
- [ ] Non-Retina display testing (@1x)
- [ ] Light mode / dark mode switching
- [ ] All provider icons rendering correctly
- [ ] Performance benchmarks (render time <10ms)
- [ ] Cache efficiency (hit rate >80%)

### After Implementation

- [ ] Beta user feedback collection
- [ ] Analytics tracking (engagement metrics)
- [ ] Performance monitoring (no regressions)
- [ ] Accessibility audit (VoiceOver, high contrast, reduced motion)
- [ ] A/B test results analysis (if applicable)

---

## File Organization

```
docs/design/
├── README.md                           # This file
├── MenubarIconDesignConcepts.md       # Complete design analysis
├── DesignComparisonChart.md           # Quick reference comparison
├── ImplementationGuide.md             # Developer instructions
├── SizeSpecifications.md              # Technical specifications
└── mockups/
    ├── InfinityIconConcept.svg        # Single infinity icon
    ├── InfinityIconStates.svg         # All state variations
    ├── WaveLogoRefined.svg            # Enhanced current design
    └── HybridIconConcept.svg          # Hybrid concept
```

---

## Key Specifications

### Recommended Size
- **Points:** 40×24pt (width × height)
- **Pixels (@2x):** 80×48px
- **Aspect Ratio:** 1.67:1

### Infinity Symbol
- **Stroke Width:** 4pt (8px @2x)
- **Loop Radius:** 7pt per loop
- **Center Gap:** 12×14pt (for provider icon)

### Provider Icon
- **Size:** 8×8pt (16×16px @2x)
- **Padding:** 2pt around icon
- **Position:** Centered in infinity gap

### Colors (Vibrant Mode)
- **Safe:** #14B8A6 (teal) - 0-50% usage
- **Warning:** #FFB84D (orange) - 50-80% usage
- **Critical:** #FF4F70 (red) - 80-100% usage
- **Stale:** 55% opacity on any color

### Template Mode
- **Light Mode:** Black ~85% opacity (NSColor.labelColor)
- **Dark Mode:** White ~85% opacity (NSColor.labelColor)
- **System Managed:** Automatic theme adaptation

---

## Resources

### Apple Documentation
- [Human Interface Guidelines - Menus](https://developer.apple.com/design/human-interface-guidelines/menus)
- [NSStatusItem Documentation](https://developer.apple.com/documentation/appkit/nsstatusitem)
- [Template Images](https://developer.apple.com/documentation/appkit/nsimage/1520024-istemplate)

### Internal References
- `IconRenderer.swift` - Current implementation
- `StatusItemController.swift` - Icon usage
- `SettingsStore.swift` - User preferences
- `UsageStore.swift` - Data source

### Design Tools
- **Figma:** Icon design and prototyping
- **Sketch:** Alternative design tool
- **Illustrator:** SVG editing and export
- **SF Symbols:** macOS icon reference

---

## FAQ

### Why infinity symbol?

The infinity symbol (∞) naturally resembles "eyes" when you look at the two loops. This creates a powerful metaphor: "Runic is watching your AI usage." It's memorable, meaningful, and immediately communicates the app's purpose.

### Why not keep the wave logo?

The wave logo is functional but lacks symbolic meaning. It doesn't communicate "monitoring" or "AI" at first glance. The infinity design provides stronger brand identity and better provider identification while maintaining professional aesthetics.

### What about users who prefer data-rich icons?

We'll keep the wave logo as a preference option. Users can switch in Preferences → General → Menubar Icon Style. This gives power users their detailed metrics while new users get the clearer, more symbolic design.

### How do I know usage levels without bars?

The infinity loops change color based on usage pressure:
- **Teal:** Safe (0-50% used)
- **Orange:** Warning (50-80% used)
- **Red:** Critical (80-100% used)

Plus, hovering shows a tooltip with exact percentages, and clicking opens the full menu with detailed charts.

### Will this work on older Macs?

Yes. The design supports both Retina (@2x) and non-Retina (@1x) displays. Template rendering ensures compatibility with all macOS versions and themes. Testing includes legacy display support.

### How long to implement?

**Option A (Infinity):** 8-12 hours for experienced Swift developer

**Breakdown:**
- SVG creation: 1-2 hours
- IconRenderer updates: 4-6 hours
- Cache integration: 1-2 hours
- Settings UI: 1 hour
- Testing: 2-3 hours

### Can we A/B test designs?

Yes. Implementation guide includes A/B testing strategy:
- Randomly assign 50% of users to new design
- Track engagement metrics (menu opens, preference changes)
- Collect feedback surveys
- Choose winner after 2 weeks
- Full rollout with preference option

---

## Version History

### v1.0 (February 1, 2026)
- Initial design review
- Three concept options analyzed
- Complete documentation set
- SVG mockups created
- Implementation guide provided
- Size specifications documented

---

## Contributors

**Design Concept:** User Vision (infinity = monitoring eyes)

**Documentation:** Design Review Team

**Current Implementation:** IconRenderer.swift (wave logo)

---

## Next Steps

1. **Review & Approval**
   - Stakeholder review of design concepts
   - Final decision on Option A, B, or C
   - Budget and timeline approval

2. **Implementation**
   - Create infinity SVG asset
   - Update IconRenderer.swift
   - Add user preferences
   - Implement caching system

3. **Testing**
   - Visual testing (all sizes, displays, modes)
   - Performance testing (render time, cache efficiency)
   - Accessibility testing (VoiceOver, high contrast, reduced motion)
   - User testing (beta group feedback)

4. **Rollout**
   - Beta release with new icon
   - Collect user feedback
   - A/B testing (if applicable)
   - Production release
   - Announcement in release notes

5. **Iteration**
   - Monitor engagement metrics
   - Address user feedback
   - Refine based on real-world usage
   - Plan future enhancements

---

## Contact

For questions about this design documentation:
- Review design files in this directory
- Check implementation guide for technical details
- Refer to size specifications for exact measurements
- Open discussions in team channels

---

**Last Updated:** February 1, 2026

**Status:** Design Review Complete - Awaiting Implementation Approval
