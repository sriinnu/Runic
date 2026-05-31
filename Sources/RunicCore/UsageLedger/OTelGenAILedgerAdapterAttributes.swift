import Foundation

extension OTelGenAILedgerAdapter {
    static func parseAttributesPayload(_ payload: Any?) -> [String: Any] {
        guard let payload else { return [:] }
        if let keyed = payload as? [String: Any] {
            if keyed.keys.contains("attributes"), let nested = keyed["attributes"] {
                return self.parseAttributesPayload(nested)
            }
            if keyed.keys.contains("key"), keyed.keys.contains("value") {
                return self.parseAttributesPayload([keyed])
            }
            return keyed
        }
        guard let list = payload as? [Any] else { return [:] }

        var attributes: [String: Any] = [:]
        for itemAny in list {
            guard let item = itemAny as? [String: Any] else { continue }
            guard let key = item["key"] as? String, !key.isEmpty else { continue }
            guard let decoded = self.decodeAttributeValue(item["value"]) else { continue }
            attributes[key] = decoded
        }
        return attributes
    }

    static func decodeAttributeValue(_ raw: Any?) -> Any? {
        guard let raw else { return nil }
        guard let dictionary = raw as? [String: Any] else { return raw }

        if let stringValue = dictionary["stringValue"] as? String {
            return stringValue
        }
        if let intValue = dictionary["intValue"] {
            return self.coerceInt(intValue) ?? intValue
        }
        if let doubleValue = dictionary["doubleValue"] {
            return self.coerceDouble(doubleValue) ?? doubleValue
        }
        if let boolValue = dictionary["boolValue"] as? Bool {
            return boolValue
        }
        if let arrayValue = dictionary["arrayValue"] as? [String: Any],
           let values = arrayValue["values"] as? [Any]
        {
            return values.compactMap { self.decodeAttributeValue($0) }
        }
        if let kvListValue = dictionary["kvlistValue"] as? [String: Any],
           let values = kvListValue["values"] as? [Any]
        {
            return self.parseAttributesPayload(values)
        }
        return nil
    }

    static func stringValue(for keys: [String], in dictionary: [String: Any]) -> String? {
        for key in keys {
            guard let raw = self.lookupValue(forKey: key, in: dictionary) else { continue }
            if let string = raw as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
                continue
            }
            if let number = raw as? NSNumber {
                return number.stringValue
            }
        }
        return nil
    }

    static func intValue(for keys: [String], in dictionary: [String: Any]) -> Int? {
        for key in keys {
            guard let raw = self.lookupValue(forKey: key, in: dictionary) else { continue }
            if let coerced = self.coerceInt(raw) {
                return coerced
            }
        }
        return nil
    }

    static func doubleValue(for keys: [String], in dictionary: [String: Any]) -> Double? {
        for key in keys {
            guard let raw = self.lookupValue(forKey: key, in: dictionary) else { continue }
            if let coerced = self.coerceDouble(raw) {
                return coerced
            }
        }
        return nil
    }

    static func dateValue(for keys: [String], in dictionary: [String: Any]) -> Date? {
        for key in keys {
            guard let raw = self.lookupValue(forKey: key, in: dictionary) else { continue }
            if let numeric = self.coerceDouble(raw),
               let date = self.dateFromNumericTimestamp(numeric)
            {
                return date
            }
            if let text = raw as? String, let parsed = self.parseISODate(text) {
                return parsed
            }
        }
        return nil
    }

    static func dateFromNumericTimestamp(_ raw: Double) -> Date? {
        guard raw > 0 else { return nil }

        let seconds: Double = if raw >= 100_000_000_000_000_000 {
            raw / 1_000_000_000
        } else if raw >= 100_000_000_000_000 {
            raw / 1_000_000
        } else if raw >= 100_000_000_000 {
            raw / 1000
        } else {
            raw
        }

        guard seconds > 0, seconds < 4_102_444_800 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    static func parseISODate(_ text: String) -> Date? {
        if let parsed = try? Date(text, strategy: .iso8601) {
            return parsed
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    static func lookupValue(forKey key: String, in dictionary: [String: Any]) -> Any? {
        if let direct = dictionary[key] {
            return direct
        }
        let parts = key.split(separator: ".").map(String.init)
        guard parts.count > 1 else { return nil }

        var cursor: Any = dictionary
        for part in parts {
            guard let object = cursor as? [String: Any], let next = object[part] else { return nil }
            cursor = next
        }
        return cursor
    }

    static func coerceInt(_ value: Any) -> Int? {
        if let int = value as? Int { return int }
        if let uint = value as? UInt { return Int(uint) }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let int = Int(trimmed) { return int }
            if let double = Double(trimmed) { return Int(double) }
        }
        return nil
    }

    static func coerceDouble(_ value: Any) -> Double? {
        if let double = value as? Double { return double }
        if let float = value as? Float { return Double(float) }
        if let int = value as? Int { return Double(int) }
        if let uint = value as? UInt { return Double(uint) }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(trimmed)
        }
        return nil
    }

    static func isScalar(_ value: Any) -> Bool {
        value is String || value is NSNumber || value is Bool
    }
}
