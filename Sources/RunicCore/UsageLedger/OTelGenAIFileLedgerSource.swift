import Foundation

public struct OTelGenAIFileLedgerSource: UsageLedgerSource {
    public let files: [URL]
    public let options: OTelGenAIIngestionOptions
    public let minTimestamp: Date?
    private static let maxWholeJSONBytes = 8 * 1024 * 1024

    public init(
        files: [URL],
        options: OTelGenAIIngestionOptions = .disabled,
        minTimestamp: Date? = nil)
    {
        self.files = files
        self.options = options
        self.minTimestamp = minTimestamp
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        guard self.options.enabled else { return [] }

        var entries: [UsageLedgerEntry] = []
        for file in self.files {
            try Task.checkCancellation()
            guard Self.shouldRead(file: file, minTimestamp: self.minTimestamp) else { continue }
            let parsed = try Self.parseFile(file, options: self.options, minTimestamp: self.minTimestamp)
            entries.append(contentsOf: parsed)
        }
        return entries.sorted { $0.timestamp < $1.timestamp }
    }

    private static func shouldRead(file: URL, minTimestamp: Date?) -> Bool {
        guard let minTimestamp else { return true }
        guard let modifiedAt = try? file.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        else { return true }
        return modifiedAt >= minTimestamp
    }

    private static func parseFile(
        _ file: URL,
        options: OTelGenAIIngestionOptions,
        minTimestamp: Date?) throws -> [UsageLedgerEntry]
    {
        if file.pathExtension.lowercased() == "json" {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if size > Self.maxWholeJSONBytes {
                throw OTelGenAILedgerAdapterError.fileTooLarge(
                    path: file.path,
                    size: size,
                    limit: Self.maxWholeJSONBytes)
            }
            return try OTelGenAILedgerAdapter.parseData(Data(contentsOf: file), options: options)
                .filter { entry in minTimestamp.map { entry.timestamp >= $0 } ?? true }
        }

        var entries: [UsageLedgerEntry] = []

        func parseLine(_ line: Data, index: Int) throws {
            guard !line.isEmpty else { return }
            guard let text = String(data: line, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty
            else { return }
            guard let data = text.data(using: .utf8) else {
                throw OTelGenAILedgerAdapterError.invalidUTF8
            }
            do {
                let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                let parsed = OTelGenAILedgerAdapter.parseJSONObject(object, options: options)
                entries.append(contentsOf: parsed.filter { entry in
                    minTimestamp.map { entry.timestamp >= $0 } ?? true
                })
            } catch {
                throw OTelGenAILedgerAdapterError.invalidJSON("line \(index): \(error.localizedDescription)")
            }
        }

        var lineIndex = 1
        var parseError: Error?
        try CostUsageJsonl.scan(
            fileURL: file,
            maxLineBytes: 512 * 1024,
            prefixBytes: 512 * 1024)
        { line in
            guard parseError == nil else { return }
            guard !line.wasTruncated else {
                lineIndex += 1
                return
            }
            do {
                try parseLine(line.bytes, index: lineIndex)
            } catch {
                parseError = error
            }
            lineIndex += 1
        }
        if let parseError { throw parseError }
        return entries
    }
}
