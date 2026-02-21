import Foundation

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)

import Darwin.C.stdlib

/// Platform context implementation for Apple platforms (Darwin).
public struct DarwinPlatformContext: PlatformContext {

    /// Creates a new Darwin platform context.
    public init() {}

    public var arguments: [String] {
        Array(CommandLine.arguments.dropFirst())
    }

    public func environmentVariable(_ name: String) -> String? {
        guard let cString = getenv(name) else { return nil }
        return String(validatingCString: cString)
    }

    public var stdin: StdioStream {
        FileHandleStdioStream(.stdin)
    }

    public var stdout: StdioStream {
        FileHandleStdioStream(.stdout)
    }

    public var stderr: StdioStream {
        FileHandleStdioStream(.stderr)
    }

    public func exit(code: Int32) -> Never {
        Darwin.exit(code)
    }

    public var currentWorkingDirectory: PlatformPath {
        let cwd = FileManager.default.currentDirectoryPath
        return PlatformPath(cwd)
    }
}

#endif
