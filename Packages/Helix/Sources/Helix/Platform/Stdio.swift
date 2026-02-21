import Foundation

// MARK: - Stdio Stream

/// Represents a standard I/O stream (stdin, stdout, stderr).
public protocol StdioStream: Sendable {
    /// Reads data from the stream.
    func read(upToCount count: Int) throws -> Data?

    /// Writes data to the stream.
    func write(_ data: Data) throws

    /// Flushes any buffered output.
    func flush() throws
}

// MARK: - File Handle Stream

/// A StdioStream backed by a FileHandle.
public struct FileHandleStdioStream: StdioStream {
    public enum StreamType {
        case stdin
        case stdout
        case stderr
    }

    private let fileHandle: FileHandle

    public init(_ type: StreamType) {
        switch type {
        case .stdin:
            self.fileHandle = FileHandle.standardInput
        case .stdout:
            self.fileHandle = FileHandle.standardOutput
        case .stderr:
            self.fileHandle = FileHandle.standardError
        }
    }

    public func read(upToCount count: Int) throws -> Data? {
        fileHandle.readData(ofLength: count)
    }

    public func write(_ data: Data) throws {
        try fileHandle.write(contentsOf: data)
    }

    public func flush() throws {
        fileHandle.synchronizeFile()
    }
}

// MARK: - Buffer Stream

/// An in-memory stream for testing or capturing output.
public final class BufferStdioStream: @unchecked Sendable, StdioStream {
    private let lock = NSLock()
    private var buffer: Data
    private var inputBuffer: Data
    private var inputIndex: Int = 0

    public init(input: Data = Data()) {
        self.buffer = Data()
        self.inputBuffer = input
    }

    public var output: Data {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    public var outputString: String? {
        lock.lock()
        defer { lock.unlock() }
        return String(data: buffer, encoding: .utf8)
    }

    public func read(upToCount count: Int) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        let remaining = inputBuffer.count - inputIndex
        guard remaining > 0 else { return nil }
        let toRead = min(count, remaining)
        let slice = inputBuffer.subdata(in: inputIndex..<(inputIndex + toRead))
        inputIndex += toRead
        return slice
    }

    public func write(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(data)
    }

    public func flush() throws {
        // No-op for buffer
    }
}
