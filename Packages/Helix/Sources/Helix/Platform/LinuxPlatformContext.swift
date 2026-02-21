import Foundation

#if os(Linux)

import Glibc

/// Platform context implementation for Linux.
public struct LinuxPlatformContext: PlatformContext {
    public init() {}

    public var arguments: [String] {
        Array(CommandLine.arguments.dropFirst())
    }

    public func environmentVariable(_ name: String) -> String? {
        guard let cString = getenv(name) else { return nil }
        return String(validatingCString: cString)
    }

    public var stdin: StdioStream { FileHandleStdioStream(.stdin) }
    public var stdout: StdioStream { FileHandleStdioStream(.stdout) }
    public var stderr: StdioStream { FileHandleStdioStream(.stderr) }

    public func exit(code: Int32) -> Never {
        Glibc.exit(code)
    }

    public var currentWorkingDirectory: PlatformPath {
        PlatformPath(FileManager.default.currentDirectoryPath)
    }
}

#endif

