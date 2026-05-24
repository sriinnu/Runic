import Foundation

enum CostUsageJsonl {
    struct Line {
        let bytes: Data
        let wasTruncated: Bool
    }

    @discardableResult
    static func scan(
        fileURL: URL,
        offset: Int64 = 0,
        maxLineBytes: Int,
        prefixBytes: Int,
        onLine: (Line) -> Void) throws
        -> Int64
    {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        let startOffset = max(0, offset)
        if startOffset > 0 {
            try handle.seek(toOffset: UInt64(startOffset))
        }

        var current = Data()
        current.reserveCapacity(4 * 1024)
        var lineBytes = 0
        var truncated = false
        var bytesRead: Int64 = 0

        func flushLine() {
            guard lineBytes > 0 else { return }
            let line = Line(bytes: current, wasTruncated: truncated)
            onLine(line)
            current.removeAll(keepingCapacity: true)
            lineBytes = 0
            truncated = false
        }

        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: 256 * 1024) ?? Data()
            if chunk.isEmpty {
                flushLine()
                break
            }

            bytesRead += Int64(chunk.count)

            var cursor = chunk.startIndex
            while cursor < chunk.endIndex {
                if Task.isCancelled { throw CancellationError() }
                let newline = chunk[cursor...].firstIndex(of: 0x0A) ?? chunk.endIndex
                let linePart = chunk[cursor..<newline]

                lineBytes += linePart.count
                if !truncated {
                    if lineBytes > maxLineBytes || lineBytes > prefixBytes {
                        truncated = true
                        current.removeAll(keepingCapacity: true)
                    } else {
                        current.append(contentsOf: linePart)
                    }
                }

                if newline < chunk.endIndex {
                    flushLine()
                    cursor = chunk.index(after: newline)
                } else {
                    cursor = chunk.endIndex
                }
            }
        }

        return startOffset + bytesRead
    }
}
