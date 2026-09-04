import Foundation
import RunicCore

/// Watches `~/Library/Application Support/Runic/` for changes to `config.json` and
/// delivers freshly loaded configs on the main actor.
///
/// The containing *directory* is watched (not the file) so atomic-replace writes —
/// which swap the inode — don't drop the watch. Events are debounced ~300ms, then
/// the config is reloaded and compared against the last-seen value before the
/// callback fires.
@MainActor
final class ConfigFileWatcher {
    private static let log = RunicLog.logger("config-watcher")
    private static let debounceNanoseconds: UInt64 = 300_000_000
    private static let rearmDelayNanoseconds: UInt64 = 1_000_000_000

    private let onChange: @MainActor (RunicConfig) -> Void
    private let eventQueue = DispatchQueue(label: "runic.config-file-watcher")
    private var source: DispatchSourceFileSystemObject?
    private var debounceTask: Task<Void, Never>?
    private var lastConfig: RunicConfig
    private var isRunning = false

    init(onChange: @escaping @MainActor (RunicConfig) -> Void) {
        self.onChange = onChange
        self.lastConfig = RunicConfigStore.load()
    }

    deinit {
        self.debounceTask?.cancel()
        self.source?.cancel()
    }

    // MARK: - Lifecycle

    /// Start watching. Refreshes the baseline config so edits made before `start()`
    /// are picked up by the first event.
    func start() {
        guard !self.isRunning else { return }
        self.isRunning = true
        self.lastConfig = RunicConfigStore.load()
        Self.log.info("Watching \(RunicConfigStore.storageURL.deletingLastPathComponent().path) for config changes.")
        self.armSource()
    }

    func stop() {
        guard self.isRunning else { return }
        self.isRunning = false
        self.debounceTask?.cancel()
        self.debounceTask = nil
        self.source?.cancel()
        self.source = nil
        Self.log.info("Stopped watching config file.")
    }

    /// Load the current config and fire the callback immediately, regardless of
    /// whether anything changed. For a manual "Reload" action.
    func reloadNow() {
        self.debounceTask?.cancel()
        self.debounceTask = nil
        let config = RunicConfigStore.load()
        self.lastConfig = config
        self.onChange(config)
    }

    // MARK: - Watch Source

    private func armSource() {
        self.source?.cancel()
        self.source = nil

        let dirURL = RunicConfigStore.storageURL.deletingLastPathComponent()
        let fd = open(dirURL.path, O_EVTONLY)
        guard fd >= 0 else {
            Self.log.error(
                "Failed to open config directory for watching (\(String(cString: strerror(errno)))); retrying shortly.")
            self.scheduleRearm()
            return
        }

        let newSource = Self.makeSource(fileDescriptor: fd, queue: self.eventQueue) { [weak self] rawEvents in
            Task { @MainActor [weak self] in
                self?.handleFileSystemEvents(DispatchSource.FileSystemEvent(rawValue: rawEvents))
            }
        }
        self.source = newSource
        newSource.resume()
    }

    /// Builds the dispatch source outside main-actor isolation. Closures written
    /// inside a `@MainActor` method inherit that isolation, and libdispatch invokes
    /// the event/cancel handlers on `queue` — the runtime isolation check then
    /// traps (SIGTRAP in `dispatch_assert_queue`). Keeping the handlers here makes
    /// them plain nonisolated closures that hop to the main actor explicitly.
    ///
    /// .rename/.delete on the directory mean the watched path vanished (or was
    /// swapped) — the source can never fire again, so the caller re-arms it.
    /// .write covers atomic-replace of config.json inside the directory.
    ///
    /// Events cross the isolation boundary as their raw `UInt` mask because
    /// `DispatchSource.FileSystemEvent` isn't `Sendable`.
    private nonisolated static func makeSource(
        fileDescriptor fd: Int32,
        queue: DispatchQueue,
        onEvents: @escaping @Sendable (UInt) -> Void) -> DispatchSourceFileSystemObject
    {
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: queue)
        source.setCancelHandler { close(fd) }
        source.setEventHandler { [weak source] in
            onEvents(source?.data.rawValue ?? 0)
        }
        return source
    }

    private func scheduleRearm() {
        guard self.isRunning else { return }
        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.rearmDelayNanoseconds)
            } catch {
                return
            }
            guard self.isRunning, self.source == nil else { return }
            self.armSource()
        }
    }

    // MARK: - Event Handling

    private func handleFileSystemEvents(_ events: DispatchSource.FileSystemEvent) {
        guard self.isRunning else { return }
        if events.contains(.rename) || events.contains(.delete) {
            Self.log.info("Config directory changed; re-arming watcher.")
            self.armSource()
        }
        self.scheduleReload()
    }

    private func scheduleReload() {
        self.debounceTask?.cancel()
        self.debounceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let config = await Task.detached(priority: .utility) { RunicConfigStore.load() }.value
            guard !Task.isCancelled, config != self.lastConfig else { return }
            self.lastConfig = config
            Self.log.info("Config file changed (\(config.activeOverrideCount) override(s)); applying.")
            self.onChange(config)
        }
    }
}
