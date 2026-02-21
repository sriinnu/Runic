import Foundation

// MARK: - Sync Conflict Resolver

/// Default implementation of conflict resolution for synchronized records
///
/// This resolver implements multiple conflict resolution strategies:
/// - Last-write-wins (default): Most recently modified record wins
/// - Prefer local: Always keep local version
/// - Prefer remote: Always keep remote version
/// - Highest version: Keep record with highest version number
/// - Merge: Attempt to merge both versions (custom logic required)
public actor SyncConflictResolver: SyncConflictResolverProtocol {

    // MARK: - Properties

    /// Statistics about resolved conflicts
    public private(set) var conflictStats: ConflictStatistics

    /// Custom merge handlers for specific record types
    private var mergeHandlers: [String: MergeHandler] = [:]

    // MARK: - Initialization

    public init() {
        self.conflictStats = ConflictStatistics()
    }

    // MARK: - Public Methods

    /// Resolves a conflict between local and remote versions
    ///
    /// - Parameters:
    ///   - local: The local version of the record
    ///   - remote: The remote version of the record
    ///   - strategy: The resolution strategy to apply
    /// - Returns: The resolved record that should be kept
    public func resolve(
        local: SyncableRecord,
        remote: SyncableRecord,
        strategy: ConflictResolutionStrategy
    ) async -> SyncableRecord {
        // Validate that records are the same type
        guard local.recordID == remote.recordID else {
            return local // Fallback to local if IDs don't match
        }

        let resolved: SyncableRecord

        switch strategy {
        case .lastWriteWins:
            resolved = resolveLastWriteWins(local: local, remote: remote)

        case .preferLocal:
            resolved = local

        case .preferRemote:
            resolved = remote

        case .highestVersion:
            resolved = resolveHighestVersion(local: local, remote: remote)

        case .merge:
            resolved = resolveMerge(local: local, remote: remote)
        }

        // Update statistics
        conflictStats.recordConflict(
            recordType: local.recordType,
            strategy: strategy,
            winner: resolved.recordID == local.recordID ? .local : .remote
        )

        return resolved
    }

    /// Registers a custom merge handler for a specific record type
    ///
    /// - Parameters:
    ///   - recordType: The CloudKit record type name
    ///   - handler: Closure that merges two records of this type
    public func registerMergeHandler(
        for recordType: String,
        handler: @escaping MergeHandler
    ) {
        mergeHandlers[recordType] = handler
    }

    /// Resets conflict statistics
    public func resetStatistics() {
        conflictStats = ConflictStatistics()
    }

    // MARK: - Private Resolution Methods

    /// Resolves conflict by keeping the most recently modified record
    private func resolveLastWriteWins(
        local: SyncableRecord,
        remote: SyncableRecord
    ) -> SyncableRecord {
        if local.modifiedAt > remote.modifiedAt {
            return local
        } else if remote.modifiedAt > local.modifiedAt {
            return remote
        } else {
            // Same timestamp, use version as tiebreaker
            return local.version >= remote.version ? local : remote
        }
    }

    /// Resolves conflict by keeping the record with highest version number
    private func resolveHighestVersion(
        local: SyncableRecord,
        remote: SyncableRecord
    ) -> SyncableRecord {
        if local.version > remote.version {
            return local
        } else if remote.version > local.version {
            return remote
        } else {
            // Same version, use timestamp as tiebreaker
            return local.modifiedAt >= remote.modifiedAt ? local : remote
        }
    }

    /// Attempts to merge both versions using custom merge logic
    private func resolveMerge(
        local: SyncableRecord,
        remote: SyncableRecord
    ) -> SyncableRecord {
        // Check for registered merge handler
        if let handler = mergeHandlers[local.recordType] {
            return handler(local, remote)
        }

        // No custom merge handler, fall back to last-write-wins
        return resolveLastWriteWins(local: local, remote: remote)
    }
}

// MARK: - Supporting Types

/// Closure type for custom merge handlers
public typealias MergeHandler = @Sendable (SyncableRecord, SyncableRecord) -> SyncableRecord

/// Indicates which version won during conflict resolution
public enum ConflictWinner: String, Codable, Sendable {
    case local
    case remote
}

/// Statistics about conflict resolution operations
public struct ConflictStatistics: Sendable {
    /// Total number of conflicts resolved
    public private(set) var totalConflicts: Int = 0

    /// Number of conflicts per record type
    public private(set) var conflictsByType: [String: Int] = [:]

    /// Number of conflicts per strategy
    public private(set) var conflictsByStrategy: [String: Int] = [:]

    /// Number of wins for local vs remote
    public private(set) var localWins: Int = 0
    public private(set) var remoteWins: Int = 0

    /// Timestamp of last conflict
    public private(set) var lastConflictAt: Date?

    public init() {}

    /// Records a conflict resolution event
    mutating func recordConflict(
        recordType: String,
        strategy: ConflictResolutionStrategy,
        winner: ConflictWinner
    ) {
        totalConflicts += 1
        conflictsByType[recordType, default: 0] += 1
        conflictsByStrategy[strategy.rawValue, default: 0] += 1

        switch winner {
        case .local:
            localWins += 1
        case .remote:
            remoteWins += 1
        }

        lastConflictAt = Date()
    }

    /// Percentage of conflicts won by local version
    public var localWinRate: Double {
        guard totalConflicts > 0 else { return 0 }
        return Double(localWins) / Double(totalConflicts)
    }

    /// Percentage of conflicts won by remote version
    public var remoteWinRate: Double {
        guard totalConflicts > 0 else { return 0 }
        return Double(remoteWins) / Double(totalConflicts)
    }

    /// Human-readable summary of conflict statistics
    public var summary: String {
        var lines = [
            "Conflict Resolution Statistics:",
            "  Total conflicts: \(totalConflicts)",
            "  Local wins: \(localWins) (\(String(format: "%.1f%%", localWinRate * 100)))",
            "  Remote wins: \(remoteWins) (\(String(format: "%.1f%%", remoteWinRate * 100)))"
        ]

        if !conflictsByType.isEmpty {
            lines.append("  By record type:")
            for (type, count) in conflictsByType.sorted(by: { $0.value > $1.value }) {
                lines.append("    \(type): \(count)")
            }
        }

        if !conflictsByStrategy.isEmpty {
            lines.append("  By strategy:")
            for (strategy, count) in conflictsByStrategy.sorted(by: { $0.value > $1.value }) {
                lines.append("    \(strategy): \(count)")
            }
        }

        if let lastConflict = lastConflictAt {
            let formatter = RelativeDateTimeFormatter()
            let timeAgo = formatter.localizedString(for: lastConflict, relativeTo: Date())
            lines.append("  Last conflict: \(timeAgo)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Default Merge Handlers

extension SyncConflictResolver {
    /// Registers default merge handlers for Runic record types
    public func registerDefaultMergeHandlers() {
        // Usage Snapshot merge: prefer record with most recent data
        registerMergeHandler(for: CloudKitRecordType.usageSnapshot) { local, remote in
            guard let localUsage = local as? UsageSnapshotSyncRecord,
                  let remoteUsage = remote as? UsageSnapshotSyncRecord else {
                return local
            }

            // Prefer the record with more recent usage data
            return localUsage.updatedAt > remoteUsage.updatedAt ? local : remote
        }

        // User Preferences merge: combine enabled providers
        registerMergeHandler(for: CloudKitRecordType.userPreferences) { local, remote in
            guard let localPrefs = local as? UserPreferencesSyncRecord,
                  let remotePrefs = remote as? UserPreferencesSyncRecord else {
                return local
            }

            // Merge enabled providers (union of both sets)
            let mergedProviders = Array(Set(localPrefs.enabledProviders + remotePrefs.enabledProviders))

            // Use most recent settings for other fields
            let source = localPrefs.modifiedAt > remotePrefs.modifiedAt ? localPrefs : remotePrefs

            return UserPreferencesSyncRecord(
                recordID: localPrefs.recordID,
                version: max(localPrefs.version, remotePrefs.version) + 1,
                modifiedAt: Date(),
                lastModifiedDeviceID: source.lastModifiedDeviceID,
                refreshInterval: source.refreshInterval,
                enabledProviders: mergedProviders,
                notificationsEnabled: source.notificationsEnabled,
                autoRefreshEnabled: source.autoRefreshEnabled,
                theme: source.theme,
                displayFormat: source.displayFormat
            )
        }

        // Alert Configuration merge: prefer most restrictive thresholds
        registerMergeHandler(for: CloudKitRecordType.alertConfiguration) { local, remote in
            guard let localAlert = local as? AlertConfigurationSyncRecord,
                  let remoteAlert = remote as? AlertConfigurationSyncRecord else {
                return local
            }

            // Use lower (more conservative) thresholds
            let warningThreshold = min(localAlert.warningThreshold, remoteAlert.warningThreshold)
            let criticalThreshold = min(localAlert.criticalThreshold, remoteAlert.criticalThreshold)

            // Merge notification channels (union)
            let mergedChannels = Array(Set(localAlert.notificationChannels + remoteAlert.notificationChannels))

            // Enabled if either version has it enabled
            let enabled = localAlert.enabled || remoteAlert.enabled

            return AlertConfigurationSyncRecord(
                recordID: localAlert.recordID,
                version: max(localAlert.version, remoteAlert.version) + 1,
                modifiedAt: Date(),
                lastModifiedDeviceID: localAlert.lastModifiedDeviceID,
                providerID: localAlert.providerID,
                warningThreshold: warningThreshold,
                criticalThreshold: criticalThreshold,
                notificationChannels: mergedChannels,
                enabled: enabled
            )
        }
    }
}
