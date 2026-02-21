import Foundation

/// Protocol every Helix command adopts. Provide metadata via
/// `commandDescription` and implement `run()` to perform the command's work.
@MainActor
public protocol ParsableCommand: Sendable {
    init()
    static var commandDescription: CommandDescription { get }
    mutating func run() async throws

    /// Optional validation method called after parsing but before run().
    /// Throw `ValidationError` if validation fails.
    mutating func validate() throws
}

extension ParsableCommand {
    /// Default implementation - does nothing.
    public mutating func validate() throws {
        // Default: no validation
    }

    public static var commandDescription: CommandDescription {
        CommandDescription()
    }

    /// Creates a command descriptor from this command type.
    public static var descriptor: CommandDescriptor {
        let signature = CommandSignature.describe(Self()).flattened()
        let typeName = String(describing: Self.self)
        let name: String
        if let cmdName = commandDescription.commandName {
            name = cmdName
        } else {
            // Remove "Command" suffix if present
            name = typeName.hasSuffix("Command") ? String(typeName.dropLast(7)) : typeName
        }
        return CommandDescriptor(
            name: name,
            abstract: commandDescription.abstract,
            discussion: commandDescription.discussion,
            signature: signature,
            subcommands: commandDescription.subcommands.map { $0.descriptor },
            defaultSubcommandName: commandDescription.defaultSubcommand.map { $0.descriptor.name }
        )
    }

    /// Runs the command with arguments from the current platform context.
    public static func main() async throws {
        try await main(arguments: DefaultPlatformContext.shared.arguments)
    }

    /// Runs the command with the specified arguments.
    public static func main(arguments argv: [String]) async throws {
        // Build descriptor
        let descriptor = Self.descriptor

        // Create program and resolve
        let program = Program(descriptors: [descriptor])
        let normalizedArguments = program.normalizedArguments(argv)
        let (helpRequested, versionRequested) = parseHelpVersionFlags(from: normalizedArguments)

        if normalizedArguments.isEmpty, commandDescription.showHelpOnEmptyInvocation {
            print(HelixError.helpText(for: descriptor))
            return
        }

        if helpRequested {
            let helpDescriptor = (try? program.resolveDescriptorForHelp(arguments: normalizedArguments)) ?? descriptor
            print(HelixError.helpText(for: helpDescriptor))
            return
        }

        if versionRequested {
            if let version = commandDescription.version {
                print(version)
            }
            return
        }

        do {
            let invocation = try program.resolve(argv: normalizedArguments)
            let commandType = resolveCommandType(path: invocation.path)
            var command = commandType.init()

            try bindValues(from: invocation, to: &command)
            try command.validate()
            try await command.run()
        } catch let error as HelixError {
            switch error {
            default:
                throw error
            }
        }
    }

    private static func parseHelpVersionFlags(from arguments: [String]) -> (help: Bool, version: Bool) {
        var helpRequested = false
        var versionRequested = false
        for argument in arguments {
            if argument == "--" { break }
            switch argument {
            case "-h", "--help":
                helpRequested = true
            case "-V", "--version":
                versionRequested = true
            default:
                break
            }
        }
        return (helpRequested, versionRequested)
    }

    /// Binds parsed values from invocation to command properties using reflection.
    /// This method uses Mirror to traverse command properties and set values from parsed arguments.
    private static func bindValues(from invocation: CommandInvocation, to command: inout any ParsableCommand) throws {
        try _HelixBinder.bindCommand(
            &command,
            parsed: invocation.parsedValues,
            environment: DefaultPlatformContext.shared.environment
        )
    }

    private static func resolveCommandType(path: [String]) -> any ParsableCommand.Type {
        var current: any ParsableCommand.Type = Self.self
        for component in path.dropFirst() {
            guard let match = current.commandDescription.subcommands.first(where: { $0.descriptor.name == component }) else {
                break
            }
            current = match
        }
        return current
    }
}

/// Helper type for Option wrapper inspection
public struct OptionWrapperHolder {
    let storage: Any?
    let nameSpecifications: [NameSpecification]
}

/// Helper type for Argument wrapper inspection
public struct ArgumentWrapperHolder {
    let storage: Any?
}

/// Helper type for Flag wrapper inspection
public struct FlagWrapperHolder {
    let wrappedValue: Bool
}

/// Declarative metadata describing a command built with `ParsableCommand`.
public struct CommandDescription: Sendable {
    public var commandName: String?
    public var abstract: String
    public var discussion: String?
    public var version: String?
    public var subcommands: [any ParsableCommand.Type]
    public var defaultSubcommand: (any ParsableCommand.Type)?
    public var showHelpOnEmptyInvocation: Bool

    public init(
        commandName: String? = nil,
        abstract: String = "",
        discussion: String? = nil,
        version: String? = nil,
        subcommands: [any ParsableCommand.Type] = [],
        defaultSubcommand: (any ParsableCommand.Type)? = nil,
        showHelpOnEmptyInvocation: Bool = false)
    {
        self.commandName = commandName
        self.abstract = abstract
        self.discussion = discussion
        self.version = version
        self.subcommands = subcommands
        self.defaultSubcommand = defaultSubcommand
        self.showHelpOnEmptyInvocation = showHelpOnEmptyInvocation
    }
}

/// Thrown from `ParsableCommand/run()` when user input fails validation.
public struct ValidationError: Error, LocalizedError, CustomStringConvertible, Sendable {
    private let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { self.message }
    public var description: String { self.message }
}

/// Exit sentinel understood by CLI harnesses.
public struct ExitCode: Error, Equatable, CustomStringConvertible, Sendable {
    public let rawValue: Int32

    public init(_ rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let success = ExitCode(0)
    public static let failure = ExitCode(1)

    public var description: String { "ExitCode(\(self.rawValue))" }
}
