import CloudKit
import Foundation

// MARK: - Sync Protocol Definitions

/// Protocol defining the core synchronization engine interface
///
/// This protocol abstracts the synchronization logic to allow for different
/// implementations (CloudKit, custom server, etc.) while maintaining a
/// consistent API for syncing data across devices.
public protocol SyncEngine: Sendable {
    /// Synchronizes local data with remote storage
    ///
    /// - Parameter options: Configuration options for this sync operation
    /// - Returns: Result indicating success or failure with error details
    func sync(options: SyncOptions) async -> Result<SyncResult, SyncError>

    /// Pushes local changes to remote storage
    ///
    /// - Parameter records: Array of records to push
    /// - Returns: Result containing pushed record identifiers or error
    func push(records: [SyncableRecord]) async -> Result<[String], SyncError>

    /// Fetches changes from remote storage
    ///
    /// - Parameter recordTypes: Array of record type names to fetch
    /// - Returns: Result containing fetched records or error
    func fetch(recordTypes: [String]) async -> Result<[SyncableRecord], SyncError>

    /// Deletes records from remote storage
    ///
    /// - Parameter recordIDs: Array of record identifiers to delete
    /// - Returns: Result containing deleted record identifiers or error
    func delete(recordIDs: [String]) async -> Result<[String], SyncError>

    /// Resets sync state and clears all remote data
    ///
    /// - Warning: This operation is destructive and cannot be undone
    /// - Returns: Result indicating success or failure
    func resetSync() async -> Result<Void, SyncError>
}

// MARK: - Syncable Record Protocol

/// Protocol for objects that can be synchronized across devices
///
/// Conform to this protocol to enable CloudKit synchronization for your data types.
public protocol SyncableRecord: Sendable, Codable {
    /// Unique identifier for the record
    var recordID: String { get }

    /// Type name used for CloudKit record type
    var recordType: String { get }

    /// Version number for conflict resolution
    var version: Int { get }

    /// Last modification timestamp
    var modifiedAt: Date { get }

    /// Device identifier that last modified this record
    var lastModifiedDeviceID: String? { get }

    /// Converts the record to a CloudKit CKRecord
    ///
    /// - Returns: CloudKit record representation
    func toCKRecord() throws -> CKRecord

    /// Creates a record from a CloudKit CKRecord
    ///
    /// - Parameter ckRecord: CloudKit record to convert
    /// - Returns: Initialized syncable record
    static func fromCKRecord(_ ckRecord: CKRecord) throws -> Self
}

// MARK: - Sync Conflict Resolver Protocol

/// Protocol for resolving conflicts when multiple devices modify the same record
///
/// Implement this protocol to define custom conflict resolution strategies
/// beyond the default last-write-wins behavior.
public protocol SyncConflictResolverProtocol: Sendable {
    /// Resolves a conflict between local and remote versions of a record
    ///
    /// - Parameters:
    ///   - local: The local version of the conflicting record
    ///   - remote: The remote version of the conflicting record
    ///   - strategy: The conflict resolution strategy to apply
    /// - Returns: The resolved record that should be kept
    func resolve(
        local: SyncableRecord,
        remote: SyncableRecord,
        strategy: ConflictResolutionStrategy) async -> SyncableRecord
}

// MARK: - Sync Observer Protocol

/// Protocol for observing synchronization events
///
/// Implement this protocol to receive notifications about sync state changes,
/// progress updates, and completion events.
public protocol SyncObserver: AnyObject, Sendable {
    /// Called when synchronization begins
    func syncDidStart()

    /// Called when synchronization progress updates
    ///
    /// - Parameters:
    ///   - current: Number of records processed
    ///   - total: Total number of records to process
    func syncDidProgress(current: Int, total: Int)

    /// Called when synchronization completes successfully
    ///
    /// - Parameter result: The sync result containing statistics
    func syncDidComplete(result: SyncResult)

    /// Called when synchronization fails
    ///
    /// - Parameter error: The error that caused the failure
    func syncDidFail(error: SyncError)
}

// MARK: - Supporting Types

/// Configuration options for sync operations
public struct SyncOptions: Sendable {
    /// Whether to force a full sync, ignoring change tracking
    public let forceFullSync: Bool

    /// Maximum number of records to sync in a single batch
    public let batchSize: Int

    /// Conflict resolution strategy to use
    public let conflictStrategy: ConflictResolutionStrategy

    /// Whether to sync in background mode
    public let backgroundMode: Bool

    /// Timeout interval for sync operations
    public let timeout: TimeInterval

    /// Whether to encrypt sensitive data
    public let encryptSensitiveData: Bool

    public init(
        forceFullSync: Bool = false,
        batchSize: Int = 100,
        conflictStrategy: ConflictResolutionStrategy = .lastWriteWins,
        backgroundMode: Bool = false,
        timeout: TimeInterval = 60.0,
        encryptSensitiveData: Bool = true)
    {
        self.forceFullSync = forceFullSync
        self.batchSize = batchSize
        self.conflictStrategy = conflictStrategy
        self.backgroundMode = backgroundMode
        self.timeout = timeout
        self.encryptSensitiveData = encryptSensitiveData
    }
}

/// Result of a sync operation with statistics
public struct SyncResult: Sendable {
    /// Number of records successfully pushed
    public let pushedCount: Int

    /// Number of records successfully fetched
    public let fetchedCount: Int

    /// Number of conflicts resolved
    public let conflictsResolved: Int

    /// Number of records deleted
    public let deletedCount: Int

    /// Timestamp when sync completed
    public let completedAt: Date

    /// Duration of the sync operation
    public let duration: TimeInterval

    /// Any non-fatal warnings encountered
    public let warnings: [String]

    public init(
        pushedCount: Int = 0,
        fetchedCount: Int = 0,
        conflictsResolved: Int = 0,
        deletedCount: Int = 0,
        completedAt: Date = Date(),
        duration: TimeInterval = 0,
        warnings: [String] = [])
    {
        self.pushedCount = pushedCount
        self.fetchedCount = fetchedCount
        self.conflictsResolved = conflictsResolved
        self.deletedCount = deletedCount
        self.completedAt = completedAt
        self.duration = duration
        self.warnings = warnings
    }
}

/// Conflict resolution strategies
public enum ConflictResolutionStrategy: String, Codable, Sendable {
    /// Keep the most recently modified record (default)
    case lastWriteWins

    /// Keep the local version
    case preferLocal

    /// Keep the remote version
    case preferRemote

    /// Keep the version with higher version number
    case highestVersion

    /// Merge both versions (requires custom merge logic)
    case merge
}

/// Errors that can occur during synchronization
public enum SyncError: Error, Sendable {
    /// iCloud account is not available
    case iCloudAccountUnavailable

    /// Network connection is not available
    case networkUnavailable

    /// CloudKit quota exceeded
    case quotaExceeded

    /// Record format is invalid
    case invalidRecordFormat(String)

    /// Sync operation timed out
    case timeout

    /// Authentication failed
    case authenticationFailed

    /// Conflict could not be resolved
    case conflictResolutionFailed(String)

    /// Generic CloudKit error
    case cloudKitError(Error)

    /// Encryption/decryption failed
    case encryptionFailed(String)

    /// Unknown error occurred
    case unknown(Error)

    public var localizedDescription: String {
        switch self {
        case .iCloudAccountUnavailable:
            "iCloud account is not available. Please sign in to iCloud in Settings."
        case .networkUnavailable:
            "Network connection is not available. Sync will retry when online."
        case .quotaExceeded:
            "iCloud storage quota exceeded. Please free up space or upgrade your plan."
        case let .invalidRecordFormat(details):
            "Invalid record format: \(details)"
        case .timeout:
            "Sync operation timed out. Please try again."
        case .authenticationFailed:
            "Authentication failed. Please sign in again."
        case let .conflictResolutionFailed(details):
            "Failed to resolve conflict: \(details)"
        case let .cloudKitError(error):
            "CloudKit error: \(error.localizedDescription)"
        case let .encryptionFailed(details):
            "Encryption failed: \(details)"
        case let .unknown(error):
            "Unknown error: \(error.localizedDescription)"
        }
    }
}

/// Priority levels for sync operations
public enum SyncPriority: Int, Sendable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}
