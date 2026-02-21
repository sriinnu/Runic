import Foundation

/// Parsed representation of `argv` after running `CommandParser`.
public struct ParsedValues: Sendable, Equatable {
    public var positional: [String]
    public var options: [String: [String]]
    public var flags: Set<String>

    public init(positional: [String], options: [String: [String]], flags: Set<String>) {
        self.positional = positional
        self.options = options
        self.flags = flags
    }
}

/// Consumes tokenized arguments using a `CommandSignature`.
public struct CommandParser {
    let signature: CommandSignature

    public init(signature: CommandSignature) {
        self.signature = signature
    }

    public func parse(arguments: [String]) throws -> ParsedValues {
        let tokens = CommandLineTokenizer.tokenize(arguments)
        var positional: [String] = []
        var options: [String: [String]] = [:]
        var flags = Set<String>()

        let optionLookup = Self.buildOptionLookup(self.signature.options)
        let flagLookup = Self.buildFlagLookup(self.signature.flags)

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            index += 1
            switch token {
            case let .option(name):
                if let definition = optionLookup[name] {
                    guard index < tokens.count else {
                        throw HelixError.parsingError("Missing value for option \(name)")
                    }
                    if case let .argument(value) = tokens[index] {
                        options[definition.label, default: []].append(value)
                        index += 1
                    } else {
                        throw HelixError.parsingError("Missing value for option \(name)")
                    }
                } else if let flagLabel = flagLookup[name] {
                    flags.insert(flagLabel)
                } else {
                    throw HelixError.parsingError("Unknown option --\(name)")
                }
            case let .optionWithValue(name, value):
                if let definition = optionLookup[name] {
                    options[definition.label, default: []].append(value)
                } else {
                    throw HelixError.parsingError("Unknown option --\(name)")
                }
            case let .flag(name):
                guard let flagLabel = flagLookup[name] else {
                    throw HelixError.parsingError("Unknown option -\(name)")
                }
                flags.insert(flagLabel)
            case let .argument(value):
                positional.append(value)
            case .terminator:
                while index < tokens.count {
                    if case let .argument(value) = tokens[index] {
                        positional.append(value)
                    }
                    index += 1
                }
            }
        }

        return ParsedValues(positional: positional, options: options, flags: flags)
    }

    private static func buildOptionLookup(_ definitions: [OptionDefinition]) -> [String: OptionDefinition] {
        var lookup: [String: OptionDefinition] = [:]
        for definition in definitions {
            for name in definition.names {
                if let longName = name.longComponent {
                    lookup[longName] = definition
                } else if let shortName = name.shortComponent {
                    lookup[String(shortName)] = definition
                }
            }
        }
        return lookup
    }

    private static func buildFlagLookup(_ definitions: [FlagDefinition]) -> [String: String] {
        var lookup: [String: String] = [:]
        for definition in definitions {
            for name in definition.names {
                if let longName = name.longComponent {
                    lookup[longName] = definition.label
                } else if let shortName = name.shortComponent {
                    lookup[String(shortName)] = definition.label
                }
            }
        }
        return lookup
    }

}

enum Token: Equatable, Sendable {
    case option(name: String)
    case optionWithValue(name: String, value: String)
    case flag(name: String)
    case argument(String)
    case terminator
}

enum CommandLineTokenizer {
    static func tokenize(_ argv: [String]) -> [Token] {
        var result: [Token] = []
        var iterator = argv.makeIterator()
        while let segment = iterator.next() {
            if segment == "--" {
                result.append(.terminator)
                result.append(contentsOf: iterator.map { .argument($0) })
                break
            } else if segment.hasPrefix("--") {
                let name = String(segment.dropFirst(2))
                if let equalsIndex = name.firstIndex(of: "=") {
                    let option = String(name[..<equalsIndex])
                    let value = String(name[name.index(after: equalsIndex)...])
                    result.append(.optionWithValue(name: option, value: value))
                } else {
                    result.append(.option(name: name))
                }
            } else if segment.hasPrefix("-"), segment.count > 1 {
                let body = segment.dropFirst()
                if body.count == 1 {
                    result.append(.option(name: String(body)))
                } else if let equalsIndex = body.firstIndex(of: "=") {
                    let name = String(body[..<equalsIndex])
                    let value = String(body[body.index(after: equalsIndex)...])
                    if name.count == 1 {
                        result.append(.optionWithValue(name: name, value: value))
                    } else {
                        // Not a supported form (only -o=value is supported).
                        result.append(.argument(segment))
                    }
                } else {
                    for char in body {
                        result.append(.flag(name: String(char)))
                    }
                }
            } else {
                result.append(.argument(segment))
            }
        }
        return result
    }
}
