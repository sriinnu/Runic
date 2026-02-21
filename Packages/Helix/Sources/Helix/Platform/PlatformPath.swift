import Foundation

/// Represents a file system path in a cross-platform manner.
public struct PlatformPath: Sendable, ExpressibleFromArgument {
    private let path: String

    /// Creates a path from a string.
    public init(_ path: String) {
        self.path = Self.normalize(path)
    }

    /// Creates a path from a string argument.
    public init?(argument: String) {
        self.init(argument)
    }

    // MARK: - Normalization

    private static func normalize(_ path: String) -> String {
        #if os(Windows)
        // Windows accepts both forward and backslashes, normalize to backslashes
        return path.replacingOccurrences(of: "/", with: "\\")
        #else
        return path
        #endif
    }

    // MARK: - Properties

    /// Whether the path is absolute.
    public var isAbsolute: Bool {
        #if os(Windows)
        if path.hasPrefix("\\") {
            return true
        }
        // Check for drive letter (e.g., C:)
        if path.count >= 2 {
            let secondChar = path[path.index(after: path.startIndex)]
            return secondChar == ":"
        }
        return false
        #else
        return path.hasPrefix("/")
        #endif
    }

    /// The last component of the path.
    public var lastComponent: String {
        #if os(Windows)
        let parts = path.split(separator: "\\", omittingEmptySubsequences: false)
        return parts.last.map(String.init) ?? path
        #else
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.last.map(String.init) ?? path
        #endif
    }

    /// The file extension.
    public var `extension`: String? {
        let components = lastComponent.split(separator: ".")
        guard components.count > 1 else { return nil }
        return String(components.last!)
    }

    /// The path without the final extension.
    public var deletingExtension: PlatformPath {
        guard let ext = self.extension else { return self }
        let withoutExt = lastComponent.dropLast(ext.count + 1)
        return PlatformPath(path.dropLast(withoutExt.count + ext.count + 1) + String(withoutExt))
    }

    // MARK: - Path Operations

    /// Appends a component to the path.
    public func appending(_ component: String) -> PlatformPath {
        let separator: String
        #if os(Windows)
        separator = "\\"
        #else
        separator = "/"
        #endif

        var result = path
        if !result.isEmpty && !result.hasSuffix(separator) {
            result += separator
        }
        return PlatformPath(result + component)
    }

    /// Resolves the path to an absolute path.
    public func resolvingRelativeTo(_ base: PlatformPath) -> PlatformPath {
        if isAbsolute {
            return self
        }
        return base.appending(path)
    }

    // MARK: - String Conversion

    public var string: String {
        path
    }

    public var description: String {
        path
    }
}

// MARK: - Path Joining

public extension PlatformPath {
    /// Joins multiple path components.
    static func joining(_ components: String...) -> PlatformPath {
        components.reduce(PlatformPath("")) { $0.appending($1) }
    }
}

// MARK: - Environment Variable Expansion

extension PlatformPath {
    /// Expands environment variables in the path.
    /// - Parameter environment: A dictionary of environment variables.
    /// - Returns: A new path with variables expanded.
    public func expandingEnvironmentVariables(_ environment: [String: String]) -> PlatformPath {
        var result = path
        for (key, value) in environment {
            let variable = "$" + key
            result = result.replacingOccurrences(of: variable, with: value)
            #if os(Windows)
            let windowsVariable = "%" + key + "%"
            result = result.replacingOccurrences(of: windowsVariable, with: value)
            #endif
        }
        return PlatformPath(result)
    }

    /// Expands the home directory (~) in the path.
    /// - Parameter homeDirectory: The home directory path.
    /// - Returns: A new path with ~ expanded.
    public func expandingHomeDirectory(_ homeDirectory: PlatformPath) -> PlatformPath {
        guard path.hasPrefix("~") else { return self }
        return homeDirectory.appending(String(path.dropFirst()))
    }
}

// MARK: - Platform-Specific Home Directory

extension PlatformPath {
    /// The user's home directory.
    public static var homeDirectory: PlatformPath {
        #if os(Windows)
        if let home = DefaultPlatformContext.shared.environmentVariable("USERPROFILE") {
            return PlatformPath(home)
        }
        if let home = DefaultPlatformContext.shared.environmentVariable("HOMEPATH") {
            let drive = DefaultPlatformContext.shared.environmentVariable("HOMEDRIVE") ?? ""
            return PlatformPath(drive + home)
        }
        return PlatformPath("")
        #else
        if let home = DefaultPlatformContext.shared.environmentVariable("HOME") {
            return PlatformPath(home)
        }
        return PlatformPath("")
        #endif
    }
}
