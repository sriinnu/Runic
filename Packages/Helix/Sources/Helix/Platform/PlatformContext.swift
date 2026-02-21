import Foundation

#if os(Windows)
import WinSDK
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// MARK: - Platform Context Protocol

/// Defines the interface for platform-specific operations.
/// This protocol abstracts platform differences to enable cross-platform support.
public protocol PlatformContext: Sendable {

    /// The command-line arguments passed to the program.
    var arguments: [String] { get }

    /// Retrieves the value of an environment variable.
    /// - Parameter name: The name of the environment variable.
    /// - Returns: The value of the variable, or `nil` if not found.
    func environmentVariable(_ name: String) -> String?

    /// The standard input stream.
    var stdin: StdioStream { get }

    /// The standard output stream.
    var stdout: StdioStream { get }

    /// The standard error stream.
    var stderr: StdioStream { get }

    /// Terminates the program with the given exit code.
    /// - Parameter code: The exit code to return.
    func exit(code: Int32) -> Never

    /// The current working directory.
    var currentWorkingDirectory: PlatformPath { get }
}

// MARK: - PlatformContext Error

extension PlatformContext {
    /// Retrieves an environment variable, throwing if not found.
    /// - Parameter name: The name of the environment variable.
    /// - Returns: The value of the variable.
    /// - Throws: `HelixError.missingEnvironmentVariable` if the variable is not set.
    public func requireEnvironmentVariable(_ name: String) throws -> String {
        guard let value = environmentVariable(name) else {
            throw HelixError.missingEnvironmentVariable(name)
        }
        return value
    }
}

// MARK: - Convenience Properties

extension PlatformContext {
    /// All environment variables as a dictionary.
    public var environment: [String: String] {
        var result: [String: String] = [:]
        #if os(Windows)
        guard let envBlock = GetEnvironmentStringsW() else { return result }
        defer { FreeEnvironmentStringsW(envBlock) }
        var current = envBlock
        while current.pointee != 0 {
            let length = Int(wcslen(current))
            let entry = String(decoding: UnsafeBufferPointer(start: current, count: length), as: UTF16.self)
            let parts = entry.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                result[String(parts[0])] = String(parts[1])
            }
            current = current.advanced(by: length + 1)
        }
        #else
        var current = environ
        while let entry = current.pointee {
            if let str = String(validatingCString: entry) {
                let parts = str.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    result[String(parts[0])] = String(parts[1])
                }
            }
            current = current.advanced(by: 1)
        }
        #endif
        return result
    }
}
