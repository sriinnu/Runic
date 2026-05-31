#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

extension TTYCommandRunner {
    final class PTYRunContext {
        let primaryFD: Int32
        let secondaryFD: Int32
        let primaryHandle: FileHandle
        let secondaryHandle: FileHandle
        let proc: Process
        var buffer = Data()

        private var cleanedUp = false
        private var didLaunch = false
        private var processGroup: pid_t?

        init(resolved: String, options: Options) throws {
            var primaryFD: Int32 = -1
            var secondaryFD: Int32 = -1
            var win = winsize(ws_row: options.rows, ws_col: options.cols, ws_xpixel: 0, ws_ypixel: 0)
            guard openpty(&primaryFD, &secondaryFD, nil, nil, &win) == 0 else {
                throw Error.launchFailed("openpty failed")
            }
            _ = fcntl(primaryFD, F_SETFL, O_NONBLOCK)

            self.primaryFD = primaryFD
            self.secondaryFD = secondaryFD
            self.primaryHandle = FileHandle(fileDescriptor: primaryFD, closeOnDealloc: true)
            self.secondaryHandle = FileHandle(fileDescriptor: secondaryFD, closeOnDealloc: true)
            self.proc = Process()

            self.configureProcess(resolved: resolved, options: options)
        }

        func launch() throws {
            try self.proc.run()
            self.didLaunch = true

            let pid = self.proc.processIdentifier
            if setpgid(pid, pid) == 0 {
                self.processGroup = pid
            }
        }

        func cleanup() {
            guard !self.cleanedUp else { return }
            self.cleanedUp = true

            if self.didLaunch, self.proc.isRunning {
                try? self.writeAllToPrimary(Data("/exit\n".utf8))
            }

            try? self.primaryHandle.close()
            try? self.secondaryHandle.close()
            guard self.didLaunch else { return }

            if self.proc.isRunning {
                self.proc.terminate()
            }
            if let pgid = self.processGroup {
                kill(-pgid, SIGTERM)
            }

            let waitDeadline = Date().addingTimeInterval(2.0)
            while self.proc.isRunning, Date() < waitDeadline {
                usleep(100_000)
            }
            if self.proc.isRunning {
                if let pgid = self.processGroup {
                    kill(-pgid, SIGKILL)
                }
                kill(self.proc.processIdentifier, SIGKILL)
            }
            self.proc.waitUntilExit()
        }

        func send(_ text: String) throws {
            guard let data = text.data(using: .utf8) else { return }
            try self.writeAllToPrimary(data)
        }

        func readChunk() -> Data {
            var appended = Data()
            while true {
                var tmp = [UInt8](repeating: 0, count: 8192)
                let n = read(self.primaryFD, &tmp, tmp.count)
                if n > 0 {
                    let slice = tmp.prefix(n)
                    self.buffer.append(contentsOf: slice)
                    appended.append(contentsOf: slice)
                    continue
                }
                break
            }
            return appended
        }

        func writeAllToPrimary(_ data: Data) throws {
            try data.withUnsafeBytes { rawBytes in
                guard let baseAddress = rawBytes.baseAddress else { return }
                var offset = 0
                var retries = 0
                while offset < rawBytes.count {
                    let written = write(self.primaryFD, baseAddress.advanced(by: offset), rawBytes.count - offset)
                    if written > 0 {
                        offset += written
                        retries = 0
                        continue
                    }
                    if written == 0 { break }

                    let err = errno
                    if err == EAGAIN || err == EWOULDBLOCK {
                        retries += 1
                        if retries > 200 {
                            throw Error.launchFailed("write to PTY would block")
                        }
                        usleep(5000)
                        continue
                    }
                    throw Error.launchFailed("write to PTY failed: \(String(cString: strerror(err)))")
                }
            }
        }

        private func configureProcess(resolved: String, options: Options) {
            let resolvedURL = URL(fileURLWithPath: resolved)
            if resolvedURL.lastPathComponent == "claude",
               let watchdog = TTYCommandRunner.locateBundledHelper("RunicClaudeWatchdog")
            {
                self.proc.executableURL = URL(fileURLWithPath: watchdog)
                self.proc.arguments = ["--", resolved] + options.extraArgs
            } else {
                self.proc.executableURL = resolvedURL
                self.proc.arguments = options.extraArgs
            }
            self.proc.standardInput = self.secondaryHandle
            self.proc.standardOutput = self.secondaryHandle
            self.proc.standardError = self.secondaryHandle

            var env = TTYCommandRunner.enrichedEnvironment()
            if let workingDirectory = options.workingDirectory {
                self.proc.currentDirectoryURL = workingDirectory
                env["PWD"] = workingDirectory.path
            }
            self.proc.environment = env
        }
    }
}
