import AppKit
import RunicCore

extension IconRenderer {
    struct IconCacheKey: Hashable {
        let primary: Int
        let weekly: Int
        let credits: Int
        let stale: Bool
        let style: Int
        let indicator: Int
        let appearance: Int
        let dataMode: Int
        /// Theme palette id for vibrant rendering. Template icons use system
        /// label colors, so they should not churn when preferences change.
        let themeID: String
    }

    final class IconCacheStore: @unchecked Sendable {
        private var cache: [IconCacheKey: NSImage] = [:]
        private var order: [IconCacheKey] = []
        private let lock = NSLock()

        func cachedIcon(for key: IconCacheKey) -> NSImage? {
            self.lock.lock()
            defer { self.lock.unlock() }
            guard let image = self.cache[key] else { return nil }
            if let idx = self.order.firstIndex(of: key) {
                self.order.remove(at: idx)
                self.order.append(key)
            }
            return image
        }

        func storeIcon(_ image: NSImage, for key: IconCacheKey, limit: Int) {
            self.lock.lock()
            defer { self.lock.unlock() }
            self.cache[key] = image
            self.order.removeAll { $0 == key }
            self.order.append(key)
            while self.order.count > limit {
                let oldest = self.order.removeFirst()
                self.cache.removeValue(forKey: oldest)
            }
        }
    }

    final class MorphCache: @unchecked Sendable {
        private let cache = NSCache<NSNumber, NSImage>()

        init(limit: Int) {
            self.cache.countLimit = limit
        }

        func image(for key: NSNumber) -> NSImage? {
            self.cache.object(forKey: key)
        }

        func set(_ image: NSImage, for key: NSNumber) {
            self.cache.setObject(image, forKey: key)
        }
    }

    static let styleKeys: [IconStyle: Int] = [
        .codex: 0,
        .claude: 1,
        .zai: 2,
        .gemini: 3,
        .antigravity: 4,
        .cursor: 5,
        .factory: 6,
        .copilot: 7,
        .minimax: 8,
        .openrouter: 9,
        .groq: 10,
        .deepseek: 11,
        .fireworks: 12,
        .mistral: 13,
        .perplexity: 14,
        .kimi: 15,
        .auggie: 16,
        .together: 17,
        .cohere: 18,
        .xai: 19,
        .cerebras: 20,
        .sambanova: 21,
        .azure: 22,
        .bedrock: 23,
        .vertexai: 24,
        .qwen: 25,
        .vercelai: 26,
        .localLLM: 27,
        .combined: 99,
    ]

    static let iconCacheStore = IconCacheStore()
    static let iconCacheLimit = PerformanceConstants.iconCacheSize
    static let morphBucketCount = 200
    static let morphCache = MorphCache(limit: PerformanceConstants.morphCacheSize)

    static func quantizedPercent(_ value: Double?) -> Int {
        guard let value else { return -1 }
        return Int((value * 10).rounded())
    }

    static func quantizedCredits(_ value: Double?) -> Int {
        guard let value else { return -1 }
        let clamped = max(0, min(value, self.creditsCap))
        return Int((clamped * 10).rounded())
    }

    static func styleKey(_ style: IconStyle) -> Int {
        self.styleKeys[style] ?? Self.styleKeys[.combined] ?? 99
    }

    static func indicatorKey(_ indicator: ProviderStatusIndicator) -> Int {
        switch indicator {
        case .none: 0
        case .minor: 1
        case .major: 2
        case .critical: 3
        case .maintenance: 4
        case .unknown: 5
        }
    }

    static func appearanceKey(_ appearance: IconAppearance) -> Int {
        switch appearance {
        case .template: 0
        case .vibrant: 1
        }
    }

    static func dataModeKey(_ mode: IconDataMode) -> Int {
        switch mode {
        case .remaining: 0
        case .used: 1
        }
    }

    static func morphCacheKey(
        progress: Double,
        style: IconStyle,
        appearance: IconAppearance) -> NSNumber
    {
        let bucket = Int((progress * Double(self.morphBucketCount)).rounded())
        let key = self.styleKey(style) * 10000 + self.appearanceKey(appearance) * 1000 + bucket
        return NSNumber(value: key)
    }

    static func cachedIcon(for key: IconCacheKey) -> NSImage? {
        self.iconCacheStore.cachedIcon(for: key)
    }

    static func storeIcon(_ image: NSImage, for key: IconCacheKey) {
        self.iconCacheStore.storeIcon(image, for: key, limit: self.iconCacheLimit)
    }
}
