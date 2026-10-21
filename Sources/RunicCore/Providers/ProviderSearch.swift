import Foundation

extension UsageProvider {
    /// Settings → Providers search. Every word of `query` must appear in one of the
    /// brand's names: display name, CLI name and aliases, raw value — of the brand
    /// and of its China slot, plus "china"/"cn" when it has one. Matching ignores
    /// case and punctuation, so "zai" finds "z.ai" and "kimi cn" finds Kimi's China slot.
    /// An empty query matches everything.
    public func matchesSearch(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace).map { Self.searchKey(String($0)) }
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return true }
        let haystack = self.searchHaystack
        return words.allSatisfy { word in haystack.contains { $0.contains(word) } }
    }

    private var searchHaystack: [String] {
        var names: [String] = []
        for slot in [self, self.chinaSibling].compactMap(\.self) {
            let descriptor = ProviderDescriptorRegistry.descriptor(for: slot)
            names.append(descriptor.metadata.displayName)
            names.append(descriptor.metadata.cliName)
            names.append(contentsOf: descriptor.cli.aliases)
            names.append(slot.rawValue)
        }
        if self.chinaSibling != nil { names.append(contentsOf: ["china", "cn"]) }
        return names.map(Self.searchKey).filter { !$0.isEmpty }
    }

    private static func searchKey(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }
}
