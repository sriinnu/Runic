# Runic Improvement Plan

**Generated:** January 31, 2026
**Status:** 📋 Action Plan from 6-Agent Comprehensive Review
**Timeline:** 4-6 Weeks

---

## Executive Summary

Six specialized agents completed a comprehensive review of the Runic codebase across architecture, performance, UI/UX, security, testing, and documentation. This plan prioritizes improvements for maximum impact.

### Overall System Health

| Category | Current Grade | Target Grade | Priority |
|----------|---------------|--------------|----------|
| **Architecture** | B+ | A- | HIGH |
| **Performance** | B | A | HIGH |
| **UI/UX** | C+ (5/10) | B+ (8/10) | CRITICAL |
| **Security** | A- (5/5) | A+ | HIGH |
| **Test Coverage** | C (16%) | B+ (60%) | CRITICAL |
| **Documentation** | C+ (7.5/10) | B+ (9/10) | HIGH |

---

## Critical Findings Summary

### 🔴 CRITICAL Issues (Must Fix)

1. **Accessibility Compliance** - ZERO screen reader support
2. **Test Coverage** - Only 16% code coverage, critical paths untested
3. **UsageStore God Class** - 2,127 lines, architectural bottleneck
4. **Input Validation** - JSON parsing without size limits or validation
5. **Documentation Gaps** - No troubleshooting guide, deployment docs

### 🟡 HIGH Priority Issues

1. **Performance** - 30-50% improvement possible with targeted fixes
2. **Security Hardening** - Missing certificate pinning, weak keychain settings
3. **UI Consistency** - Disparate design systems across platforms
4. **Error Handling** - Generic error messages, no retry mechanisms
5. **React Native** - N+1 rendering issues, no virtualization

### 🟢 MEDIUM Priority Issues

1. **Code Organization** - File size violations, tight coupling
2. **Loading States** - No skeleton screens or shimmer effects
3. **Monitoring** - No observability or metrics
4. **SwiftUI Patterns** - Missing view models, tight AppKit coupling
5. **Caching Strategy** - No TTL, potential memory leaks

---

## Improvement Roadmap

### Phase 1: Critical Fixes (Week 1-2) 🔴

#### Week 1: Accessibility & Core Tests

**Priority 1.1: Accessibility Compliance**
- [ ] Add `accessibilityLabel` to all interactive elements
- [ ] Add `accessibilityRole` to all components
- [ ] Test with VoiceOver (iOS/macOS)
- [ ] Test with TalkBack (Android)
- [ ] Implement Dynamic Type support

**Estimated Impact:** Legal compliance, 15% wider user base
**Effort:** 40 hours
**Assignee:** UI/UX team

**Priority 1.2: Critical Test Coverage**
- [ ] Create `UsageLedgerTests.swift` (aggregation logic)
- [ ] Create `BackgroundSyncManagerTests.swift` (sync orchestration)
- [ ] Create `GroqUsageFetcherTests.swift`
- [ ] Create `OpenRouterUsageFetcherTests.swift`
- [ ] Create `UsageStoreTests.swift` (main state)

**Estimated Impact:** 30% coverage increase, catch critical bugs
**Effort:** 60 hours
**Assignee:** QA team

#### Week 2: Architecture & Security

**Priority 1.3: Refactor UsageStore**
```
Split into:
- UsageStateStore (observable state, ~400 lines)
- UsageFetchingService (fetch coordination, ~500 lines)
- UsageStatusComputer (status logic, ~200 lines)
```

**Estimated Impact:** 15-20% memory reduction, 25% faster loads
**Effort:** 80 hours
**Assignee:** Backend team

**Priority 1.4: Input Validation**
- [ ] Add JSON payload size limits (5MB max)
- [ ] Implement RFC 5322 email validation
- [ ] Add Content-Type validation
- [ ] Bound JSON traversal iterations

**Estimated Impact:** Prevent DoS attacks, data corruption
**Effort:** 16 hours
**Assignee:** Security team

---

### Phase 2: Performance & UI (Week 3-4) 🟡

#### Week 3: Performance Optimizations

**Priority 2.1: Menu Rendering Optimization**
- [ ] Implement differential menu updates
- [ ] Add provider spec caching with invalidation
- [ ] Stop animation loop faster (<3s max)
- [ ] Skip animation ticks when no state changes

**Estimated Impact:** 40-50% faster menu construction, 60% CPU reduction
**Effort:** 32 hours
**Assignee:** Performance team

**Priority 2.2: React Native Optimizations**
- [ ] Convert HomeScreen ScrollView to FlatList
- [ ] Memoize chart components with React.memo()
- [ ] Implement sync debounce (1-second)
- [ ] Add concurrent request limiting (max 3)

**Estimated Impact:** 60-80% improvement on large lists, smooth 60 FPS
**Effort:** 20 hours
**Assignee:** Mobile team

#### Week 4: UI/UX Improvements

**Priority 2.3: Error Message Quality**
- [ ] Add error context information
- [ ] Provide actionable next steps
- [ ] Show retry buttons for network errors
- [ ] Log error IDs for support

**Estimated Impact:** 40% reduction in support tickets
**Effort:** 16 hours
**Assignee:** UI/UX team

**Priority 2.4: Loading States**
- [ ] Implement skeleton screens for provider lists
- [ ] Add shimmer effect for data loading
- [ ] Show meaningful progress for sync operations
- [ ] Add loading state indicators in buttons

**Estimated Impact:** Better perceived performance, professional polish
**Effort:** 24 hours
**Assignee:** UI/UX team

---

### Phase 3: Security & Testing (Week 5-6) 🟢

#### Week 5: Security Hardening

**Priority 3.1: Certificate Pinning**
- [ ] Implement certificate pinning for all API endpoints
- [ ] Create PinningDelegate class
- [ ] Add backup certificates
- [ ] Test with compromised CA scenario

**Estimated Impact:** Prevent MITM attacks
**Effort:** 20 hours
**Assignee:** Security team

**Priority 3.2: Keychain Security Upgrade**
- [ ] Change to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- [ ] Add Secure Enclave protection where available
- [ ] Implement access control lists (ACL)
- [ ] Set restrictive file permissions (0600)

**Estimated Impact:** Enhanced token security
**Effort:** 16 hours
**Assignee:** Security team

#### Week 6: Integration Tests & Documentation

**Priority 3.3: Integration Tests**
- [ ] Create end-to-end provider flow tests
- [ ] Create multi-provider aggregation tests
- [ ] Create sync workflow tests
- [ ] Create error recovery tests

**Estimated Impact:** 45% coverage increase, catch integration bugs
**Effort:** 40 hours
**Assignee:** QA team

**Priority 3.4: Documentation**
- [ ] Create `docs/TROUBLESHOOTING.md`
- [ ] Create `docs/DEPLOYMENT.md`
- [ ] Create `docs/API_ERRORS.md`
- [ ] Create `docs/DATABASE.md`

**Estimated Impact:** 50% faster onboarding, reduced support load
**Effort:** 24 hours
**Assignee:** Technical writer

---

## Detailed Improvement Items

### Architecture Improvements

#### A1: UsageStore Refactoring (HIGH PRIORITY)
**Current:** 2,127 lines god class
**Target:** 3 focused classes <500 lines each

```swift
// Before
final class UsageStore {
    // Everything: state, fetching, caching, animation
}

// After
final class UsageStateStore {
    // Just observable state
}

final class UsageFetchingService {
    // Just fetch coordination
}

final class UsageStatusComputer {
    // Just status computation
}
```

**Benefits:**
- 15-20% memory reduction
- 25% faster load times
- Easier testing and maintenance

#### A2: Reduce Coupling via Protocols (MEDIUM)
**Current:** Direct SettingsStore dependency
**Target:** Protocol-based abstraction

```swift
protocol RefreshConfiguring {
    var refreshFrequency: RefreshFrequency { get }
    var autoDisableRefreshWhenIdleEnabled: Bool { get }
}

func refresh(config: RefreshConfiguring) async
```

#### A3: Unified Cache Layer (MEDIUM)
**Current:** Multiple scattered caches
**Target:** Single actor-based cache

```swift
actor ProviderDataCache {
    func cached<T>(_ key: String, age: TimeInterval,
                   fetch: () async -> T) async -> T
}
```

---

### Performance Improvements

#### P1: Menu Construction Optimization (HIGH)
**Impact:** 40-50% reduction in menu construction time

- Implement differential updates using `menuVersions` tracking
- Cache enabled providers list
- Stop animation after 3 seconds max

#### P2: React Native Virtualization (HIGH)
**Impact:** 60-80% improvement on large provider lists

```typescript
// Before: ScrollView (renders everything)
<ScrollView>
  {providers.map(p => <ProviderCard />)}
</ScrollView>

// After: FlatList (virtualized)
<FlatList
  data={providers}
  keyExtractor={(p) => p.id}
  renderItem={({ item }) => <ProviderCard provider={item} />}
/>
```

#### P3: API Server Caching (MEDIUM)
**Impact:** 60-70% reduction in database load

- Add Redis with 30-second TTL
- Cache provider list responses
- Add cache control headers

#### P4: Concurrent Request Limiting (LOW)
**Impact:** 40-50% memory reduction during multi-provider sync

```typescript
// Use pLimit to restrict concurrent syncs
import pLimit from 'p-limit';
const limit = pLimit(3);
const promises = providers.map(p => limit(() => syncProvider(p)));
```

---

### UI/UX Improvements

#### U1: Accessibility (CRITICAL)
**Impact:** WCAG 2.1 AA compliance, 15% wider user base

- Add accessibility labels to all elements
- Implement VoiceOver/TalkBack support
- Add Dynamic Type support
- Test with screen readers

#### U2: Error Messages (HIGH)
**Impact:** 40% reduction in support tickets

```typescript
// Before
"Sync failed"

// After
"Unable to sync with Claude API
Reason: Network connection lost
Next Steps:
1. Check your internet connection
2. Click 'Retry' to try again
3. Contact support if issue persists (Error: NET_001)"
```

#### U3: Loading States (MEDIUM)
**Impact:** Better perceived performance

- Skeleton screens for provider lists
- Shimmer effect during loading
- Progress indicators for long operations

#### U4: Haptic Feedback (LOW)
**Impact:** Professional polish on mobile

```typescript
import ReactNativeHapticFeedback from 'react-native-haptic-feedback';

const onPress = () => {
  ReactNativeHapticFeedback.trigger('impactLight');
  // handle press
};
```

---

### Security Improvements

#### S1: Certificate Pinning (HIGH)
**Impact:** Prevent MITM attacks

```swift
enum CertificatePinning {
    static let pinnedDomains: [String: [Data]] = [
        "api.anthropic.com": [cert1Hash, cert2Hash],
        "api.openai.com": [cert1Hash, cert2Hash],
    ]
}
```

#### S2: Input Validation (HIGH)
**Impact:** Prevent DoS and injection attacks

- JSON payload size limits (5MB)
- Email validation (RFC 5322)
- URL validation
- Path traversal prevention

#### S3: Keychain Security (MEDIUM)
**Impact:** Enhanced token security

```swift
let attributes: [String: Any] = [
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    kSecAttrSynchronizable as String: false,
    kSecAttrIsInvisible as String: true,
]
```

#### S4: Log Sanitization (MEDIUM)
**Impact:** Prevent token leakage in logs

```swift
// Sanitize token logs
log("Session key: \(sanitize(sessionKey))") // Shows last 4 chars only
log("Email: \(sanitize(email))") // Masks local part
```

---

### Testing Improvements

#### T1: Critical Path Tests (CRITICAL)
**Impact:** 30% coverage increase

Priority test files:
1. `UsageLedgerTests.swift`
2. `BackgroundSyncManagerTests.swift`
3. `UsageStoreTests.swift`
4. `GroqUsageFetcherTests.swift`
5. `OpenRouterUsageFetcherTests.swift`

#### T2: Integration Tests (HIGH)
**Impact:** 45% coverage increase

Test scenarios:
1. End-to-end provider flow
2. Multi-provider aggregation
3. Sync workflow
4. Error recovery
5. Settings persistence

#### T3: UI Component Tests (MEDIUM)
**Impact:** Prevent regression

Test files:
- `StatusItemControllerTests.swift`
- `PreferencesViewTests.swift`
- Widget component tests

---

### Documentation Improvements

#### D1: Troubleshooting Guide (CRITICAL)
**Impact:** 50% reduction in support tickets

Create `docs/TROUBLESHOOTING.md` with:
- Common errors and solutions
- Debugging procedures
- Crash log analysis
- Permission issues

#### D2: Deployment Guide (CRITICAL)
**Impact:** Faster production deployment

Create `docs/DEPLOYMENT.md` with:
- Production deployment steps
- Docker containerization
- Cloud platform instructions
- Database initialization

#### D3: API Error Reference (HIGH)
**Impact:** Better developer experience

Create `docs/API_ERRORS.md` with:
- All error codes
- Response schemas
- Retry strategies
- Resolution steps

#### D4: Database Documentation (HIGH)
**Impact:** Easier maintenance

Create `docs/DATABASE.md` with:
- Schema definitions
- Migration procedures
- Backup strategies

---

## Success Metrics

### Performance Targets

| Metric | Current | Target | Improvement |
|--------|---------|--------|-------------|
| Menu Construction | 500ms | 200ms | 60% |
| Animation CPU | 8% | 2% | 75% |
| HomeScreen Renders | 50/scroll | 10/scroll | 80% |
| API Response Time | 400ms | 80ms | 80% |
| Memory (Long Session) | 250MB | 180MB | 28% |
| Test Coverage | 16% | 60% | 275% |

### Quality Targets

| Metric | Current | Target |
|--------|---------|--------|
| Accessibility Score | 2/10 | 9/10 |
| Security Score | 5/5 | 5/5 |
| UI/UX Score | 5/10 | 8/10 |
| Documentation Score | 7.5/10 | 9/10 |
| Code Coverage | 16% | 60% |

---

## Resource Requirements

### Team Allocation (6 weeks)

| Team | Hours/Week | Total Hours |
|------|------------|-------------|
| Backend | 20 | 120 |
| Frontend/Mobile | 16 | 96 |
| QA/Testing | 16 | 96 |
| Security | 8 | 48 |
| Technical Writer | 4 | 24 |
| **Total** | **64** | **384** |

### External Dependencies

- VoiceOver/TalkBack testing devices
- Redis instance for API caching
- SSL certificates for pinning
- Monitoring/observability platform

---

## Risk Assessment

### High Risk

- **UsageStore Refactoring** - Complex, high-impact changes
  - *Mitigation*: Comprehensive tests before refactor, feature flags

- **Certificate Pinning** - Could break connectivity if misconfigured
  - *Mitigation*: Gradual rollout, backup certificates, kill switch

### Medium Risk

- **React Native Changes** - Platform-specific bugs
  - *Mitigation*: Thorough testing on multiple devices

- **Performance Optimizations** - May introduce subtle bugs
  - *Mitigation*: Performance benchmarks, A/B testing

### Low Risk

- Documentation improvements
- UI polish
- Test additions

---

## Implementation Guidelines

### Code Quality Standards

- All new code must have 80%+ test coverage
- All files must be <400 lines
- All functions must have JSDoc/Swift docs
- All accessibility labels required
- Security review required for auth/network code

### Review Process

1. **Architecture Review** - For structural changes
2. **Security Review** - For auth/network/crypto
3. **Performance Review** - For optimization changes
4. **Accessibility Review** - For UI changes
5. **QA Sign-off** - For all changes

### Deployment Strategy

1. **Week 1-2**: Feature flags enabled, beta testing
2. **Week 3-4**: Gradual rollout (10% → 50% → 100%)
3. **Week 5-6**: Monitor metrics, adjust as needed

---

## Next Steps

### Immediate Actions (Today)

1. ✅ README and LICENSE updated
2. ✅ Comprehensive review completed
3. ✅ Improvement plan created
4. ⏳ Share plan with team for prioritization

### Week 1 Kickoff

1. [ ] Team review meeting
2. [ ] Assign tasks to team members
3. [ ] Setup tracking (JIRA/GitHub Projects)
4. [ ] Begin Phase 1 implementation

---

## Appendix: Review Reports

Full detailed reports available:
- Architecture Review (Agent af50444)
- Performance Review (Agent ac2a25f)
- UI/UX Review (Agent a282df0)
- Security Hardening (Agent ab4da1b)
- Test Coverage (Agent a0db3be)
- Documentation Review (Agent abcfb34)

---

**Generated by:** 6-Agent Parallel Review System
**Date:** January 31, 2026
**Status:** Ready for Implementation

**Questions?** Review individual agent reports for detailed analysis.
