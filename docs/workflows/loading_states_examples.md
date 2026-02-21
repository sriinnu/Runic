# Loading States - Usage Examples

Practical examples for implementing loading states in various scenarios.

## Example 1: Data Fetching with Skeleton

### SwiftUI

```swift
struct ProviderListView: View {
    @State private var state: LoadingState<[Provider]> = .idle

    var body: some View {
        ScrollView {
            switch state {
            case .idle:
                EmptyView()

            case .loading:
                // Show skeleton cards
                VStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonCardView(width: 300)
                    }
                }
                .transition(.opacity)

            case .loaded(let providers):
                // Show actual data
                VStack(spacing: 16) {
                    ForEach(providers) { provider in
                        ProviderCardView(provider: provider)
                    }
                }
                .transition(.opacity)

            case .failed(let error):
                ErrorView(error: error)
                    .transition(.opacity)
            }
        }
        .task {
            await loadProviders()
        }
    }

    func loadProviders() async {
        state = .loading

        do {
            try await Task.sleep(for: .seconds(0.5))
            let providers = try await fetchProviders()
            withAnimation(.easeOut(duration: 0.3)) {
                state = .loaded(providers)
            }
        } catch {
            withAnimation(.easeOut(duration: 0.3)) {
                state = .failed(error)
            }
        }
    }
}
```

### React Native

```tsx
function ProviderListScreen() {
  const [state, setState] = useState<LoadingState<Provider[]>>(
    LoadingStateHelpers.idle()
  );

  useEffect(() => {
    loadProviders();
  }, []);

  const loadProviders = async () => {
    setState(LoadingStateHelpers.loading());

    try {
      const providers = await fetchProviders();
      setState(LoadingStateHelpers.loaded(providers));
    } catch (error) {
      setState(LoadingStateHelpers.failed(error));
    }
  };

  const renderContent = () => {
    switch (state.type) {
      case 'loading':
        return (
          <View style={styles.skeletonContainer}>
            {[1, 2, 3].map((i) => (
              <SkeletonCard key={i} style={styles.card} />
            ))}
          </View>
        );

      case 'loaded':
        return state.data.map((provider) => (
          <ProviderCard
            key={provider.id}
            provider={provider}
          />
        ));

      case 'failed':
        return <ErrorView error={state.error} />;

      default:
        return null;
    }
  };

  return (
    <ScrollView>
      {renderContent()}
    </ScrollView>
  );
}
```

## Example 2: Button with Loading State

### SwiftUI

```swift
struct SyncButton: View {
    @State private var isSyncing = false

    var body: some View {
        LoadingButton(
            isLoading: isSyncing,
            action: handleSync
        ) {
            Text(isSyncing ? "Syncing..." : "Sync Now")
        }
    }

    func handleSync() {
        Task {
            isSyncing = true
            defer { isSyncing = false }

            try? await syncProviders()
        }
    }
}
```

### React Native

```tsx
function SyncButton() {
  const [isSyncing, setIsSyncing] = useState(false);

  const handleSync = async () => {
    setIsSyncing(true);
    try {
      await syncProviders();
    } finally {
      setIsSyncing(false);
    }
  };

  return (
    <LoadingButton
      label="Sync Now"
      loadingLabel="Syncing..."
      onPress={handleSync}
      isLoading={isSyncing}
      variant="primary"
    />
  );
}
```

## Example 3: Pull-to-Refresh

### React Native

```tsx
function HomeScreen() {
  const [refreshing, setRefreshing] = useState(false);
  const [providers, setProviders] = useState<Provider[]>([]);

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      const data = await fetchProviders(true);
      setProviders(data);
    } finally {
      setRefreshing(false);
    }
  };

  return (
    <FlatList
      data={providers}
      renderItem={({ item }) => (
        <ProviderCard
          provider={item}
          isRefreshing={refreshing}
        />
      )}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={handleRefresh}
          tintColor={theme.colors.primary}
        />
      }
    />
  );
}
```

## Example 4: Inline Loading Indicator

### SwiftUI

```swift
struct UsageMetricView: View {
    let metric: Metric?
    let isLoading: Bool

    var body: some View {
        HStack {
            Text("Usage")
                .font(.headline)

            Spacer()

            if isLoading {
                LoadingIndicator(message: "", size: 12)
            } else if let metric {
                Text("\(metric.value)%")
                    .font(.body)
            }
        }
    }
}
```

### React Native

```tsx
function UsageMetric({
  metric,
  isLoading
}: {
  metric?: Metric;
  isLoading: boolean
}) {
  return (
    <View style={styles.row}>
      <Text style={styles.label}>Usage</Text>

      {isLoading ? (
        <ActivityIndicator size="small" />
      ) : metric ? (
        <Text style={styles.value}>{metric.value}%</Text>
      ) : null}
    </View>
  );
}
```

## Example 5: Progressive Loading

### SwiftUI

```swift
struct DashboardView: View {
    @State private var basicDataLoaded = false
    @State private var detailDataLoaded = false

    var body: some View {
        VStack {
            // Always show header
            HeaderView()

            if basicDataLoaded {
                SummaryView()
                    .transition(.opacity)
            } else {
                SkeletonView(height: 60)
            }

            if detailDataLoaded {
                DetailView()
                    .transition(.opacity)
            } else {
                SkeletonCardView(width: 300)
            }
        }
        .task {
            await loadData()
        }
    }

    func loadData() async {
        // Load basic data first
        await loadBasicData()
        withAnimation {
            basicDataLoaded = true
        }

        // Then load detailed data
        await loadDetailData()
        withAnimation {
            detailDataLoaded = true
        }
    }
}
```

### React Native

```tsx
function DashboardScreen() {
  const [basicLoaded, setBasicLoaded] = useState(false);
  const [detailLoaded, setDetailLoaded] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    // Load basic data first
    await loadBasicData();
    setBasicLoaded(true);

    // Then load detailed data
    await loadDetailData();
    setDetailLoaded(true);
  };

  return (
    <View>
      <HeaderView />

      {basicLoaded ? (
        <SummaryView />
      ) : (
        <SkeletonView width="100%" height={60} />
      )}

      {detailLoaded ? (
        <DetailView />
      ) : (
        <SkeletonCard />
      )}
    </View>
  );
}
```

## Example 6: Optimistic Updates

### SwiftUI

```swift
struct ToggleView: View {
    @State private var isEnabled: Bool
    @State private var isPending = false

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Text("Auto-refresh")
                if isPending {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .disabled(isPending)
        .onChange(of: isEnabled) { newValue in
            handleToggle(newValue)
        }
    }

    func handleToggle(_ newValue: Bool) {
        Task {
            isPending = true
            defer { isPending = false }

            do {
                try await updateSetting(newValue)
            } catch {
                // Revert on error
                isEnabled = !newValue
            }
        }
    }
}
```

### React Native

```tsx
function ToggleSwitch({
  initialValue,
  onToggle
}: {
  initialValue: boolean;
  onToggle: (value: boolean) => Promise<void>
}) {
  const [value, setValue] = useState(initialValue);
  const [isPending, setIsPending] = useState(false);

  const handleToggle = async (newValue: boolean) => {
    // Optimistic update
    setValue(newValue);
    setIsPending(true);

    try {
      await onToggle(newValue);
    } catch (error) {
      // Revert on error
      setValue(!newValue);
      Alert.alert('Error', 'Failed to update setting');
    } finally {
      setIsPending(false);
    }
  };

  return (
    <View style={styles.row}>
      <Text>Auto-refresh</Text>
      {isPending && <ActivityIndicator size="small" />}
      <Switch
        value={value}
        onValueChange={handleToggle}
        disabled={isPending}
      />
    </View>
  );
}
```

## Example 7: Form Submission

### React Native

```tsx
function LoginForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async () => {
    setIsSubmitting(true);

    try {
      await login(email, password);
      navigation.navigate('Home');
    } catch (error) {
      Alert.alert('Error', error.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <View style={styles.form}>
      <TextInput
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        editable={!isSubmitting}
      />

      <TextInput
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        editable={!isSubmitting}
      />

      <LoadingButton
        label="Sign In"
        loadingLabel="Signing in..."
        onPress={handleSubmit}
        isLoading={isSubmitting}
        disabled={!email || !password}
      />
    </View>
  );
}
```

## Example 8: Multi-Step Process

### SwiftUI

```swift
struct SyncProgressView: View {
    enum Step {
        case authenticating
        case fetching
        case processing
        case complete
    }

    @State private var currentStep: Step = .authenticating

    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: progress)

            switch currentStep {
            case .authenticating:
                LoadingIndicator(message: "Authenticating...")
            case .fetching:
                LoadingIndicator(message: "Fetching data...")
            case .processing:
                LoadingIndicator(message: "Processing...")
            case .complete:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Complete!")
            }
        }
        .task {
            await performSync()
        }
    }

    var progress: Double {
        switch currentStep {
        case .authenticating: return 0.33
        case .fetching: return 0.66
        case .processing: return 0.99
        case .complete: return 1.0
        }
    }

    func performSync() async {
        currentStep = .authenticating
        await authenticate()

        currentStep = .fetching
        await fetchData()

        currentStep = .processing
        await processData()

        currentStep = .complete
    }
}
```

## Key Takeaways

1. **Show feedback immediately** - Users should see response within 100ms
2. **Match final layout** - Skeleton should mirror actual content
3. **Smooth transitions** - Use animations between states (300ms)
4. **Handle all states** - Idle, loading, loaded, failed
5. **Provide context** - Use descriptive loading messages
6. **Disable interaction** - Prevent actions during loading
7. **Cleanup properly** - Stop animations on unmount
8. **Test thoroughly** - Verify all state transitions
