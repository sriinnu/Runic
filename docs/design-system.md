# Runic Design System

**Version:** 1.0
**Last Updated:** January 31, 2026

This document defines the comprehensive design system for Runic's preferences UI and throughout the application. Following these guidelines ensures visual consistency, accessibility, and maintainability across all panes and components.

---

## Table of Contents

1. [Typography Scale](#typography-scale)
2. [Spacing System](#spacing-system)
3. [Color Palette](#color-palette)
4. [Component Patterns](#component-patterns)
5. [Status Indicators](#status-indicators)
6. [Best Practices](#best-practices)

---

## Typography Scale

Runic uses SwiftUI's semantic typography system with consistent font choices across the application.

### Section Titles
**Usage:** Top-level section headers in preferences panes

- **Font:** `.caption`
- **Weight:** System default
- **Color:** `.secondary`
- **Transform:** `.textCase(.uppercase)`
- **Example:** "SYSTEM", "USAGE", "AUTO-REFRESH SAFETY"

```swift
Text("Section Title")
    .font(.caption)
    .foregroundStyle(.secondary)
    .textCase(.uppercase)
```

### Subsection Headers
**Usage:** Settings section titles, card headers

- **Font:** `.subheadline.weight(.semibold)` or `.body.weight(.medium)`
- **Weight:** `.semibold` or `.medium`
- **Color:** Primary text (default)
- **Example:** "Refresh cadence", "Credits", "Cost"

```swift
Text("Subsection Header")
    .font(.subheadline.weight(.semibold))
```

### Body Text
**Usage:** Primary labels, toggle titles, setting descriptions

- **Font:** `.body`
- **Weight:** System default
- **Color:** Primary text (default)
- **Example:** "Start at Login", "Show cost summary"

```swift
Text("Setting Label")
    .font(.body)
```

### Captions & Metadata
**Usage:** Supplementary information, help text, timestamps

- **Font:** `.footnote` or `.caption`
- **Weight:** System default
- **Color:** `.tertiary` or `.secondary`
- **Line Limit:** Often uses `.fixedSize(horizontal: false, vertical: true)` for multi-line
- **Example:** "Automatically opens Runic when you start your Mac."

```swift
Text("Helper text explaining the setting above.")
    .font(.footnote)
    .foregroundStyle(.tertiary)
    .fixedSize(horizontal: false, vertical: true)
```

### Small Metadata
**Usage:** Tiny labels, status badges

- **Font:** `.caption2.weight(.medium)` or `.caption`
- **Weight:** `.medium` or `.semibold`
- **Color:** `.secondary`
- **Example:** Badge labels in advanced settings

```swift
Text("Badge Text")
    .font(.caption2.weight(.medium))
    .foregroundStyle(.secondary)
```

### Monospace Text
**Usage:** Debug output, JSON display, technical data

- **Font:** `.system(.footnote, design: .monospaced)` or `.system(.callout, design: .monospaced)`
- **When to use:**
  - Debug pane data display
  - File paths
  - JSON/technical content
  - Version numbers in technical contexts

```swift
Text(jsonOutput)
    .font(.system(.footnote, design: .monospaced))
```

---

## Spacing System

Runic uses the `RunicSpacing` enum for all spacing values, based on a **4pt grid system**. All spacing values are multiples of 4 for consistent visual rhythm.

### Base Spacing Scale

Located in `/Sources/Runic/Core/RunicSpacing.swift`:

| Constant | Value | Points | Use Cases |
|----------|-------|--------|-----------|
| `xxxs` | 2pt | Extra extra extra small | Minimal gaps, fine-tuning |
| `xxs` | 4pt | Extra extra small | Line spacing, tight vertical gaps |
| `xs` | 8pt | Extra small | Row spacing, compact sections |
| `sm` | 12pt | Small | Horizontal element spacing, comfortable gaps |
| `md` | 16pt | Medium | Section padding, moderate separation |
| `lg` | 24pt | Large | Major section spacing |
| `xl` | 32pt | Extra large | Page-level spacing (rare) |
| `xxl` | 48pt | Extra extra large | Maximum spacing (rare) |

### Semantic Spacing Constants

#### Menu Spacing
```swift
static let menuHorizontalPadding: CGFloat = sm  // 12pt
static let menuVerticalPadding: CGFloat = xs    // 8pt
static let cardSpacing: CGFloat = xs            // 8pt
```

#### Preferences Spacing
```swift
static let compact: CGFloat = 6                      // Between sm and xs
static let toggleRowSpacing: CGFloat = xs            // 8pt
static let sectionHeaderSpacing: CGFloat = md        // 16pt
static let stepperControlSpacing: CGFloat = xs       // 8pt
```

#### General Section Spacing
```swift
static let sectionSpacing: CGFloat = lg  // 24pt
```

### Vertical Spacing Between Sections

- **Between major settings groups:** `PreferencesLayoutMetrics.paneSpacing` (24pt)
- **Between section header and content:** `PreferencesLayoutMetrics.sectionHeaderSpacing` (16pt)
- **Within a section between items:** `PreferencesLayoutMetrics.sectionSpacing` (20pt)
- **Toggle rows internal spacing:** `RunicSpacing.xs` (8pt)

### Horizontal Padding Standards

- **Pane horizontal padding:** `PreferencesLayoutMetrics.paneHorizontal` (36pt)
- **Pane vertical padding:** `PreferencesLayoutMetrics.paneVertical` (24pt)
- **Menu card horizontal padding:** `MenuCardMetrics.horizontalPadding` / `RunicSpacing.sm` (12pt)
- **Field horizontal padding:** `RunicSpacing.xs` (8pt)

### Row Spacing in Lists

**Provider List Metrics:**
```swift
static let rowSpacing: CGFloat = RunicSpacing.sm          // 12pt horizontal
static let providerVerticalSpacing: CGFloat = RunicSpacing.md  // 16pt vertical
static let sectionSpacing: CGFloat = RunicSpacing.lg     // 24pt between sections
```

**Row Insets:**
```swift
static let rowInsets = EdgeInsets(
    top: RunicSpacing.md,     // 16pt
    leading: contentInset,    // 36pt
    bottom: RunicSpacing.md,  // 16pt
    trailing: contentInset    // 36pt
)
```

### Visual Examples

```
xxxs (2pt):  •·  Fine adjustment, padding tweaks
xxs  (4pt):  •··  Line spacing, divider padding
xs   (8pt):  •····  Toggle row spacing, card spacing
sm   (12pt): •······  Element gaps, stepper spacing
md   (16pt): •········  Section header spacing, row padding
lg   (24pt): •············  Major section spacing
xl   (32pt): •················  Rare large gaps
xxl  (48pt): •························  Maximum spacing
```

---

## Color Palette

Runic leverages macOS system colors for native appearance and automatic dark mode support.

### Primary Colors

- **Accent Color:** System accent color (user-customizable)
  - Used for: Links, primary actions, selected states
  - Access: `.accentColor`

### Text Colors

| Hierarchy | SwiftUI Color | NSColor Equivalent | Usage |
|-----------|---------------|-------------------|-------|
| **Primary** | Default | `.controlTextColor` | Main labels, titles, body text |
| **Secondary** | `.secondary` | `.secondaryLabelColor` | Subtitles, metadata, supporting text |
| **Tertiary** | `.tertiary` | `.tertiaryLabelColor` | Help text, captions, least important text |

**Menu Highlight Text Colors:**
```swift
MenuHighlightStyle.selectionText         // .selectedMenuItemTextColor
MenuHighlightStyle.normalPrimaryText     // .controlTextColor
MenuHighlightStyle.normalSecondaryText   // .secondaryLabelColor
```

### Background Colors

| Purpose | NSColor | Usage |
|---------|---------|-------|
| **Control Background** | `.controlBackgroundColor` | Text fields, stepper value displays, cards |
| **Text Background** | `.textBackgroundColor` | Input areas, editable regions |
| **Window Background** | System default | Main window backgrounds |
| **Selection** | `.selectedContentBackgroundColor` | Selected list items, highlighted rows |
| **Separator** | `.separatorColor` | Dividers between sections |

### Status Colors

#### Success
- **Color:** `.systemGreen` / `.green`
- **Usage:** Successful operations, positive states
- **Example:** "Success: 200 OK" webhook test

#### Warning
- **Color:** `.systemOrange` / `.orange`
- **Usage:** Alerts, cautionary states
- **Example:** Warning severity badges, high usage alerts

#### Error
- **Color:** `.systemRed` / `.red`
- **Usage:** Error messages, critical states, delete actions
- **Access:** `Color(nsColor: .systemRed)` or `MenuHighlightStyle.error(highlighted)`

#### Info
- **Color:** `.systemBlue` / `.blue`
- **Usage:** Informational states, neutral indicators
- **Example:** Info severity badges

#### Critical Badge Colors
```swift
case .info: return .blue
case .warning: return .orange
case .critical: return .red
```

### Border/Divider Colors

- **Standard Divider:** `Color(nsColor: .separatorColor)`
- **Thickness:** 1pt (system standard)
- **Vertical Padding:** `RunicSpacing.xxs` (4pt) on both sides

```swift
Divider()
    .padding(.vertical, RunicSpacing.xxs)
```

### Provider Brand Colors

Provider-specific colors from `ProviderDescriptorRegistry`:
```swift
let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
Color(red: color.red, green: color.green, blue: color.blue)
```

### Opacity Conventions

- **Disabled states:** `0.5` opacity
- **Subtle backgrounds:** `0.2` opacity (e.g., badge backgrounds)
- **Hover effects:** `0.18` opacity for pressed states
- **Progress track:** `0.22` opacity

---

## Component Patterns

### Toggle Rows

**Layout:** Checkbox on left, title/subtitle stacked on right

**Spacing:**
- Internal vertical spacing: `RunicSpacing.xs` (8pt)
- Padding top for checkbox alignment: `RunicSpacing.xxs` (4pt)

**Typography:**
- Title: `.font(.body)`
- Subtitle: `.font(.footnote)`, `.foregroundStyle(.tertiary)`

**Implementation:**
```swift
VStack(alignment: .leading, spacing: RunicSpacing.xs) {
    Toggle(isOn: self.$binding) {
        Text(self.title)
            .font(.body)
    }
    .toggleStyle(.checkbox)

    if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

### Section Headers

**Style:**
- Small caps uppercase text
- Secondary color for reduced hierarchy
- Caption font size

**Spacing:**
- Bottom spacing: `PreferencesLayoutMetrics.sectionHeaderSpacing` (16pt)

**Implementation:**
```swift
Text("Section Title")
    .font(.caption)
    .foregroundStyle(.secondary)
    .textCase(.uppercase)
```

### Cards/Containers

**Padding:**
- Internal padding: `RunicSpacing.xs` (8pt)
- Alert/rule rows: `RunicSpacing.xs` all sides

**Corner Radius:**
- Standard: `6pt` rounded corners
- Small elements: `4pt` (badges, small buttons)

**Background:**
- `Color(nsColor: .controlBackgroundColor)`
- Selected/hover: `.opacity(0.5)` or `.selectedContentBackgroundColor`

**Implementation:**
```swift
HStack {
    // Content
}
.padding(RunicSpacing.xs)
.background(Color(nsColor: .controlBackgroundColor))
.cornerRadius(6)
```

### Buttons

#### Sizes & Control Sizes
- **Large:** `.controlSize(.large)` - Used for prominent actions (e.g., "Quit Runic")
- **Regular:** Default - Standard actions
- **Small:** `.controlSize(.small)` - Secondary actions, compact layouts
- **Mini:** `.controlSize(.mini)` - Very small contexts (e.g., "Ack" button)

#### Styles
- **Bordered:** `.buttonStyle(.bordered)` - Standard secondary buttons
- **Bordered Prominent:** `.buttonStyle(.borderedProminent)` - Primary actions
- **Plain:** `.buttonStyle(.plain)` - Text-only, minimal chrome
- **Link:** `.buttonStyle(.link)` - Hyperlink appearance

#### Spacing
- Button groups: `RunicSpacing.xs` (8pt) or `RunicSpacing.sm` (12pt) between buttons

**Implementation:**
```swift
HStack(spacing: RunicSpacing.xs) {
    Button("Secondary") { }
        .buttonStyle(.bordered)
        .controlSize(.small)

    Button("Primary") { }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
}
```

### Text Fields

**Height:** System default based on control size

**Padding:**
- Horizontal: `RunicSpacing.xs` (8pt)
- Vertical: `RunicSpacing.xxs` (4pt)

**Border:** Provided by `.textFieldStyle(.roundedBorder)`

**Font:** `.font(.footnote)` for provider settings fields

**Implementation:**
```swift
TextField("Placeholder", text: $binding)
    .textFieldStyle(.roundedBorder)
    .font(.footnote)
    .padding(.horizontal, RunicSpacing.xs)
    .padding(.vertical, RunicSpacing.xxs)
```

### Dividers

**Thickness:** 1pt (system standard)

**Color:** `Color(nsColor: .separatorColor)`

**Spacing:**
- Vertical padding: `RunicSpacing.xxs` (4pt) on both sides
- For preference dividers: `PreferencesDivider` component

**Implementation:**
```swift
Divider()
    .padding(.vertical, RunicSpacing.xxs)

// Or use the component:
PreferencesDivider()  // Includes standard padding
```

### Stepper Controls

**Layout:** Label on left, stepper control on right

**Stepper Component:**
- Minus button, value display, plus button
- Horizontal spacing: `RunicSpacing.xs` (8pt)
- Value label font: `.footnote.weight(.semibold)`
- Value background: `Color(nsColor: .controlBackgroundColor)`
- Corner radius: `6pt`

**Value Display Padding:**
- Horizontal: `RunicSpacing.sm` (12pt)
- Vertical: `RunicSpacing.xxs` (4pt)

**Implementation:**
```swift
PreferenceStepperRow(
    title: "Setting Name",
    subtitle: "Helper text",
    step: 1,
    range: 1...100,
    valueLabel: { "\($0) units" },
    value: $bindingValue
)
```

### Pickers (Segmented)

**Style:** `.pickerStyle(.segmented)`

**Frame:** Often constrained with `.frame(maxWidth: 300-400)` for neat alignment

**Font:** System default (body)

**Spacing:** Parent container handles spacing

**Implementation:**
```swift
VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
    Text("Picker Label")
        .font(.body)

    Picker("", selection: $binding) {
        Text("Option 1").tag(Value.option1)
        Text("Option 2").tag(Value.option2)
    }
    .pickerStyle(.segmented)
    .frame(maxWidth: 300)

    Text("Help text for picker")
        .font(.footnote)
        .foregroundStyle(.tertiary)
}
```

---

## Status Indicators

### Success States

**Color:** Green (`.systemGreen`, `.green`)

**Icons:** Checkmark symbols (`checkmark`, `checkmark.circle.fill`)

**Badges:**
```swift
Text("SUCCESS")
    .font(.caption2.weight(.semibold))
    .padding(.horizontal, RunicSpacing.xs)
    .padding(.vertical, RunicSpacing.xxs)
    .background(Color.green.opacity(0.2))
    .foregroundStyle(.green)
    .cornerRadius(4)
```

**Text Examples:**
- "Success: 200 OK"
- Green foreground for success messages

### Error States

**Color:** Red (`.systemRed`, `.red`, `MenuHighlightStyle.error()`)

**Icons:** Exclamation marks, warning symbols

**Text Style:**
```swift
Text(errorMessage)
    .font(.footnote)
    .foregroundStyle(MenuHighlightStyle.error(isHighlighted))
    .lineLimit(4)
    .fixedSize(horizontal: false, vertical: true)
```

**Badges:**
```swift
Text("CRITICAL")
    .font(.caption2.weight(.semibold))
    .padding(.horizontal, RunicSpacing.xs)
    .padding(.vertical, RunicSpacing.xxs)
    .background(Color.red.opacity(0.2))
    .foregroundStyle(.red)
    .cornerRadius(4)
```

### Warning States

**Color:** Orange (`.systemOrange`, `.orange`)

**Badges:**
```swift
Text("WARNING")
    .font(.caption2.weight(.semibold))
    .padding(.horizontal, RunicSpacing.xs)
    .padding(.vertical, RunicSpacing.xxs)
    .background(Color.orange.opacity(0.2))
    .foregroundStyle(.orange)
    .cornerRadius(4)
```

**Usage:** Threshold alerts, cautionary states

### Loading States

**Indicators:**
- `ProgressView().controlSize(.small)`
- Typically displayed inline with text

**Text:**
```swift
Text("Refreshing...")
    .font(.footnote)
    .foregroundStyle(.secondary)

// Or with animation
Text("Testing...")
    .font(.footnote)
```

**Example:**
```swift
if isRefreshing {
    HStack {
        ProgressView().controlSize(.small)
        Text("Refreshing...")
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
}
```

### Disabled States

**Opacity:** `0.5`

**Implementation:**
```swift
PreferenceToggleRow(...)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.5)
```

**Color:** Text maintains normal colors but entire component is dimmed

**Interaction:** `.disabled(true)` prevents user interaction

---

## Best Practices

### Visual Hierarchy

1. **Use font weights strategically:**
   - `.semibold` or `.medium` for headers that need emphasis
   - Regular weight for body text
   - Never over-emphasize multiple elements in the same area

2. **Leverage color hierarchy:**
   - Primary text (default) for important content
   - `.secondary` for supporting information
   - `.tertiary` for least important text
   - Avoid using more than 3 text colors in a single section

3. **Consistent spacing creates rhythm:**
   - Use the spacing scale consistently
   - Larger spacing between unrelated groups
   - Smaller spacing within related items

4. **Size and proximity:**
   - Group related settings with tighter spacing
   - Separate distinct sections with dividers and increased spacing
   - Use section headers to introduce new topics

### When to Use Cards vs. Plain Backgrounds

**Use Cards (with background color) when:**
- Items are interactive (clickable rows)
- Content needs visual grouping/separation
- Highlighting important information
- Creating distinct list items

**Examples:**
- Alert rule rows
- Provider toggle rows
- History entries

**Use Plain Backgrounds when:**
- Simple form layouts
- Standard preference panes with clear hierarchy
- Content flows naturally top to bottom
- Dividers provide sufficient separation

**Examples:**
- General settings pane
- Toggle lists with dividers
- Simple preference sections

### Grouping Related Settings

1. **Use SettingsSection for major groups:**
   ```swift
   SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
       // Related settings
   }
   ```

2. **Add section titles for clarity:**
   ```swift
   Text("Section Name")
       .font(.caption)
       .foregroundStyle(.secondary)
       .textCase(.uppercase)
   ```

3. **Separate with dividers:**
   ```swift
   PreferencesDivider()
   ```

4. **Nest VStacks for sub-groupings:**
   ```swift
   VStack(alignment: .leading, spacing: RunicSpacing.xs) {
       // Tightly related items
   }
   ```

### Error Message Formatting

**Display Patterns:**
1. **Inline errors** - Show directly below the affected control
2. **Expandable errors** - Preview with "Show details" button
3. **Copy-able errors** - Include copy button for technical details

**Typography:**
- Font: `.footnote`
- Color: `.systemRed` or `MenuHighlightStyle.error()`
- Line limit: `4` with `.fixedSize(horizontal: false, vertical: true)`

**Best practices:**
- Truncate long errors with preview/expand pattern
- Always provide copy functionality for debugging
- Use clear, actionable language when possible
- Include technical details in expandable sections

**Example:**
```swift
if let error = errorMessage {
    VStack(alignment: .leading, spacing: RunicSpacing.xs) {
        HStack {
            Text("Error:")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button { copyError() } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
        }

        Text(error)
            .font(.footnote)
            .foregroundStyle(.red)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

### Icon Usage Guidelines

**System Icons (SF Symbols):**
- Use semantic icons that clearly represent the action/content
- Consistent icon style throughout (prefer outline over fill for UI chrome)
- Standard size unless specific context requires adjustment

**Common Icon Patterns:**
- Gear: Settings/preferences
- Plus: Add new item
- Minus: Remove item
- Trash: Delete permanently
- Pencil: Edit
- Checkmark: Success/confirmation
- Exclamation: Warning/error
- Info circle: Information/help
- Doc on doc: Copy action

**Provider Icons:**
- Use `ProviderBrandIcon.image(for:size:)` for consistent provider branding
- Standard size: `32pt` in provider lists
- Fallback: `circle.dotted` system icon

**Accessibility:**
- Mark decorative icons as `.accessibilityHidden(true)`
- Provide accessibility labels for functional icons
- Ensure icon + text combinations are clear

---

## Layout Conventions

### Preferences Pane Structure

All preference panes follow this standard structure:

```swift
PreferencesPane {
    SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
        Text("SECTION TITLE")
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)

        // Section content
    }

    PreferencesDivider()

    SettingsSection(...) {
        // Next section
    }
}
```

### Menu Card Structure

Menu cards use consistent internal spacing defined in `MenuCardMetrics`:

```swift
VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
    // Header section

    Divider()
        .padding(.vertical, RunicSpacing.xxs)

    VStack(alignment: .leading, spacing: MenuCardMetrics.sectionSpacing) {
        // Content sections
    }
}
.padding(.horizontal, MenuCardMetrics.horizontalPadding)
.padding(.top, MenuCardMetrics.headerTopPadding)
.padding(.bottom, MenuCardMetrics.headerBottomPadding)
```

---

## Accessibility Considerations

1. **Dynamic Type:** All text uses SwiftUI's semantic font styles for automatic scaling
2. **Color Independence:** Never rely on color alone to convey meaning
3. **Touch Targets:** Ensure interactive elements meet minimum size requirements
4. **Contrast:** Use system colors for automatic high contrast support
5. **Labels:** Provide accessibility labels for icons and controls
6. **VoiceOver:** Test with VoiceOver to ensure logical navigation

---

## File References

Key implementation files:
- **Spacing:** `/Sources/Runic/Core/RunicSpacing.swift`
- **Components:** `/Sources/Runic/Views/Preferences/PreferencesComponents.swift`
- **Menu Styles:** `/Sources/Runic/Views/Menu/MenuHighlightStyle.swift`
- **Card Metrics:** `/Sources/Runic/Views/Menu/MenuCardView.swift`

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | January 31, 2026 | Initial design system documentation |

---

**Maintained by:** Runic Development Team
**Contact:** For questions or updates to this design system, refer to the project repository.
