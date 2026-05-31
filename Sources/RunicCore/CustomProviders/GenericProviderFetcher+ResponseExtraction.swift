import Foundation

extension GenericProviderFetcher {
    /// Extract usage data using JSONPath-like mapping
    func extractUsageData(from json: [String: Any], mapping: ResponseMapping) throws -> UsageData {
        var data = UsageData()

        if let quotaPath = mapping.quota {
            data.quota = self.extractDouble(from: json, path: quotaPath, nested: mapping.nestedPaths)
        }

        if let usedPath = mapping.used {
            data.used = self.extractDouble(from: json, path: usedPath, nested: mapping.nestedPaths)
        }

        if let remainingPath = mapping.remaining {
            data.remaining = self.extractDouble(from: json, path: remainingPath, nested: mapping.nestedPaths)
        }

        if let costPath = mapping.cost {
            data.cost = self.extractDouble(from: json, path: costPath, nested: mapping.nestedPaths)
        }

        if let resetPath = mapping.resetDate {
            data.resetDate = self.extractDate(from: json, path: resetPath, nested: mapping.nestedPaths)
        }

        if let tokensPath = mapping.tokens {
            data.tokens = self.extractInt(from: json, path: tokensPath, nested: mapping.nestedPaths)
        }

        return data
    }

    /// Extract balance data using JSONPath-like mapping
    func extractBalanceData(from json: [String: Any], mapping: ResponseMapping) throws -> BalanceData {
        var data = BalanceData()

        if let balancePath = mapping.remaining ?? mapping.used {
            data.balance = self.extractDouble(from: json, path: balancePath, nested: mapping.nestedPaths)
        }

        data.currency = self.extractString(from: json, path: "currency", nested: true) ?? "USD"

        return data
    }

    /// Extract nested value using dot notation path
    private func extractValue(from json: [String: Any], path: String, nested: Bool) -> Any? {
        if !nested {
            return json[path]
        }

        let components = path.split(separator: ".").map(String.init)
        var current: Any? = json

        for component in components {
            if let bracketIndex = component.firstIndex(of: "["),
               let closeBracket = component.firstIndex(of: "]")
            {
                let fieldName = String(component[..<bracketIndex])
                let indexStr = String(component[component.index(after: bracketIndex)..<closeBracket])

                guard let dict = current as? [String: Any],
                      let array = dict[fieldName] as? [Any],
                      let index = Int(indexStr),
                      index < array.count
                else {
                    return nil
                }
                current = array[index]
            } else {
                guard let dict = current as? [String: Any] else {
                    return nil
                }
                current = dict[component]
            }
        }

        return current
    }

    /// Extract Double value from JSON path
    private func extractDouble(from json: [String: Any], path: String, nested: Bool) -> Double? {
        guard let value = self.extractValue(from: json, path: path, nested: nested) else {
            return nil
        }

        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let string as String:
            return Double(string)
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }

    /// Extract Int value from JSON path
    private func extractInt(from json: [String: Any], path: String, nested: Bool) -> Int? {
        guard let value = self.extractValue(from: json, path: path, nested: nested) else {
            return nil
        }

        switch value {
        case let int as Int:
            return int
        case let double as Double:
            return Int(double)
        case let string as String:
            return Int(string)
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }

    /// Extract String value from JSON path
    private func extractString(from json: [String: Any], path: String, nested: Bool) -> String? {
        guard let value = self.extractValue(from: json, path: path, nested: nested) else {
            return nil
        }

        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return String(describing: value)
        }
    }

    /// Extract Date value from JSON path (supports Unix timestamp and ISO8601)
    private func extractDate(from json: [String: Any], path: String, nested: Bool) -> Date? {
        guard let value = self.extractValue(from: json, path: path, nested: nested) else {
            return nil
        }

        if let timestamp = value as? Double {
            let interval = timestamp > 10_000_000_000 ? timestamp / 1000.0 : timestamp
            return Date(timeIntervalSince1970: interval)
        }

        if let timestamp = value as? Int {
            let interval = timestamp > 10_000_000_000 ? Double(timestamp) / 1000.0 : Double(timestamp)
            return Date(timeIntervalSince1970: interval)
        }

        if let dateString = value as? String {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                return date
            }

            formatter.formatOptions.insert(.withFractionalSeconds)
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
}
