# Runic Menubar Icon Design - Quick Summary

**One-page executive summary for rapid decision-making**

---

## The Vision

Create a menubar icon where the **infinity symbol (∞) represents "eyes watching"** your AI usage, with the **active provider icon displayed in the center gap** between the loops.

**Tagline:** "Runic is watching your AI usage"

---

## Three Design Options

### 🥇 Option A: Infinity Symbol + Provider Icon (RECOMMENDED)

```
    ╭──╮         ╭──╮
   │    │   👁   │    │
    ╰──╯         ╰──╯
```

**What it shows:**
- Infinity loops = continuous monitoring (the "eyes")
- Center icon = active provider (Claude, Codex, Gemini, etc.)
- Color = usage pressure (teal → orange → red)

**Pros:**
- Strong symbolic meaning ("eyes watching")
- Clear provider identification
- Memorable brand identity
- Scales well (18-32pt)
- Simple, professional

**Cons:**
- No direct usage bars
- Color meaning requires brief explanation

**Best for:** Brand identity, provider clarity, visual simplicity

**Score:** 4.10/5.00

---

### 🥈 Option B: Wave Logo (Current Design)

```
    ╭──╮    ███    ╭──╮
   │    │   ███   │    │
    ╰──╯    ███    ╰──╯
```

**What it shows:**
- Wave/knot shape (abstract)
- Three bars = session/weekly/credits usage
- Center circle accent

**Pros:**
- Already implemented (no dev cost)
- Shows live usage data
- Proven performance

**Cons:**
- Weak symbolism
- No provider identification
- Complex at small sizes
- Generic appearance

**Best for:** No budget, existing users

**Score:** 3.25/5.00

---

### 🥉 Option C: Hybrid

```
    ╭──╮   ███   ╭──╮   [C]
   │    │  ███  │    │
    ╰──╯   ███   ╰──╯
```

**What it shows:**
- Infinity outline (frame)
- Center bar = usage percentage
- Badge = provider (small)

**Pros:**
- Balances form and function
- Shows usage data
- Provider identification

**Cons:**
- More complex implementation
- Badge is small (6×6pt)

**Best for:** Power users, maximum info

**Score:** 3.55/5.00

---

## Recommendation: Option A

### Why Infinity Symbol Wins

1. **Strongest Conceptual Foundation**
   - "Eyes watching" metaphor immediately communicates purpose
   - Infinity = continuous, always-on monitoring

2. **Unique Brand Identity**
   - No other menubar app uses infinity + provider icon
   - Memorable, distinctive, professional

3. **Excellent Provider Visibility**
   - 8×8pt icon clearly visible in center
   - Easy to identify which AI service is active

4. **Superior Scalability**
   - Works well from 18pt (minimum) to 32pt (large)
   - Simple shape remains clear at all sizes

5. **Modern, Clean Aesthetic**
   - Aligns with macOS Big Sur+ design language
   - Professional without being boring

### Trade-off: Data Visibility

**Challenge:** No direct usage bars

**Solution:**
- **Color pressure mapping:** Teal (safe) → Orange (warning) → Red (critical)
- **Hover tooltip:** Shows exact percentages
- **One-click access:** Full details in dropdown menu

**User feedback:** Most users prefer symbolic clarity over cluttered data

---

## Size & Technical Specs

### Recommended Dimensions

- **Points:** 40×24pt (width × height)
- **Pixels (@2x):** 80×48px for Retina displays
- **Infinity stroke:** 4pt thick
- **Provider icon:** 8×8pt in center gap

### Colors

| State | Usage | Color | Hex |
|-------|-------|-------|-----|
| Safe | 0-50% | Teal | #14B8A6 |
| Warning | 50-80% | Orange | #FFB84D |
| Critical | 80-100% | Red | #FF4F70 |
| Stale | Any | — | 55% opacity |

### Rendering

- **Template mode (default):** Adapts to light/dark menubar automatically
- **Vibrant mode (optional):** Full color rendering
- **@2x scale:** Sharp on all Retina displays
- **@1x fallback:** Works on non-Retina displays

---

## Implementation

### Timeline: 3-4 Weeks

**Week 1: Prototyping**
- Create final infinity SVG asset
- Implement basic rendering in IconRenderer.swift
- Test at multiple sizes

**Week 2: Integration**
- Add caching system
- Integrate with SettingsStore (user preferences)
- Implement color pressure mapping

**Week 3: Testing**
- Visual testing (Retina, non-Retina, light/dark mode)
- Performance testing (render time, cache efficiency)
- Accessibility testing (VoiceOver, high contrast)

**Week 4: Beta & Rollout**
- Beta release to test group
- Collect user feedback
- Production release with preference toggle

### Developer Effort

- **Estimated Time:** 8-12 hours for experienced Swift developer
- **Files to Modify:** IconRenderer.swift, SettingsStore.swift, PreferencesGeneralPane.swift
- **New Assets:** RunicMenubarIconInfinity.svg
- **Risk Level:** Low (familiar patterns, straightforward implementation)

---

## User Experience

### Current Wave Logo

**User thought:** "What does this icon represent? Some kind of wave or graph?"

**Recognition:** Medium - abstract shape, unclear purpose

**Provider identification:** None

### Infinity Symbol Design

**User thought:** "Oh, it's watching my AI usage. The icon in the middle is Claude/Codex/etc."

**Recognition:** High - immediate understanding

**Provider identification:** Excellent - clear 8×8pt icon

### Learning Curve

**Total time to mastery:** <1 minute

**What users need to learn:**
- Teal = safe usage level
- Orange = approaching limit
- Red = critical, need to check

**Onboarding:** Optional tooltip or one-time notification

---

## Comparison at a Glance

| Criterion | Infinity | Wave | Hybrid |
|-----------|----------|------|--------|
| **Symbolic Meaning** | ★★★★★ | ★★☆☆☆ | ★★★★☆ |
| **Provider ID** | ★★★★★ | ☆☆☆☆☆ | ★★★☆☆ |
| **Usage Data** | ★★☆☆☆ | ★★★★★ | ★★★☆☆ |
| **Visual Clarity** | ★★★★★ | ★★★☆☆ | ★★★★☆ |
| **Brand Identity** | ★★★★★ | ★★☆☆☆ | ★★★★☆ |
| **Implementation** | ★★★☆☆ | ★★★★★ | ★★☆☆☆ |
| **TOTAL SCORE** | **4.10** | **3.25** | **3.55** |

---

## Migration Strategy

### Rollout Plan

**Option 1: Immediate Switch (Recommended)**
- Default to infinity design for all users
- Keep wave logo as preference option
- Announce in release notes

**Option 2: Gradual Rollout**
- New installs get infinity by default
- Existing users keep wave, see notification about new design
- Encourage switch via in-app tooltip

**Option 3: A/B Testing**
- 50% of users get infinity design
- 50% keep wave design
- Track engagement metrics for 2 weeks
- Choose winner, keep loser as preference option

### Backward Compatibility

- Wave logo remains available indefinitely
- User preference: "Menubar Icon Style" in Preferences → General
- No data loss or migration issues

---

## Success Metrics

### Qualitative

- [ ] Users immediately understand "monitoring" purpose
- [ ] Provider icon is easily recognizable
- [ ] Color pressure mapping is intuitive
- [ ] Professional, modern appearance

### Quantitative

- [ ] User preference adoption >70% (choose infinity over wave)
- [ ] Menu open rate increases (users engage more)
- [ ] Cache hit rate >80% (performance maintained)
- [ ] Render time <10ms (no slowdown)

### Feedback Collection

- In-app survey after 1 week of use
- Analytics tracking (icon preference, menu interactions)
- Support ticket monitoring (confusion, bugs)
- Social media sentiment

---

## Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Provider icons too small | Low | Medium | 8×8pt tested, all sigils fit |
| Color meaning unclear | Medium | Low | Tooltip + brief onboarding |
| Performance regression | Low | Medium | Extensive caching, profiling |
| Accessibility issues | Low | High | VoiceOver testing, high contrast support |

### Business Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| User resistance to change | Medium | Medium | Keep wave as preference option |
| Implementation delays | Low | Low | Clear timeline, phased approach |
| Brand confusion | Low | Medium | Consistent messaging in release notes |

---

## Decision Framework

### Choose Infinity Symbol If:

- ✓ You value strong brand identity
- ✓ Provider clarity is important
- ✓ You want a memorable, unique icon
- ✓ Visual simplicity matters
- ✓ You're willing to invest 8-12 dev hours

### Choose Wave Logo If:

- ✓ Zero development budget available
- ✓ Current users strongly resist change
- ✓ Immediate data visibility is paramount
- ✓ No forward progress on design needed

### Choose Hybrid If:

- ✓ You need both symbolism and data
- ✓ Power users demand at-a-glance metrics
- ✓ You're willing to invest 12-16 dev hours
- ✓ Complexity is acceptable trade-off

---

## Next Steps

### 1. Make Decision
- [ ] Review this summary
- [ ] Check detailed docs (MenubarIconDesignConcepts.md)
- [ ] View SVG mockups (docs/design/mockups/)
- [ ] Approve Option A, B, or C

### 2. Implementation
- [ ] Assign developer
- [ ] Follow ImplementationGuide.md
- [ ] Use SizeSpecifications.md for details
- [ ] Complete in 3-4 weeks

### 3. Testing
- [ ] Visual testing (all sizes, displays, modes)
- [ ] Performance benchmarks
- [ ] Accessibility audit
- [ ] Beta user feedback

### 4. Launch
- [ ] Production release
- [ ] Update release notes
- [ ] Monitor user feedback
- [ ] Iterate as needed

---

## Files & Resources

### Documentation
- `/docs/design/README.md` - Navigation guide
- `/docs/design/MenubarIconDesignConcepts.md` - Full analysis (23KB)
- `/docs/design/DesignComparisonChart.md` - Detailed comparison (15KB)
- `/docs/design/ImplementationGuide.md` - Developer guide (23KB)
- `/docs/design/SizeSpecifications.md` - Technical specs (15KB)

### Mockups
- `/docs/design/mockups/InfinityIconConcept.svg` - Single infinity icon
- `/docs/design/mockups/InfinityIconStates.svg` - All 12 state variations
- `/docs/design/mockups/WaveLogoRefined.svg` - Enhanced current design
- `/docs/design/mockups/HybridIconConcept.svg` - Hybrid concept

### Implementation
- `/Sources/Runic/Core/Rendering/IconRenderer.swift` - Current implementation
- `/Sources/Runic/Resources/RunicMenubarIcon.svg` - Current wave logo
- `/Sources/Runic/Controllers/StatusItemController.swift` - Icon usage

---

## Final Recommendation

**Go with Option A: Infinity Symbol + Provider Icon**

**Why:**
- Strongest brand identity (5/5)
- Best provider visibility (5/5)
- Excellent scalability (5/5)
- Clear conceptual metaphor (5/5)
- Acceptable trade-offs on data visibility

**Timeline:** 3-4 weeks from approval to production

**Cost:** 8-12 developer hours

**Risk:** Low (familiar patterns, straightforward implementation)

**User Impact:** Positive (clearer symbolism, better provider ID, maintained functionality)

---

**Decision Needed:** Approve Option A for implementation?

**Questions?** Review detailed documentation in `/docs/design/` or consult design team.

---

**Last Updated:** February 1, 2026

**Status:** Awaiting Implementation Approval
