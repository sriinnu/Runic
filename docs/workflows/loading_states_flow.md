# Loading States Flow Diagram

## State Transitions

```
┌─────────────────────────────────────────────────────────────┐
│                        Loading States                        │
└─────────────────────────────────────────────────────────────┘

         ┌──────────┐
         │   IDLE   │
         └─────┬────┘
               │
               │ User Action / App Init
               │
               ▼
         ┌──────────┐
    ┌───│ LOADING  │───┐
    │   └──────────┘   │
    │                  │
    │ Success          │ Error
    │                  │
    ▼                  ▼
┌──────────┐      ┌──────────┐
│  LOADED  │      │  FAILED  │
└──────────┘      └──────────┘
    │                  │
    │                  │
    │ Refresh          │ Retry
    │                  │
    └────────┬─────────┘
             │
             ▼
       ┌──────────┐
       │ LOADING  │
       └──────────┘
```

## Component Flow

### SwiftUI - MenuCardView

```
App Launch
    │
    ├─► UsageStore.isRefreshing = true
    │       │
    │       ├─► Model.subtitleStyle = .loading
    │       │       │
    │       │       ├─► Show SkeletonCardView
    │       │       │       │
    │       │       │       └─► Shimmer animation (1.5s loop)
    │       │       │
    │       │       └─► Accessibility: "Loading usage data"
    │       │
    │       └─► Fetch Data
    │               │
    │               ├─► Success
    │               │       │
    │               │       ├─► Model.subtitleStyle = .info
    │               │       │
    │               │       └─► Fade in content (opacity transition)
    │               │
    │               └─► Error
    │                       │
    │                       ├─► Model.subtitleStyle = .error
    │                       │
    │                       └─► Show error message
    │
    └─► UsageStore.isRefreshing = false
```

### React Native - HomeScreen

```
Screen Mount
    │
    ├─► initializeProviders()
    │       │
    │       ├─► isLoading = true
    │       │       │
    │       │       ├─► Show LoadingSpinner
    │       │       │       │
    │       │       │       └─► Text: "Loading providers..."
    │       │       │
    │       │       └─► Show 3 SkeletonCards
    │       │               │
    │       │               └─► Shimmer animation
    │       │
    │       └─► fetchProviders()
    │               │
    │               ├─► Success
    │               │       │
    │               │       ├─► isLoading = false
    │               │       │
    │               │       └─► Render FlatList
    │               │               │
    │               │               └─► ProviderCards fade in (300ms)
    │               │
    │               └─► Error
    │                       │
    │                       └─► Show error state
    │
    └─► Pull to refresh
            │
            ├─► refreshing = true
            │       │
            │       ├─► RefreshControl spinner
            │       │
            │       └─► ProviderCards show loading overlay
            │
            └─► syncAllProviders()
                    │
                    └─► refreshing = false
```

## Visual States

### 1. Initial Load (Skeleton)

```
┌─────────────────────────────────────┐
│  Claude                    user@... │
│  ═══════════                 ═════  │  ◄── Skeleton bars
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  Session Usage                      │
│  ▓▓▓▓▓░░░░░░░░░░░░░░░              │  ◄── Shimmer effect
│  ═════        ═════════             │
│                                     │
│  Weekly Usage                       │
│  ▓▓▓▓▓▓▓░░░░░░░░░░░                │  ◄── Moving gradient
│  ═════        ═════════             │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  Credits                            │
│  ▓▓▓▓▓▓▓▓░░░░░░░░░                 │
│  ═════        ═════════             │
└─────────────────────────────────────┘

▓ = Shimmer highlight
░ = Base skeleton color
═ = Skeleton text placeholder
```

### 2. Loading with Data (Refresh)

```
┌─────────────────────────────────────┐
│  Claude                user@test... │  ⟳ ◄── Loading spinner
│  Updated 5 minutes ago              │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  Session Usage                      │
│  ████████████░░░░░░░░              │  ◄── Actual progress
│  75% used    Resets in 2 hours     │
│                                     │
│  Weekly Usage                       │
│  ██████████████████░               │
│  92% used    Resets in 3 days      │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  Credits                            │
│  ████████████████████              │
│  850 tokens  1000 tokens           │
└─────────────────────────────────────┘

⟳ = Spinner overlay
█ = Filled progress
░ = Empty progress
```

### 3. Loaded (Final State)

```
┌─────────────────────────────────────┐
│  Claude                user@test... │
│  Updated just now                   │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  Session Usage                      │
│  ████████████░░░░░░░░              │
│  75% used    Resets in 2 hours     │
│  On pace for 85% today             │
│                                     │
│  Weekly Usage                       │
│  ██████████████████░               │
│  92% used    Resets in 3 days      │
│  Above average usage               │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  Credits                            │
│  ████████████████████              │
│  850 tokens remaining              │
│  1000 tokens full scale            │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  Cost                               │
│  Today: $2.45 · 45K tokens         │
│  Last 30 days: $67.89 · 1.2M tok   │
└─────────────────────────────────────┘
```

### 4. Error State

```
┌─────────────────────────────────────┐
│  Claude                user@test... │
│  ⚠ Failed to fetch usage data       │  ◄── Error message
│  Network timeout. Click to retry.   │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  No usage data available            │  ◄── Placeholder text
│                                     │
└─────────────────────────────────────┘
```

## Button States

### LoadingButton Flow

```
Normal State
┌─────────────┐
│  Sync Now   │  ◄── Enabled, no spinner
└─────────────┘
      │
      │ User Click
      ▼
Loading State
┌─────────────┐
│ ⟳ Syncing...│  ◄── Disabled, with spinner
└─────────────┘
      │
      │ Complete
      ▼
Normal State
┌─────────────┐
│  Sync Now   │  ◄── Enabled again
└─────────────┘
```

## Animation Timeline

### Shimmer Animation (1.5s loop)

```
Time: 0.0s          0.5s          1.0s          1.5s
      │             │             │             │
      ▼             ▼             ▼             ▼
      ░░░░░░░░░░   ░░░▓▓▓░░░░   ░░░░░░▓▓▓░   ░░░░░░░░░░

      ◄─────────────────────────────────────────────►
                  Infinite Loop

░ = Base skeleton color (gray 0.3)
▓ = Shimmer highlight (white 0.4)
```

### Fade-in Animation (300ms)

```
Time: 0ms           100ms         200ms         300ms
      │             │             │             │
      ▼             ▼             ▼             ▼
Opacity: 0.0         0.33          0.67          1.0

      [Skeleton]    [Blend]       [Blend]       [Content]

      ◄─────────────────────────────────────────────►
                  One-time Transition
```

## Decision Tree

```
                    Need to show loading?
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
       YES                 NO                 │
        │                  │                  │
        ▼                  ▼                  │
   Have data?         Show content       Is error?
        │                                    │
   ┌────┴────┐                          ┌────┴────┐
   │         │                          │         │
  YES       NO                         YES       NO
   │         │                          │         │
   ▼         ▼                          ▼         ▼
Overlay   Skeleton                   Error     Empty
spinner   screen                     state     state
```

## Component Hierarchy

```
SwiftUI (MenuCardView)
│
├─► UsageMenuCardHeaderView
│   └─► Subtitle: "Refreshing..." or "Updated..."
│
├─► Divider (if hasDetails)
│
└─► Content Area
    ├─► if loading & no data
    │   └─► SkeletonCardView
    │       ├─► Header skeleton
    │       ├─► Metrics skeleton (2x)
    │       ├─► Credits skeleton
    │       └─► ShimmerModifier
    │
    ├─► if loaded
    │   ├─► Usage metrics
    │   ├─► Credits section
    │   ├─► Cost section
    │   └─► Insights section
    │
    └─► if error
        └─► Error message with copy button

React Native (HomeScreen)
│
├─► Header
│   └─► Summary Cards
│
├─► Alerts
│
└─► Content Area
    ├─► if isLoading
    │   ├─► LoadingSpinner
    │   ├─► "Loading providers..."
    │   └─► SkeletonContainer
    │       ├─► SkeletonCard (1)
    │       ├─► SkeletonCard (2)
    │       └─► SkeletonCard (3)
    │
    ├─► if loaded
    │   └─► FlatList
    │       ├─► ProviderCard (1)
    │       │   ├─► Animated.View (fade-in)
    │       │   └─► Loading overlay if refreshing
    │       ├─► ProviderCard (2)
    │       └─► ProviderCard (3)
    │
    └─► if empty
        └─► EmptyState
            ├─► "No Providers Added"
            ├─► Description
            └─► "Go to Settings" button
```

## State Management

### SwiftUI Pattern

```swift
@Observable
final class UsageStore {
    var isRefreshing: Bool = false
    var snapshots: [Provider: Snapshot] = [:]
    var errors: [Provider: Error] = [:]

    func refresh() async {
        isRefreshing = true  // ─┐
        defer {              //  │
            isRefreshing = false // Ensures cleanup
        }                    // ─┘

        // Fetch data
    }
}
```

### React Native Pattern

```typescript
const [state, setState] = useState<LoadingState<T>>(
    LoadingStateHelpers.idle()
);

const load = async () => {
    setState(LoadingStateHelpers.loading());

    try {
        const data = await fetch();
        setState(LoadingStateHelpers.loaded(data));
    } catch (error) {
        setState(LoadingStateHelpers.failed(error));
    }
};
```

## Performance Optimizations

1. **Native Driver**: All animations use native thread
2. **React.memo**: Prevents unnecessary re-renders
3. **Skeleton Limit**: Max 3 items shown
4. **Layout Matching**: Prevents content shift
5. **Cleanup**: Animations stopped on unmount

## Accessibility Flow

```
Screen Reader Announces:
│
├─► On loading start
│   └─► "Loading usage data"
│
├─► During shimmer
│   └─► [Silent - animation is decorative]
│
├─► On content load
│   └─► "Claude, Account: user@test.com, Updated just now,
│        Session Usage: 75% used, Weekly Usage: 92% used"
│
└─► On error
    └─► "Error: Failed to fetch usage data.
         Network timeout. Click to retry."
```

This flow diagram shows how loading states transition and interact throughout the application!
