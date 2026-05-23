import Foundation
import Testing
@testable import RunicCore

struct CostUsageJsonlTests {
    @Test
    func `scanner discards huge lines without dropping later rows`() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-jsonl-scan-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let file = root.appendingPathComponent("huge.jsonl")
        fm.createFile(atPath: file.path, contents: nil)
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }

        try handle.write(contentsOf: Data(#"{"ok":1}"#.utf8))
        try handle.write(contentsOf: Data([0x0A]))
        try handle.write(contentsOf: Data(repeating: 0x78, count: 512 * 1024))
        try handle.write(contentsOf: Data([0x0A]))
        try handle.write(contentsOf: Data(#"{"ok":2}"#.utf8))
        try handle.write(contentsOf: Data([0x0A]))

        var rows: [String] = []
        let endOffset = try CostUsageJsonl.scan(
            fileURL: file,
            maxLineBytes: 256 * 1024,
            prefixBytes: 32 * 1024)
        { line in
            guard !line.wasTruncated, let text = String(data: line.bytes, encoding: .utf8) else { return }
            rows.append(text)
        }

        let size = try fm.attributesOfItem(atPath: file.path)[.size] as? NSNumber
        #expect(endOffset == size?.int64Value)
        #expect(rows == [#"{"ok":1}"#, #"{"ok":2}"#])
    }
}
