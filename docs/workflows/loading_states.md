# Loading States Documentation

This document describes the professional loading states implementation throughout the Runic app.

## Overview

Professional loading states provide visual feedback during async operations, improving perceived performance and user experience. The implementation follows Material Design guidelines with skeleton screens, shimmer effects, and progress indicators.

## Components

### SwiftUI (macOS/iOS)

#### 1. SkeletonView
**Location:** `Sources/Runic/Views/Components/SkeletonView.swift`

Basic skeleton rectangle with shimmer animation:
```swift
SkeletonView(cornerRadius: 4, height: 20)
```

**Features:**
- Shimmer animation (1.5s duration)
- 45-degree angle gradient
- Light gray base with white highlight
- Configurable corner radius and height

#### 2. SkeletonCardView
**Location:** `Sources/Runic/Views/Components/SkeletonView.swift`

Full card skeleton matching MenuCardView layout:
```swift
SkeletonCardView(width: 300)
```

**Features:**
- Matches final UI layout precisely
- Header, metrics, and credits sections
- Smooth fade-in transition

#### 3. LoadingIndicator
**Location:** `Sources/Runic/Views/Components/SkeletonView.swift`

Progress indicator with optional label:
```swift
LoadingIndicator(message: "Syncing with Claude...", size: 16)
```

**Use cases:**
- During sync operations
- Authentication flows
- Data fetching

#### 4. LoadingButton
**Location:** `Sources/Runic/Views/Components/SkeletonView.swift`

Button with integrated loading state:
```swift
LoadingButton(isLoading: isSyncing, action: handleSync) {
    Text("Sync Now")
}
```

**Features:**
- Auto-shows spinner when loading
- Disables interaction during loading
- Smooth transitions

#### 5. LoadingState Enum
**Location:** `Sources/Runic/Views/Components/SkeletonView.swift`

Type-safe state management:
```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(Error)
}
```

**Usage:**
```swift
@State private var state: LoadingState<Provider> = .idle

// Loading
state = .loading

// Success
state = .loaded(provider)

// Error
state = .failed(error)

// Access
if let provider = state.value {
    // Use provider
}
```

### React Native (Windows/Android)

#### 1. SkeletonView
**Location:** `runic-cross-platform/src/components/SkeletonView.tsx`

Animated skeleton with shimmer:
```tsx
<SkeletonView width={100} height={20} borderRadius={4} />
<SkeletonView width="100%" height={40} />
```

**Features:**
- LinearGradient shimmer effect
- 1.5s animation loop
- Configurable dimensions
- Percentage or pixel width

#### 2. SkeletonCard
**Location:** `runic-cross-platform/src/components/SkeletonView.tsx`

Full provider card skeleton:
```tsx
<SkeletonCard />
```

**Features:**
- Matches ProviderCard layout
- Header, quota, footer sections
- Theme-aware colors

#### 3. LoadingButton
**Location:** `runic-cross-platform/src/components/LoadingButton.tsx`

Button with loading state support:
```tsx
<LoadingButton
  label="Sync Now"
  onPress={handleSync}
  isLoading={isSyncing}
  loadingLabel="Syncing..."
  variant="primary"
/>
```

**Variants:**
- `primary` - Filled button with primary color
- `secondary` - Filled with secondary container color
- `text` - Transparent with primary text color

**Features:**
- ActivityIndicator during loading
- Disabled state during loading
- Custom loading label
- Smooth transitions

#### 4. LoadingState Type
**Location:** `runic-cross-platform/src/components/SkeletonView.tsx`

Type-safe state management:
```typescript
type LoadingState<T> =
  | { type: 'idle' }
  | { type: 'loading' }
  | { type: 'loaded'; data: T }
  | { type: 'failed'; error: Error };

// Helpers
LoadingStateHelpers.loading()
LoadingStateHelpers.loaded(data)
LoadingStateHelpers.failed(error)

// Checks
LoadingStateHelpers.isLoading(state)
LoadingStateHelpers.getData(state)
```

## Implementation Examples

### SwiftUI - MenuCardView

The menu card automatically shows skeleton when loading:

```swift
if self.model.metrics.isEmpty {
    if let placeholder = self.model.placeholder {
        if self.model.subtitleStyle == .loading {
            SkeletonCardView(width: self.width)
                .transition(.opacity)
        } else {
            Text(placeholder)
                .transition(.opacity)
        }
    }
}
```

**States:**
- Loading: Shows SkeletonCardView
- Empty: Shows "No usage yet" text
- Error: Shows error message
- Loaded: Shows actual data

### React Native - ProviderCard

Provider cards show loading indicator overlay:

```tsx
export const ProviderCard = React.memo(
  function ProviderCard({ provider, isRefreshing = false }) {
    const [fadeAnim] = useState(new Animated.Value(0));

    useEffect(() => {
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }).start();
    }, [provider.id]);

    return (
      <Animated.View style={{ opacity: fadeAnim }}>
        <TouchableOpacity disabled={isRefreshing}>
          {isRefreshing && (
            <ActivityIndicator size="small" />
          )}
          {/* Card content */}
        </TouchableOpacity>
      </Animated.View>
    );
  }
);
```

**Features:**
- Fade-in on mount (300ms)
- Loading indicator overlay
- Disabled during refresh
- Smooth transitions

### React Native - HomeScreen

Home screen shows skeleton cards during initial load:

```tsx
{isLoading && !refreshing ? (
  <View style={styles.loadingContainer}>
    <LoadingSpinner size={48} />
    <Text>Loading providers...</Text>
    <View style={styles.skeletonContainer}>
      {[1, 2, 3].map((i) => (
        <SkeletonCard key={i} />
      ))}
    </View>
  </View>
) : (
  <FlatList
    data={enabledProviders}
    renderItem={renderProviderCard}
    refreshControl={
      <RefreshControl
        refreshing={refreshing}
        onRefresh={handleRefresh}
      />
    }
  />
)}
```

**States:**
- Initial load: Shows spinner + skeleton cards
- Pull-to-refresh: Shows refresh control
- Empty: Shows empty state UI
- Loaded: Shows provider list

## Animation Specifications

### Shimmer Effect

**Duration:** 1.5 seconds
**Colors:**
- Base: Light gray (opacity 0.3)
- Highlight: White (opacity 0.4)
**Angle:** 45 degrees
**Loop:** Infinite

**SwiftUI Implementation:**
```swift
Animated.timing(fadeAnim, {
  toValue: 1,
  duration: 1500,
  easing: Easing.linear,
  useNativeDriver: true,
}).start();
```

**React Native Implementation:**
```tsx
Animated.loop(
  Animated.timing(shimmerPosition, {
    toValue: 1,
    duration: 1500,
    easing: Easing.linear,
    useNativeDriver: true,
  })
).start();
```

### Fade-In Transition

**Duration:** 300ms
**Easing:** Ease-out
**Use:** When data loads

```swift
.transition(.opacity)
```

```tsx
Animated.timing(fadeAnim, {
  toValue: 1,
  duration: 300,
  useNativeDriver: true,
}).start();
```

## Best Practices

### 1. Show Loading Immediately
Loading states should appear instantly when an operation starts:
```swift
func sync() async {
    state = .loading  // Immediate
    let data = await fetchData()
    state = .loaded(data)
}
```

### 2. Match Final Layout
Skeleton screens should mirror the final UI layout exactly:
```swift
// Bad - generic rectangle
SkeletonView(height: 100)

// Good - matches actual layout
VStack {
    SkeletonView(height: 16)  // Title
    SkeletonView(height: 4)   // Progress bar
    SkeletonView(height: 12)  // Subtitle
}
```

### 3. Smooth Transitions
Always use transitions when switching between states:
```swift
withAnimation(.easeOut(duration: 0.3)) {
    showContent = true
}
```

### 4. Accessibility
Provide meaningful labels for screen readers:
```swift
SkeletonCardView(width: width)
    .accessibilityLabel("Loading usage data")
```

### 5. Error States
Always handle errors gracefully:
```swift
switch state {
case .loading:
    SkeletonView()
case .loaded(let data):
    ContentView(data: data)
case .failed(let error):
    ErrorView(error: error)
case .idle:
    EmptyView()
}
```

## Performance Considerations

### 1. Use Native Driver
Always enable native driver for animations:
```tsx
useNativeDriver: true  // Runs on UI thread
```

### 2. Limit Skeleton Count
Show 3-5 skeleton items max:
```tsx
{[1, 2, 3].map((i) => <SkeletonCard key={i} />)}
```

### 3. Optimize Re-renders
Use React.memo for loading components:
```tsx
export const SkeletonCard = React.memo(
  function SkeletonCard({ style }) {
    // Component implementation
  }
);
```

### 4. Cleanup Animations
Stop animations when components unmount:
```tsx
useEffect(() => {
  const animation = startAnimation();
  return () => animation.stop();
}, []);
```

## Testing

### Visual Testing
- Verify skeleton matches final layout
- Check shimmer animation smoothness
- Test transitions between states
- Validate color contrast

### Functional Testing
- Test loading → loaded transition
- Test loading → error transition
- Verify accessibility labels
- Test animation cleanup

### Performance Testing
- Monitor animation frame rate (should be 60fps)
- Check memory usage during loading
- Verify no animation leaks

## Future Enhancements

1. **Staggered animations** - Skeleton items appear with slight delay
2. **Pulse animation** - Alternative to shimmer
3. **Content placeholders** - Show approximate content shape
4. **Progress tracking** - Show percentage for long operations
5. **Optimistic updates** - Show expected state immediately

## Related Documentation

- [Performance Optimization Guide](../PERFORMANCE.md)
- [Animation Guidelines](../ANIMATIONS.md)
- [Accessibility Guide](../ACCESSIBILITY.md)
- [Component Documentation](../COMPONENTS.md)
