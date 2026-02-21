import Foundation

/// Declarative description of all options, flags, and positional arguments.
public struct CommandSignature: Sendable {
    public private(set) var arguments: [ArgumentDefinition]
    public private(set) var options: [OptionDefinition]
    public private(set) var flags: [FlagDefinition]
    public private(set) var optionGroups: [CommandSignature]

    public init(
        arguments: [ArgumentDefinition] = [],
        options: [OptionDefinition] = [],
        flags: [FlagDefinition] = [],
        optionGroups: [CommandSignature] = [])
    {
        self.arguments = arguments
        self.options = options
        self.flags = flags
        self.optionGroups = optionGroups
    }

    mutating func append(_ component: CommandComponent) {
        switch component {
        case let .argument(definition):
            self.arguments.append(definition)
        case let .option(definition):
            self.options.append(definition)
        case let .flag(definition):
            self.flags.append(definition)
        case let .group(signature):
            self.optionGroups.append(signature)
        }
    }

    /// Uses reflection to discover Helix property wrappers and build a signature.
    public static func describe(_ command: some Any) -> CommandSignature {
        var signature = CommandSignature()
        Self.inspect(value: command, into: &signature)
        return signature
    }

    private static func inspect(value: Any, into signature: inout CommandSignature) {
        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            guard let label = child.label else { continue }
            if let registrable = child.value as? HelixMetadata {
                registrable.register(label: label, signature: &signature)
            } else if let optionGroup = child.value as? HelixOptionGroup {
                optionGroup.register(label: label, signature: &signature)
            }
        }
    }

    /// Returns a copy where nested option groups are merged into a single signature.
    public func flattened() -> CommandSignature {
        var combined = CommandSignature(
            arguments: self.arguments,
            options: self.options,
            flags: self.flags)
        for group in self.optionGroups {
            let flattenedGroup = group.flattened()
            combined.arguments.append(contentsOf: flattenedGroup.arguments)
            combined.options.append(contentsOf: flattenedGroup.options)
            combined.flags.append(contentsOf: flattenedGroup.flags)
        }
        return combined
    }
}

/// Internal helper used by property wrappers.
public enum CommandComponent: Sendable {
    case argument(ArgumentDefinition)
    case option(OptionDefinition)
    case flag(FlagDefinition)
    case group(CommandSignature)
}

/// Canonical description of an option.
public struct OptionDefinition: Sendable, Equatable {
    public let label: String
    public let names: [HelixName]
    public let help: String?
    public let envVar: String?

    public init(label: String, names: [HelixName], help: String?, envVar: String? = nil) {
        self.label = label
        self.names = names
        self.help = help
        self.envVar = envVar
    }
}

/// Canonical description of a positional argument.
public struct ArgumentDefinition: Sendable, Equatable {
    public let label: String
    public let help: String?
    public let isOptional: Bool

    public init(label: String, help: String?, isOptional: Bool) {
        self.label = label
        self.help = help
        self.isOptional = isOptional
    }
}

/// Canonical description of a boolean flag.
public struct FlagDefinition: Sendable, Equatable {
    public let label: String
    public let names: [HelixName]
    public let help: String?

    public init(label: String, names: [HelixName], help: String?) {
        self.label = label
        self.names = names
        self.help = help
    }
}
