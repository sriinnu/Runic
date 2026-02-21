# Silo 🏺

<p align="center">
  <img src="Assets/silo-logo.svg" alt="Silo logo" width="180" />
</p>
<p align="center">
  <em>Small-size mark: <code>Assets/silo-mark.svg</code></em>
</p>

**Cross-platform browser cookie storage extraction**

Silo is a Swift library for reading browser cookies across macOS, iOS, Linux, and Windows. Extract cookies from Safari, Chrome, Firefox, Edge, Brave, Arc, and more with a modern, type-safe API.

## ✨ Features

### Core Capabilities
- 🌍 **Multi-platform** – macOS, Linux, Windows, iOS (app container only)
- 🌐 **Multi-browser** – Safari, Chrome, Chromium, Firefox, Edge, Brave, Arc, Vivaldi, Helium, ChatGPT Atlas, and more
- 👤 **Profile-aware** – Multiple browser profile support with automatic detection
- 🔍 **Query filtering** – Domain/path/expiry/flag filtering plus optional domain/path regex filtering
- 🔐 **Decryption** – macOS Keychain + Local State, Windows DPAPI, Linux Secret Service + "peanuts" fallback
- 🧯 **Decryption policy** – Best-effort or strict failure behavior
- 🧹 **Redaction** – Safe logging via `BrowserCookieRecord.redactedValue`
- 🍪 **HTTPCookie** – Direct Foundation integration for seamless URLSession usage
- 🧾 **JSON import/export** – Round-trip normalized cookies for external tooling
- 📈 **Analytics + sync helpers** – Summarize and diff cookie sets (no write-back)
- 📊 **Normalized attributes** – Domain, path, expiry, secure/httpOnly, host-only, SameSite, priority, and partitioning when available

**What It Does**
- Reads local browser cookie stores for supported browsers and profiles.
- Decrypts Chromium cookies using platform keychains or explicit keys.
- Normalizes cookies into `BrowserCookieRecord` and `HTTPCookie`.
- Filters by domain/path/expiry/flags and optional regex patterns.

**What It Does Not Do**
- It is read-only: no cookie CRUD or write-back to browser stores.
- Sync helpers are analysis-only and do not apply changes.
- It does not bypass OS permissions or sandboxing.
- It does not expose Safari/WebKit SameSite values yet.

## Status
- Implemented: core models, query filtering, HTTPCookie mapping (host-only + SameSite where available), JSON import/export, analytics + sync helpers, mock store CRUD for tests, macOS/Linux/Windows readers, iOS app-container reader, Linux Secret Service lookup (explicit key override + opt-in peanuts fallback), Windows DPAPI key handling.
- Planned: deeper keyring integration and expanded iOS entitlements guidance.
- See `TODO.md` for the working backlog.
Note: Linux decryption uses Secret Service when available; the "peanuts" fallback is disabled unless `SILO_ALLOW_INSECURE_CHROMIUM_FALLBACK=1` is set. On iOS, only WebKit/Safari app-container cookies are discoverable unless you pass App Group containers.

## Roadmap
- Browser store write-back (CRUD) with encryption support
- Deeper Linux keyring/libsecret coverage
- Safari SameSite support if WebKit exposes it

## 📦 Installation

```swift
dependencies: [
    .package(url: "https://github.com/sriinnu/Silo.git", from: "1.0.0")
]
```

## ✅ Getting Started (Permissions + Setup)

### macOS
- Enable **Full Disk Access** for apps reading Safari cookies.
- Allow **Keychain** access when prompted for Chromium decryption.
- Optional: set `SILO_CHROME_SAFE_STORAGE` to override the keychain password.

### Linux
- Install and enable `secret-tool` (libsecret) for Chromium decryption.
- Silo resolves `secret-tool` from `SILO_SECRET_TOOL_PATH` (authoritative), well-known locations, or `PATH`.
- `secret-tool` lookups use a short timeout (default 2000ms); override with `SILO_SECRET_TOOL_TIMEOUT_MS` or set it to `0` to disable.
- If keyring is unavailable or locked, set `SILO_CHROME_SAFE_STORAGE` or enable the insecure fallback with `SILO_ALLOW_INSECURE_CHROMIUM_FALLBACK=1`.

### Windows
- Run as the same Windows user who owns the browser profile.
- Ensure access to the `Local State` file and profile database (DPAPI is user-bound).
- AES-GCM cookies (`v10`/`v11`) require a readable `Local State` key; legacy DPAPI cookies can still decrypt without it.

### iOS
- Reads **only** WebKit/Safari app-container cookies.
- Shared container access requires App Group entitlements and explicit container configuration.

### Quick Permissions Checklist

| Platform | Required Access | Notes |
|---------|------------------|-------|
| macOS | Full Disk Access (Safari), Keychain | Safari cookies live in protected locations. |
| Linux | Secret Service / libsecret | `secret-tool` required for Chromium decryption. |
| Windows | DPAPI (user profile) | Must run as the same Windows user. |
| iOS | App container + entitlements | WebKit/Safari only; App Groups required for shared containers. |

## 🚀 Quick Start

```swift
import Silo

let client = BrowserCookieClient(
    configuration: .init(decryptionFailurePolicy: .strict)
)

// List available profiles
let stores = client.stores(for: .chrome)

// Query cookies
let query = BrowserCookieQuery(
    domains: ["example.com"],
    domainMatch: .suffix
)

// Get records (grouped by store)
let sources = try client.records(matching: query, in: .chrome)
let records = sources.flatMap { $0.records }
for record in records {
    print(record.redactedValue)
}

// Convert to HTTPCookie
let cookies = try client.cookies(matching: query, in: .chrome)

// Export to JSON
let exportData = try client.exportJSON(matching: query, in: .chrome)
```

## 🌍 Platform Support

| Browser | macOS | Linux | Windows | iOS |
|---------|-------|-------|---------|-----|
| Safari (WebKit) | read | - | - | read (app container) |
| Chrome (Stable/Beta/Canary) | read | read | read | - |
| Chromium | read | read | read | - |
| Firefox | read | read | read | - |
| Edge (Stable/Beta/Canary) | read | read | read | - |
| Brave (Stable/Beta/Nightly) | read | read | read | - |
| Arc (Stable/Beta/Canary) | read | - | - | - |
| Vivaldi | read | read | read | - |
| Helium | read | read | read | - |
| ChatGPT Atlas | read | - | - | - |

Status legend: read = cookie reading implemented; discovery = profile/store detection only; planned = not implemented yet.
Notes: Safari/WebKit `Cookies.binarycookies` parsing does not currently expose SameSite, so `sameSite` is always `nil` for Safari/WebKit records. Regex filtering applies to `domainPattern` and `pathPattern` when `useRegex` is `true`; non-regex path matching uses `contains`/`prefix`/`exact`.

**Limitations**
- Safari/WebKit SameSite is not available from `Cookies.binarycookies` yet.
- iOS is limited to WebKit/Safari app-container cookies only.
- Linux keyring availability varies; you may need explicit keys or fallback settings.
- Real-world Safari binarycookies parsing still needs broader validation.

## 📝 API

### Query Filtering

```swift
// Exact match
let exactQuery = BrowserCookieQuery(
    domains: ["api.example.com"],
    domainMatch: .exact
)

// Multiple domains
let multiQuery = BrowserCookieQuery(
    domains: ["example.com", "example.org"],
    domainMatch: .suffix
)

// Regex domain match
let regexDomainQuery = BrowserCookieQuery(
    domainPattern: ".*\\.example\\.com$",
    useRegex: true
)

// Include expired
let allQuery = BrowserCookieQuery(
    domains: ["example.com"],
    includeExpired: true
)

// Regex path match
let apiQuery = BrowserCookieQuery(
    pathPattern: "^/api/",
    useRegex: true
)
```

### Browser Selection

```swift
// Specific browser
let cookies = try client.cookies(matching: query, in: .chrome)

// Multiple browsers
let allCookies = try client.cookies(
    matching: query,
    in: [.chrome, .firefox, .safari]
)
```

### JSON Export

```swift
let export = try client.export(matching: query, in: .chrome)
let json = try export.jsonData()
```

### JSON Import

```swift
let data = try Data(contentsOf: url)
let imported = try client.importJSON(data)
let importedRecords = imported.records

// If the payload does not include host-only metadata:
let relaxedImport = try client.importJSON(
    data,
    options: BrowserCookieImportOptions(defaultHostOnly: false)
)
```

### JSON Schema Version

`BrowserCookieExport` embeds a `schemaVersion` (currently `1`) so payloads can evolve safely.

### Analytics + Sync Helpers

```swift
let analytics = BrowserCookieAnalytics(records: records)
print(analytics.totalCount)

let plan = BrowserCookieSync.plan(existing: records, incoming: importedRecords)
if plan.hasChanges {
    print("Adds: \(plan.additions.count), Updates: \(plan.updates.count)")
}
```

### Mock Store (In-Memory CRUD)

```swift
let mockStore = BrowserCookieMockStore(browser: .chrome, label: "Mock")
let record = BrowserCookieRecord(
    domain: "example.com",
    name: "sid",
    path: "/",
    value: "abc",
    expires: nil,
    isSecure: true,
    isHTTPOnly: true)

try mockStore.create(record)
try mockStore.update(record)
mockStore.upsert(record)
_ = mockStore.delete(record)
```

## 🔐 Permissions

### macOS
- **Full Disk Access** for Safari
- **Keychain** for Chromium encrypted cookies

### Linux
- **Keyring access** for encrypted cookies
- **File permissions** for profiles

### Windows
- **DPAPI** for encrypted cookies

### iOS
- **App container** access
- **App Groups** entitlements for shared containers

### iOS Entitlements (App Groups)
Silo can only read WebKit/Safari cookies from the current app container or App Group containers you own. It cannot access system Safari cookies or other apps.
To read from a shared container:
- Enable App Groups in Xcode for all participating targets.
- Add `com.apple.security.application-groups` with the same group identifier(s).
- Pass the App Group container URL(s) to `BrowserCookieClient.Configuration(homeDirectories:)`.

```swift
let groupURL = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.example.cookies"
)
let client = BrowserCookieClient(
    configuration: .init(homeDirectories: [groupURL].compactMap { $0 })
)
```

## Security
Silo reads sensitive cookie data. Apply least privilege and avoid logging cookie values.
Use `BrowserCookieRecord.redactedValue` to safely log cookie data. For strict
decryption failures, set `BrowserCookieClient.Configuration(decryptionFailurePolicy: .strict)`.
On Linux, the insecure "peanuts" fallback is disabled by default. To enable it, set
`SILO_ALLOW_INSECURE_CHROMIUM_FALLBACK=1` (not recommended). For explicit keys, set
`SILO_CHROME_SAFE_STORAGE`. See `SECURITY.md`.

### Keyring Hardening
Linux hardening:
- Prefer `SILO_SECRET_TOOL_PATH` to pin the `secret-tool` location.
- `SILO_SECRET_TOOL_TIMEOUT_MS` limits keyring lookups (default 2000ms; set `0` to disable).
- Use `SILO_CHROME_SAFE_STORAGE` for explicit keys and only enable the peanuts fallback when you accept the risk.

Windows hardening:
- DPAPI decryption is non-interactive; run inside the target user session.
- AES-GCM cookies (`v10`/`v11`) require a readable `Local State` key file.

## Testing

```bash
swift test
```

Integration tests build real SQLite cookie stores on disk and validate:
- Chromium + Firefox readers (plain value parsing)
- Safari binarycookies parsing
- Chromium decryption paths (AES-GCM on macOS/Linux, AES-CBC on Linux, DPAPI-wrapped key on Windows)

## Publishing

### Git (Release Tags)
```bash
git tag v1.0.0
git push --tags
```

### NPM (Optional Metadata Wrapper)
```bash
npm publish --access public
```

Notes:
- The npm package is a lightweight metadata wrapper pointing to the Swift package.
- Update the version in `package.json` when tagging a new release.

## 📚 Documentation

```bash
swift package generate-documentation --target Silo
```

## 📚 API Reference

### BrowserCookieClient

```swift
public struct BrowserCookieClient {
    // Initialize
    public init(configuration: Configuration = Configuration())

    // Browser stores
    public func stores(for browser: Browser) -> [BrowserCookieStore]
    public func stores(in browsers: [Browser]) -> [BrowserCookieStore]

    // Query cookies
    public func records(matching query: BrowserCookieQuery, in store: BrowserCookieStore) throws -> [BrowserCookieRecord]
    public func records(matching query: BrowserCookieQuery, in browser: Browser) throws -> [BrowserCookieStoreRecords]
    public func records(matching query: BrowserCookieQuery, in browsers: [Browser]) throws -> [BrowserCookieStoreRecords]

    public func cookies(matching query: BrowserCookieQuery, in store: BrowserCookieStore) throws -> [HTTPCookie]
    public func cookies(matching query: BrowserCookieQuery, in browser: Browser) throws -> [HTTPCookie]
    public func cookies(matching query: BrowserCookieQuery, in browsers: [Browser]) throws -> [HTTPCookie]
}
```

### Configuration

```swift
public struct BrowserCookieClient.Configuration {
    public var homeDirectories: [URL]
    public var decryptionFailurePolicy: BrowserCookieDecryptionFailurePolicy
}

public enum BrowserCookieDecryptionFailurePolicy {
    case bestEffort
    case strict
}
```

### BrowserCookieQuery

```swift
public struct BrowserCookieQuery {
    public var domains: [String]
    public var domainMatch: BrowserCookieDomainMatch
    public var domainPattern: String?
    public var pathPattern: String?
    public var useRegex: Bool
    public var paths: [String]
    public var pathMatch: BrowserCookiePathMatch
    public var secureOnly: Bool?
    public var httpOnlyOnly: Bool?
    public var excludeSession: Bool
    public var minExpiryDate: Date?
    public var maxExpiryDate: Date?
    public var sameSite: BrowserCookieSameSite?
    public var origin: BrowserCookieOriginStrategy
    public var includeExpired: Bool
    public var referenceDate: Date
}
```

### BrowserCookieRecord

```swift
public struct BrowserCookieRecord {
    public var domain: String
    public var name: String
    public var path: String
    public var value: String
    public var expires: Date?
    public var createdAt: Date?
    public var lastAccessedAt: Date?
    public var isSecure: Bool
    public var isHTTPOnly: Bool
    public var sameSite: BrowserCookieSameSite?
    public var priority: BrowserCookiePriority?
    public var partitionKey: String?
    public var isSameParty: Bool?
    public var redactedValue: String
    public func redactedValue(prefix: Int, suffix: Int) -> String
}
```

Note: optional fields (e.g. `createdAt`, `priority`, `partitionKey`) depend on browser support and storage format.

### Field Availability (By Browser)

| Field | Chromium | Firefox | Safari/WebKit |
|------|----------|---------|---------------|
| `domain`, `name`, `path`, `value` | ✓ | ✓ | ✓ |
| `expires` | ✓ | ✓ | ✓ |
| `createdAt` | ✓ | ✓ | ✓ |
| `lastAccessedAt` | ✓ | ✓ | - |
| `priority` | ✓ | ✓ | - |
| `partitionKey` | ✓ | ✓ | - |
| `isSameParty` | ✓ | ✓ | - |
| `sameSite` | ✓ | ✓ | - |

### BrowserCookieExport

```swift
public struct BrowserCookieExport {
    public var schemaVersion: Int
    public var generatedAt: Date
    public var stores: [BrowserCookieStoreExport]
    public func jsonData(prettyPrinted: Bool = true) throws -> Data
}

public struct BrowserCookieStoreExport {
    public var browser: Browser
    public var profileId: String
    public var profileName: String
    public var kind: BrowserCookieStoreKind
    public var label: String
    public var records: [BrowserCookieExportRecord]
}
```

## See Also

[Helix](https://github.com/sriinnu/Helix) – Command-line parsing framework

## 📄 License

MIT License - Copyright (c) 2026 Srinivas Pendela

---

**GitHub:** https://github.com/sriinnu/Silo  
**Author:** Srinivas Pendela (hello@srinivas.dev)
