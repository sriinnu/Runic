import Foundation

/// Describes a `ParsableCommand` so the lightweight `Program` router can
/// resolve `argv` without instantiating the command immediately.
public struct CommandDescriptor: Sendable {
    public let name: String
    public let abstract: String
    public let discussion: String?
    public let signature: CommandSignature
    public let subcommands: [CommandDescriptor]
    public let defaultSubcommandName: String?

    public init(
        name: String,
        abstract: String,
        discussion: String?,
        signature: CommandSignature,
        subcommands: [CommandDescriptor] = [],
        defaultSubcommandName: String? = nil)
    {
        self.name = name
        self.abstract = abstract
        self.discussion = discussion
        self.signature = signature
        self.subcommands = subcommands
        self.defaultSubcommandName = defaultSubcommandName
    }
}

/// The fully resolved command plus the parsed values for the original `argv`.
public struct CommandInvocation: Sendable {
    public let descriptor: CommandDescriptor
    public let parsedValues: ParsedValues
    public let path: [String]

    public init(descriptor: CommandDescriptor, parsedValues: ParsedValues, path: [String]) {
        self.descriptor = descriptor
        self.parsedValues = parsedValues
        self.path = path
    }
}

/// Errors surfaced while resolving a command path prior to running user code.
public enum HelixError: Error, CustomStringConvertible, Sendable, Equatable {
    case missingCommand
    case unknownCommand(String)
    case missingSubcommand(command: String)
    case unknownSubcommand(command: String, name: String)
    case parsingError(String)
    case missingEnvironmentVariable(String)
    case webAssemblyExit(Int32)
    case optionNotBound(String)
    case argumentNotBound(String)
    case validationError(String)
    case helpRequested
    case versionRequested

    public var description: String {
        switch self {
        case .missingCommand:
            "No command specified"
        case let .unknownCommand(name):
            "Unknown command '\(name)'"
        case let .missingSubcommand(command):
            "Command '\(command)' requires a subcommand"
        case let .unknownSubcommand(command, name):
            "Unknown subcommand '\(name)' for command '\(command)'"
        case let .parsingError(error):
            error
        case let .missingEnvironmentVariable(name):
            "Missing environment variable '\(name)'"
        case let .webAssemblyExit(code):
            "WebAssembly exit with code \(code)"
        case let .optionNotBound(type):
            "Option of type '\(type)' was accessed before being parsed"
        case let .argumentNotBound(type):
            "Argument of type '\(type)' was accessed before being parsed"
        case let .validationError(message):
            "Validation error: \(message)"
        case .helpRequested:
            "Help was requested"
        case .versionRequested:
            "Version was requested"
        }
    }
}

/// Resolves `CommandLine.arguments` into concrete commands using descriptors.
public struct Program: Sendable {
    private let descriptorLookup: [String: CommandDescriptor]

    public init(descriptors: [CommandDescriptor]) {
        self.descriptorLookup = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.name, $0) })
    }

    /// Walks the command tree, parses any remaining arguments, and returns a
    /// `CommandInvocation` ready to `run()`.
    public func resolve(argv: [String]) throws -> CommandInvocation {
        var args = normalizedArguments(argv)

        guard let command = try selectRootCommand(arguments: &args) else {
            throw HelixError.missingCommand
        }
        var remainingArguments = args
        var commandPath = [command.name]
        let descriptor = try self.resolveDescriptor(command, arguments: &remainingArguments, path: &commandPath)
        let parser = CommandParser(signature: descriptor.signature.flattened())
        let parsed = try parser.parse(arguments: remainingArguments)
        return CommandInvocation(descriptor: descriptor, parsedValues: parsed, path: commandPath)
    }

    private func resolveDescriptor(
        _ descriptor: CommandDescriptor,
        arguments: inout [String],
        path: inout [String],
        stopAtHelpOrVersion: Bool = false) throws -> CommandDescriptor
    {
        if stopAtHelpOrVersion, let nextToken = arguments.first, Self.isHelpOrVersionToken(nextToken) {
            return descriptor
        }

        guard !descriptor.subcommands.isEmpty else {
            return descriptor
        }

        if arguments.isEmpty {
            if let defaultChild = lookupDefaultSubcommand(for: descriptor) {
                path.append(defaultChild.name)
                return try self.resolveDescriptor(defaultChild, arguments: &arguments, path: &path, stopAtHelpOrVersion: stopAtHelpOrVersion)
            }
            throw HelixError.missingSubcommand(command: descriptor.name)
        }

        let nextToken = arguments[0]
        if nextToken.starts(with: "-") {
            if stopAtHelpOrVersion, Self.isHelpOrVersionToken(nextToken) {
                return descriptor
            }
            if let defaultChild = lookupDefaultSubcommand(for: descriptor) {
                path.append(defaultChild.name)
                return try self.resolveDescriptor(defaultChild, arguments: &arguments, path: &path, stopAtHelpOrVersion: stopAtHelpOrVersion)
            }
            throw HelixError.missingSubcommand(command: descriptor.name)
        }

        guard let match = descriptor.subcommands.first(where: { $0.name == nextToken }) else {
            throw HelixError.unknownSubcommand(command: descriptor.name, name: nextToken)
        }
        arguments.removeFirst()
        path.append(match.name)
        return try self.resolveDescriptor(match, arguments: &arguments, path: &path, stopAtHelpOrVersion: stopAtHelpOrVersion)
    }

    private func lookupDefaultSubcommand(for descriptor: CommandDescriptor) -> CommandDescriptor? {
        guard let name = descriptor.defaultSubcommandName else { return nil }
        return descriptor.subcommands.first(where: { $0.name == name })
    }

    internal func resolveDescriptorForHelp(arguments: [String]) throws -> CommandDescriptor {
        var args = arguments
        guard let command = try selectRootCommand(arguments: &args) else {
            throw HelixError.missingCommand
        }
        var commandPath = [command.name]
        return try resolveDescriptor(command, arguments: &args, path: &commandPath, stopAtHelpOrVersion: true)
    }

    internal func normalizedArguments(_ argv: [String]) -> [String] {
        var args = argv
        guard let first = args.first else { return [] }
        if descriptorLookup[first] != nil {
            return args
        }
        let looksLikeExecutable = first.contains("/") || first.contains("\\") || first.hasSuffix(".exe")
        let nextIsCommand = args.count > 1 && descriptorLookup[args[1]] != nil
        if looksLikeExecutable || nextIsCommand {
            args.removeFirst()
        }
        return args
    }

    private func selectRootCommand(arguments: inout [String]) throws -> CommandDescriptor? {
        if let name = arguments.first, let match = descriptorLookup[name] {
            arguments.removeFirst()
            return match
        }
        if descriptorLookup.count == 1, let sole = descriptorLookup.values.first {
            return sole
        }
        if let name = arguments.first {
            throw HelixError.unknownCommand(name)
        }
        return nil
    }

    private static func isHelpOrVersionToken(_ token: String) -> Bool {
        switch token {
        case "-h", "--help", "-V", "--version":
            return true
        default:
            return false
        }
    }
}
