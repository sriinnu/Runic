import Foundation

#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

extension PlatformContext {
    /// The current platform context based on the runtime platform.
    /// Uses compile-time platform detection to select the appropriate implementation.
    public static var current: any PlatformContext {
        DefaultPlatformContext.shared
    }
}

// MARK: - Default Platform Context

/// Internal default platform context that selects the appropriate implementation.
/// Thread-safe singleton using static let (lazy + thread-safe in Swift).
public struct DefaultPlatformContext: PlatformContext {
    public static let shared: DefaultPlatformContext = {
        // Static let is already thread-safe in Swift (guaranteed by the language)
        DefaultPlatformContext()
    }()

    private let context: any PlatformContext

    public init() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        self.context = DarwinPlatformContext()
        #elseif os(Linux)
        self.context = LinuxPlatformContext()
        #elseif os(Windows)
        self.context = WindowsPlatformContext()
        #elseif os(WASI)
        self.context = WebPlatformContext()
        #else
        // Fallback for unknown platforms
        self.context = FallbackPlatformContext()
        #endif
    }

    public var arguments: [String] { context.arguments }
    public func environmentVariable(_ name: String) -> String? { context.environmentVariable(name) }
    public var stdin: StdioStream { context.stdin }
    public var stdout: StdioStream { context.stdout }
    public var stderr: StdioStream { context.stderr }
    public func exit(code: Int32) -> Never { context.exit(code: code) }
    public var currentWorkingDirectory: PlatformPath { context.currentWorkingDirectory }
}

// MARK: - Fallback Platform Context

/// Fallback platform context for unknown platforms.
struct FallbackPlatformContext: PlatformContext {
    var arguments: [String] = []
    var stdin: StdioStream = FileHandleStdioStream(.stdin)
    var stdout: StdioStream = FileHandleStdioStream(.stdout)
    var stderr: StdioStream = FileHandleStdioStream(.stderr)

    func environmentVariable(_ name: String) -> String? {
        #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
        let value = getenv(name)
        return value.flatMap { String(validatingCString: $0) }
        #else
        return nil
        #endif
    }

    func exit(code: Int32) -> Never {
        #if canImport(Darwin)
        Darwin.exit(code)
        #elseif canImport(Glibc)
        Glibc.exit(code)
        #elseif canImport(Musl)
        Musl.exit(code)
        #else
        // Intentionally trap on platforms without a usable exit().
        preconditionFailure("exit(code:) is not supported on this platform")
        #endif
    }

    var currentWorkingDirectory: PlatformPath {
        #if canImport(Foundation)
        return PlatformPath(FileManager.default.currentDirectoryPath)
        #else
        return PlatformPath("")
        #endif
    }
}
