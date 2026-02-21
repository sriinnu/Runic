import Foundation

#if os(Windows)

import WinSDK

/// Platform context implementation for Windows.
public struct WindowsPlatformContext: PlatformContext {

    /// Creates a new Windows platform context.
    public init() {}

    public var arguments: [String] {
        let argc = Int(CommandLine.argc)
        var result: [String] = []

        for i in 0..<argc {
            guard let arg = CommandLine.unsafeArgv[i] else { continue }
            if let str = String(validatingUTF8: arg) {
                result.append(str)
            }
        }

        return Array(result.dropFirst())
    }

    public func environmentVariable(_ name: String) -> String? {
        // Windows API uses UTF-16 and reports lengths including the null terminator.
        var wideName = Array(name.utf16)
        wideName.append(0)

        return wideName.withUnsafeBufferPointer { namePtr in
            let required = GetEnvironmentVariableW(namePtr.baseAddress, nil, 0)
            if required == 0 {
                let err = GetLastError()
                if err == ERROR_ENVVAR_NOT_FOUND {
                    return nil
                }
                // Variable exists but empty (or another non-not-found error).
                return ""
            }

            var buffer = UnsafeMutablePointer<UInt16>.allocate(capacity: Int(required))
            defer { buffer.deallocate() }

            var copied = GetEnvironmentVariableW(namePtr.baseAddress, buffer, required)
            if copied >= required {
                buffer.deallocate()
                buffer = UnsafeMutablePointer<UInt16>.allocate(capacity: Int(copied + 1))
                copied = GetEnvironmentVariableW(namePtr.baseAddress, buffer, copied + 1)
            }

            if copied == 0 {
                let err = GetLastError()
                if err == ERROR_ENVVAR_NOT_FOUND {
                    return nil
                }
                return ""
            }

            return String(decoding: UnsafeBufferPointer(start: buffer, count: Int(copied)), as: UTF16.self)
        }
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
        ExitProcess(UInt32(code))
    }

    public var currentWorkingDirectory: PlatformPath {
        let required = GetCurrentDirectoryW(0, nil)
        guard required > 0 else { return PlatformPath("") }

        let capacity = Int(required + 1)
        let buffer = UnsafeMutablePointer<UInt16>.allocate(capacity: capacity)
        defer { buffer.deallocate() }

        let copied = GetCurrentDirectoryW(UInt32(capacity), buffer)
        guard copied > 0 else { return PlatformPath("") }

        let path = String(decoding: UnsafeBufferPointer(start: buffer, count: Int(copied)), as: UTF16.self)
        return PlatformPath(path)
    }
}

#endif
