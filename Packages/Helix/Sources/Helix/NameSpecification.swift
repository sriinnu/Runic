import Foundation

/// Represents a specific flag/option name (short or long).
public enum HelixName: Equatable, Sendable {
    case short(Character)
    case long(String)
}

extension HelixName {
    var longComponent: String? {
        switch self {
        case let .long(value): value
        default: nil
        }
    }

    var shortComponent: Character? {
        switch self {
        case let .short(value): value
        default: nil
        }
    }
}

/// Mimics ArgumentParser's name specification convenience API.
public enum NameSpecification: Sendable {
    case automatic
    case short(Character)
    case longName(String)
    case shortAndLong
    case customShort(Character, allowingJoined: Bool)
    case customLong(String)

    public static var long: NameSpecification { .automatic }

    public static func long(_ value: String) -> NameSpecification {
        .longName(value)
    }

    func resolve(defaultLabel: String) -> [HelixName] {
        switch self {
        case .automatic:
            [.long(Self.normalize(defaultLabel))]
        case let .short(char):
            [.short(char)]
        case let .longName(name):
            [.long(name)]
        case .shortAndLong:
            [.short(Self.firstCharacter(in: defaultLabel)), .long(Self.normalize(defaultLabel))]
        case let .customShort(char, _):
            [.short(char)]
        case let .customLong(name):
            [.long(name)]
        }
    }

    private static func normalize(_ label: String) -> String {
        guard !label.isEmpty else { return label }

        let scalars = Array(label.unicodeScalars)
        let uppercase = CharacterSet.uppercaseLetters
        let lowercase = CharacterSet.lowercaseLetters
        let digits = CharacterSet.decimalDigits

        var output = ""
        var lastWasUpper = false
        var lastWasLower = false

        for scalar in scalars {
            let isUpper = uppercase.contains(scalar)
            let isLower = lowercase.contains(scalar)
            let isDigit = digits.contains(scalar)

            if isUpper {
                if lastWasLower || lastWasUpper {
                    output.append("-")
                }
                output.append(Character(scalar).lowercased())
                lastWasUpper = true
                lastWasLower = false
            } else if isLower || isDigit {
                output.append(Character(scalar))
                lastWasLower = true
                lastWasUpper = false
            } else {
                output.append("-")
                lastWasUpper = false
                lastWasLower = false
            }
        }

        return output.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func firstCharacter(in label: String) -> Character {
        label.first ?? "x"
    }
}
