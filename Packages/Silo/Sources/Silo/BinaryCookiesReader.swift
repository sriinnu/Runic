import Foundation

/// Parser for Safari/WebKit Cookies.binarycookies files (macOS and iOS).
struct BinaryCookiesReader {
    func readCookies(from url: URL) throws -> [BrowserCookieRecord] {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    func parse(data: Data) throws -> [BrowserCookieRecord] {
        guard readTag(in: data, at: 0) == "cook" else {
            throw BrowserCookieError.loadFailed(
                browser: .safari,
                details: "Invalid cookie file header.")
        }

        guard let pageCount = readUInt32BE(in: data, at: 4) else {
            return []
        }

        var pageSizes: [Int] = []
        var offset = 8
        for _ in 0..<pageCount {
            guard let size = readUInt32BE(in: data, at: offset) else { break }
            pageSizes.append(Int(size))
            offset += 4
        }

        var records: [BrowserCookieRecord] = []
        for size in pageSizes {
            guard offset + size <= data.count else { break }
            let pageData = data.subdata(in: offset..<(offset + size))
            records.append(contentsOf: parsePage(pageData))
            offset += size
        }
        return records
    }

    private func parsePage(_ pageData: Data) -> [BrowserCookieRecord] {
        guard pageData.count >= 8 else { return [] }
        let pageTag = readTag(in: pageData, at: 0)
        let pageHeaderBE = readUInt32BE(in: pageData, at: 0)
        let pageHeaderLE = readUInt32LE(in: pageData, at: 0)
        guard pageTag == "page" || pageHeaderBE == 0x00000100 || pageHeaderLE == 0x00000100 else { return [] }
        guard let cookieCount = readUInt32LE(in: pageData, at: 4) else { return [] }

        var offsets: [Int] = []
        var offset = 8
        for _ in 0..<cookieCount {
            guard let cookieOffset = readUInt32LE(in: pageData, at: offset) else { break }
            offsets.append(Int(cookieOffset))
            offset += 4
        }

        var records: [BrowserCookieRecord] = []
        for cookieOffset in offsets {
            if let record = parseCookie(in: pageData, at: cookieOffset) {
                records.append(record)
            }
        }
        return records
    }

    private func parseCookie(in pageData: Data, at offset: Int) -> BrowserCookieRecord? {
        guard let sizeValue = readUInt32LE(in: pageData, at: offset) else { return nil }
        let size = Int(sizeValue)
        guard size > 0, offset + size <= pageData.count else { return nil }

        guard size >= Self.cookieHeaderSize else { return nil }

        let flags = readUInt32LE(in: pageData, at: offset + 8) ?? 0
        guard let domainOffset = readUInt32LE(in: pageData, at: offset + 16),
              let nameOffset = readUInt32LE(in: pageData, at: offset + 20),
              let pathOffset = readUInt32LE(in: pageData, at: offset + 24),
              let valueOffset = readUInt32LE(in: pageData, at: offset + 28) else {
            return nil
        }

        let recordBase = offset
        let recordLimit = offset + size
        let expiryOffset = recordBase + 40
        let creationOffset = recordBase + 48
        var expirySeconds = readDoubleLE(in: pageData, at: expiryOffset)
        var creationSeconds = readDoubleLE(in: pageData, at: creationOffset)
        if expirySeconds == nil {
            let fallbackExpiry = recordBase + size - 16
            expirySeconds = readDoubleLE(in: pageData, at: fallbackExpiry)
            if creationSeconds == nil {
                creationSeconds = readDoubleLE(in: pageData, at: fallbackExpiry + 8)
            }
        }
        guard let expirySeconds else { return nil }

        guard let domain = readCString(in: pageData, at: recordBase + Int(domainOffset), limit: recordLimit),
              let name = readCString(in: pageData, at: recordBase + Int(nameOffset), limit: recordLimit),
              let path = readCString(in: pageData, at: recordBase + Int(pathOffset), limit: recordLimit),
              let value = readCString(in: pageData, at: recordBase + Int(valueOffset), limit: recordLimit) else {
            return nil
        }

        let expires = expirySeconds > 0 ? Date(timeIntervalSinceReferenceDate: expirySeconds) : nil
        let createdAt = creationSeconds.flatMap { $0 > 0 ? Date(timeIntervalSinceReferenceDate: $0) : nil }
        let isSecure = (flags & 0x1) != 0
        let isHTTPOnly = (flags & 0x4) != 0

        return BrowserCookieRecord(
            domain: domain,
            name: name,
            path: path.isEmpty ? "/" : path,
            value: value,
            expires: expires,
            createdAt: createdAt,
            isSecure: isSecure,
            isHTTPOnly: isHTTPOnly,
            sameSite: nil)
    }

    private func readTag(in data: Data, at offset: Int) -> String? {
        guard offset + 4 <= data.count else { return nil }
        let slice = data[offset..<(offset + 4)]
        return String(data: slice, encoding: .ascii)
    }

    private func readCString(in data: Data, at offset: Int, limit: Int? = nil) -> String? {
        guard offset < data.count else { return nil }
        let cappedLimit = min(limit ?? data.count, data.count)
        guard offset < cappedLimit else { return nil }
        var end = offset
        while end < cappedLimit && data[end] != 0 {
            end += 1
        }
        let slice = data[offset..<end]
        return String(data: slice, encoding: .utf8)
    }

    private func readUInt32BE(in data: Data, at offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let b0 = UInt32(data[offset]) << 24
        let b1 = UInt32(data[offset + 1]) << 16
        let b2 = UInt32(data[offset + 2]) << 8
        let b3 = UInt32(data[offset + 3])
        return b0 | b1 | b2 | b3
    }

    private func readUInt32LE(in data: Data, at offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        let b3 = UInt32(data[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    private func readUInt64LE(in data: Data, at offset: Int) -> UInt64? {
        guard offset + 8 <= data.count else { return nil }
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(data[offset + index]) << (8 * index)
        }
        return value
    }

    private func readDoubleLE(in data: Data, at offset: Int) -> Double? {
        guard let bits = readUInt64LE(in: data, at: offset) else { return nil }
        return Double(bitPattern: bits)
    }

    private static let cookieHeaderSize = 56
}
