# Helix

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="logo-dark.svg" />
    <img src="logo.svg" alt="Helix Logo" width="200" />
  </picture>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0+-orange.svg" />
  <img src="https://img.shields.io/badge/Platforms-Apple%20%7C%20Linux%20%7C%20Windows%20%7C%20WASI-lightgrey.svg" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" />
  <img src="https://github.com/sriinnu/Helix/actions/workflows/ci.yml/badge.svg" />
</p>

A modern, declarative command-line parsing framework for Swift that uses property wrappers to create elegant CLI interfaces. Inspired by Swift ArgumentParser but with a lighter footprint and simplified API.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture](#architecture)
3. [Property Wrappers](#property-wrappers)
4. [Custom Types](#custom-types)
5. [Validation](#validation)
6. [Subcommands](#subcommands)
7. [Cross-Platform Support](#cross-platform-support)
8. [Testing](#testing)
9. [API Reference](#api-reference)
10. [Migration Guide](#migration-guide)
11. [Best Practices](#best-practices)
12. [Performance](#performance)
13. [FAQ](#faq)
14. [Contributing](#contributing)

---

## Quick Start

### Installation

Add Helix to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sriinnu/Helix", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTool",
    dependencies: ["Helix"]
)
```

### Your First Command

```swift
import Helix

struct GreetCommand: ParsableCommand {
    static var commandDescription: CommandDescription {
        CommandDescription(commandName: "greet", abstract: "Print a greeting")
    }

    @Option(name: .shortAndLong, help: "Name to greet")
    var name: String = "World"

    @Flag(name: .shortAndLong, help: "Use formal greeting")
    var formal: Bool = false

    mutating func run() async throws {
        let greeting = formal ? "Good day, \(name)." : "Hello, \(name)!"
        print(greeting)
    }
}

try await GreetCommand.main()
```

**Usage:**

```bash
$ greet --name Alice
Hello, Alice!

$ greet --name Bob --formal
Good day, Bob.
```

Note: `ParsedValues` uses property labels (e.g. `logLevel`, `failFast`) as keys, not the kebab-case CLI names.

---

## Architecture

### Execution Flow

```
User Input (argv)
        ↓
Program.resolve() - Command/subcommand resolution
        ↓
CommandParser.parse() - Tokenization and parsing
        ↓
Binding - automatic property wrapper binding
        ↓
validate() - Optional validation
        ↓
run() - Execute command logic
```

### Component Overview

| Component | Purpose |
|-----------|---------|
| `ParsableCommand` | Main protocol all commands conform to |
| `@Option` | Named parameters (`--output file.txt`) |
| `@Argument` | Positional parameters (`file.txt`) |
| `@Flag` | Boolean switches (`--verbose`) |
| `@OptionGroup` | Reusable option sets |
| `CommandSignature` | Metadata about command parameters |
| `CommandParser` | Tokenizes and parses arguments |
| `Program` | Routes argv to commands |
| `PlatformContext` | Platform abstraction layer |
| `PlatformPath` | Cross-platform file paths |

### How It Works

1. **Reflection-Based Discovery**: Helix uses Swift's `Mirror` API to automatically discover `@Option`, `@Argument`, and `@Flag` properties on your command types.

2. **Two-Phase Parsing**:
   - **Resolution**: `Program.resolve()` identifies which command/subcommand to run
   - **Parsing**: `CommandParser.parse()` extracts values from argv

3. **Property Binding**: Parsed values are automatically bound to your command properties (including `@OptionGroup`).

---

## Property Wrappers

### `@Option` - Named Parameters

Options are named parameters that accept values:

```swift
// Required option (no default)
@Option(help: "Output file path")
var output: String

// Optional option (with default)
@Option(help: "Verbosity level (0-5)")
var verbose: Int = 0

// Short and long names
@Option(name: .shortAndLong, help: "Configuration file")
var config: String = "config.json"

// Custom names
@Option(name: .short('o'), help: "Output file")
var outputFile: String

@Option(name: .longName("output-dir"), help: "Directory for output")
var outputDirectory: String

// Multiple names
@Option(names: [.short('v'), .longName("verbose")], help: "Verbose output")
var verboseMode: Bool = false

// Environment variable fallback
@Option(name: .shortAndLong, envVar: "API_KEY", help: "API key")
var apiKey: String?
```

`envVar` provides environment variable fallback when the option is not provided on the command line.

### `@Argument` - Positional Parameters

Arguments are parsed by position, not by name:

```swift
// Required argument
@Argument(help: "Input file to process")
var input: String

// Optional argument
@Argument(help: "Output file (defaults to stdout)")
var output: String?

// Multiple arguments (parsed in order)
@Argument(help: "Source files")
var sources: [String]
```

### `@Flag` - Boolean Switches

Flags are boolean options that don't take values:

```swift
// Simple flag
@Flag(help: "Enable debug mode")
var debug: Bool = false

// Short form
@Flag(name: .short('v'), help: "Verbose output")
var verbose: Bool = false

// Long form
@Flag(name: .longName("verbose"), help: "Verbose output")
var verbose: Bool = false

// Combined short
@Flag(name: .shortAndLong, help: "Force overwrite")
var force: Bool = false
```

### `@OptionGroup` - Reusable Option Sets

Group related options together:

```swift
struct LoggingOptions: HelixParsable {
    @Option(help: "Log level (debug|info|warn|error)")
    var level: String = "info"

    @Option(help: "Log file path")
    var file: String?

    @Flag(help: "Include timestamps")
    var timestamps: Bool = true
}

struct MyCommand: ParsableCommand {
    @OptionGroup
    var logging: LoggingOptions

    mutating func run() async throws {
        print("Logging at level: \(logging.level)")
    }
}
```

When parsing manually, pass `Self.descriptor.signature.flattened()` to `CommandParser` to include options from option groups.
`ParsableCommand.main()` already uses flattened signatures; the note above only applies if you instantiate `CommandParser` manually.

### Name Specification Options

| Specification | Generated Names | Example |
|--------------|-----------------|---------|
| `.automatic` | `--property-name` | `--output-file` |
| `.short('o')` | `-o` | `-o file.txt` |
| `.longName("out")` | `--out` | `--out file.txt` |
| `.shortAndLong` | `-o`, `--output` | `-o file.txt` / `--output file.txt` |
| `.customShort('x')` | `-x` | `-x file.txt` |
| `.customLong("output")` | `--output` | `--output file.txt` |

Note: `--name=value` and `-o=value` are supported. Joined short option values (e.g. `-ovalue`) are not supported.

---

## Custom Types

### Conforming to `ExpressibleFromArgument`

Add support for custom types by conforming to `ExpressibleFromArgument`:

```swift
enum LogLevel: String, ExpressibleFromArgument {
    case debug, info, warning, error

    init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
}

// Usage
@Option(help: "Log level")
var logLevel: LogLevel = .info
```

### Complex Types

```swift
struct ServerAddress: ExpressibleFromArgument {
    let host: String
    let port: Int

    init?(argument: String) {
        let parts = argument.split(separator: ":", maxSplits: 1)
        guard parts.count == 2,
              let port = Int(parts[1]) else {
            return nil
        }
        self.host = String(parts[0])
        self.port = port
    }
}

// Usage
@Option(help: "Server address (host:port)")
var server: ServerAddress
```

### Built-in Type Support

Helix supports these types out of the box:

| Type | Notes |
|------|-------|
| `String` | Direct assignment |
| `Substring` | Converted from String |
| `Int`, `Int32`, `Int64` | Base-10 parsing |
| `Double`, `Float` | Decimal parsing |
| `Bool` | `true/false/t/1/yes/y` / `false/f/0/no/n` |
| `Optional<T>` | Wraps any supported type |
| `Array<T>` | Options support comma-separated values and repeated occurrences; positional arrays consume remaining positionals |

---

## Validation

Add custom validation logic with the `validate()` method:

```swift
struct DeployCommand: ParsableCommand {
    @Option(help: "Environment (dev|staging|prod)")
    var environment: String

    @Option(help: "Timeout in seconds (1-300)")
    var timeout: Int = 60

    @Argument(help: "Service name")
    var service: String

    mutating func validate() throws {
        // Validate environment
        let validEnvironments = ["dev", "staging", "prod"]
        guard validEnvironments.contains(environment) else {
            throw ValidationError("Environment must be one of: \(validEnvironments.joined(separator: ", "))")
        }

        // Validate timeout range
        guard (1...300).contains(timeout) else {
            throw ValidationError("Timeout must be between 1 and 300 seconds")
        }

        // Cross-field validation
        if environment == "prod" && timeout < 30 {
            throw ValidationError("Production deployments require at least 30 second timeout")
        }
    }

    mutating func run() async throws {
        print("Deploying \(service) to \(environment) with \(timeout)s timeout")
    }
}
```

### ValidationError

```swift
throw ValidationError("Custom error message")

// Or use CustomStringConvertible types
struct AppError: Error, CustomStringConvertible {
    var description: String
}

throw AppError(description: "Something went wrong")
```

---

## Subcommands

Create hierarchical CLI tools with nested commands:

```swift
struct GitCommand: ParsableCommand {
    static var commandDescription: CommandDescription {
        CommandDescription(
            commandName: "git",
            abstract: "Distributed version control",
            discussion: "Git is a free and open source distributed version control system.",
            subcommands: [
                CloneCommand.self,
                CommitCommand.self,
                PushCommand.self,
                PullCommand.self
            ],
            defaultSubcommand: nil  // No default - user must specify
        )
    }
}

struct CloneCommand: ParsableCommand {
    @Argument(help: "Repository URL")
    var repository: String

    @Option(name: .shortAndLong, help: "Directory to clone into")
    var directory: String?

    static var commandDescription: CommandDescription {
        CommandDescription(
            commandName: "clone",
            abstract: "Clone a repository"
        )
    }

    mutating func run() async throws {
        print("Cloning \(repository)...")
    }
}
```

**Usage:**

```bash
$ git clone https://github.com/user/repo --directory myproject
$ git commit -m "Fix bug"
$ git push origin main
```

`ParsableCommand.main()` dispatches to subcommands automatically. When you run the executable, you typically do not need to include the root command name as the first argument.

### Default Subcommand

Automatically route to a subcommand when none specified:

```swift
struct ToolCommand: ParsableCommand {
    static var commandDescription: CommandDescription {
        CommandDescription(
            commandName: "tool",
            subcommands: [BuildCommand.self, TestCommand.self],
            defaultSubcommand: BuildCommand.self  // Auto-routes to 'build'
        )
    }
}
```

---

## Cross-Platform Support

Helix runs on multiple platforms with a unified API:

### Supported Platforms

| Platform | Minimum Version | Status |
|----------|-----------------|--------|
| macOS | 14.0+ | ✅ Full Support |
| iOS | 17.0+ | ✅ Full Support |
| tvOS | 17.0+ | ✅ Full Support |
| watchOS | 10.0+ | ✅ Full Support |
| visionOS | 1.0+ | ✅ Full Support |
| Linux | - | ✅ Supported (CI) |
| Windows | - | ✅ Supported (CI) |
| WASI | - | ⚠️ Supported (not covered by CI here) |

Platform contexts live in `Sources/Helix/Platform` and are selected via compile-time checks.

### Platform Context

Access platform-specific functionality through `PlatformContext`:

```swift
import Helix

struct PlatformCommand: ParsableCommand {
    mutating func run() async throws {
        // Get arguments
        let args = PlatformContext.current.arguments
        print("Arguments: \(args)")

        // Get environment variable
        if let path = PlatformContext.current.environmentVariable("PATH") {
            print("PATH: \(path)")
        }

        // Current working directory
        let cwd = PlatformContext.current.currentWorkingDirectory
        print("Working directory: \(cwd)")
    }
}
```

### PlatformPath

Cross-platform file path handling:

```swift
let path = PlatformPath("/home/user/documents/file.txt")

// Platform-aware operations
#if os(Windows)
print(path.string)  // Uses backslashes
#else
print(path.string)  // Uses forward slashes
#endif

// Path operations
let parent = path.deletingExtension  // /home/user/documents/file
let ext = path.extension              // "txt"
let joined = path.appending("data")   // /home/user/documents/file.txt/data

// Environment variable expansion
let expanded = path.expandingEnvironmentVariables(["HOME": "/home/user"])

// Home directory
let home = PlatformPath.homeDirectory
```

### Custom Platform Context

Create mock contexts for testing:

```swift
let mockContext = MockPlatformContext(
    arguments: ["test", "--verbose"],
    environment: ["TEST_MODE": "1"],
    currentDirectory: "/test/workspace"
)

// Use in tests
let args = mockContext.arguments  // ["test", "--verbose"]
let env = mockContext.environment  // ["TEST_MODE": "1"]
```

---

## Testing

### Running Tests

```bash
swift test
```

### Test Coverage

| Test File | Coverage |
|-----------|----------|
| `CommandParserTests.swift` | Tokenization, parsing, options, flags |
| `HelpGeneratorTests.swift` | Usage/help formatting |
| `HelpVersionBehaviorTests.swift` | `--help`, `--version`, empty-invocation help |
| `PropertyWrappersTests.swift` | Wrapper initialization and registration |
| `ParsableCommandBindingTests.swift` | End-to-end binding for options/flags/arguments/option groups |
| `PlatformContextTests.swift` | Platform abstraction |
| `PlatformPathTests.swift` | Path operations |
| `StdioTests.swift` | I/O stream handling |

### Mock Platform Context

Use `MockPlatformContext` for deterministic testing:

```swift
let ctx = MockPlatformContext(
    arguments: ["cmd", "arg1", "arg2"],
    environment: ["KEY": "value"],
    currentDirectory: "/test"
)

// Verify environment
XCTAssertEqual(ctx.environmentVariable("KEY"), "value")

// Verify arguments
XCTAssertEqual(ctx.arguments, ["arg1", "arg2"])
```

### Unit Testing Commands

```swift
import XCTest
@testable import Helix

final class MyCommandTests: XCTestCase {
    func testParsing() throws {
        var command = MyCommand()

        // Manually set properties for testing
        command.name = "test"
        command.count = 5

        XCTAssertEqual(command.name, "test")
        XCTAssertEqual(command.count, 5)
    }

    func testValidation() throws {
        var command = MyCommand()
        command.value = -1  // Invalid

        XCTAssertThrowsError(try command.validate())
    }
}
```

---

## API Reference

### ParsableCommand Protocol

```swift
@MainActor
public protocol ParsableCommand: Sendable {
    /// Required initializer
    init()

    /// Command metadata (optional, defaults to auto-generated)
    static var commandDescription: CommandDescription { get }

    /// Main command logic
    mutating func run() async throws

    /// Validation (optional)
    mutating func validate() throws
}

extension ParsableCommand {
    /// Run with arguments from current platform
    static func main() async throws

    /// Run with custom arguments
    static func main(arguments: [String]) async throws

    /// Create a descriptor for this command
    static var descriptor: CommandDescriptor { get }
}
```

Note: `Program.resolve` accepts `argv` with or without the root command name when you initialize `Program` with a single descriptor. If you provide multiple root descriptors, the first argument must select the command. `DefaultPlatformContext.shared.arguments` strips the executable name.

### CommandDescription

```swift
public struct CommandDescription: Sendable {
    public var commandName: String?
    public var abstract: String
    public var discussion: String?
    public var version: String?
    public var subcommands: [any ParsableCommand.Type]
    public var defaultSubcommand: (any ParsableCommand.Type)?
    public var showHelpOnEmptyInvocation: Bool
}
```

### HelixError

```swift
public enum HelixError: Error, Sendable {
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
}
```

### ExitCode

```swift
public struct ExitCode: Error, Equatable, Sendable {
    public let rawValue: Int32
    public static let success = ExitCode(0)
    public static let failure = ExitCode(1)
}
```

### ValidationError

```swift
public struct ValidationError: Error, LocalizedError, Sendable {
    public init(_ message: String)
    public var errorDescription: String? { message }
}
```

---

## Migration Guide

### From Swift ArgumentParser

| ArgumentParser | Helix |
|----------------|-------|
| `ArgumentParser` | `Program` |
| `ParsableCommand` | `ParsableCommand` |
| `Option` | `@Option` |
| `Argument` | `@Argument` |
| `Flag` | `@Flag` |
| `OptionGroup` | `@OptionGroup` |
| `validate()` | `validate()` |

### Key Differences

1. **Command Name**: Helix defaults to the type name (with a trailing `Command` removed). Use `commandName` in `CommandDescription` when you need lowercase CLI names or when relying on `defaultSubcommand`.

2. **Subcommand Registration**: ArgumentParser uses nested types; Helix uses `subcommands` array in `CommandDescription`.

3. **Main Entry**: ArgumentParser uses `@main` attribute; Helix uses `try await MyCommand.main(arguments:)`. If you initialize `Program` with multiple root descriptors, the first argument must select the command. If you initialize `Program` with a single descriptor, `Program.resolve` can also accept `argv` without the root command name.

### Example Migration

**Before (ArgumentParser):**

```swift
import ArgumentParser

struct Math: ParsableCommand {
    @Option(name: .short)
    var operation: String

    @Argument
    var numbers: [Int]

    func run() throws {
        // ...
    }
}
```

**After (Helix):**

```swift
import Helix

struct MathCommand: ParsableCommand {
    @Option(name: .short('o'), help: "Operation")
    var operation: String

    @Argument(help: "Numbers to process")
    var numbers: [Int]

    static var commandDescription: CommandDescription {
        CommandDescription(
            commandName: "math",
            abstract: "Perform mathematical operations"
        )
    }

    mutating func run() async throws {
        // ...
    }
}
```

---

## Best Practices

### 1. Command Organization

```swift
// Group related commands
enum Database {
    struct MigrateCommand: ParsableCommand { /* ... */ }
    struct SeedCommand: ParsableCommand { /* ... */ }
    struct BackupCommand: ParsableCommand { /* ... */ }
}

// Or use namespaces
struct CLI {
    struct Init: ParsableCommand { /* ... */ }
    struct Build: ParsableCommand { /* ... */ }
    struct Test: ParsableCommand { /* ... */ }
}
```

### 2. Error Handling

```swift
enum CLIError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case invalidConfig(String)
    case networkError(Error)

    var description: String {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidConfig(let message):
            return "Invalid configuration: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct MyCommand: ParsableCommand {
    mutating func run() async throws {
        do {
            try await performOperation()
        } catch let error as CLIError {
            print("Error: \(error)")
            throw ExitCode.failure
        }
    }
}
```

### 3. Reusable Option Groups

```swift
struct CommonOptions: HelixParsable {
    @Flag(name: .shortAndLong, help: "Verbose output")
    var verbose: Bool = false

    @Option(name: .short('o'), help: "Output file")
    var output: String?

    @Flag(name: .short('f'), help: "Force overwrite")
    var force: Bool = false
}

struct BuildCommand: ParsableCommand {
    @OptionGroup
    var common: CommonOptions

    @Option(help: "Configuration")
    var config: String = "release"

    mutating func run() async throws {
        if common.verbose {
            print("Configuration: \(config)")
        }
        // ...
    }
}
```

---

## Performance

### Parsing Overhead

Helix is designed for minimal overhead:

- **Reflection**: Only used once during descriptor generation
- **Parsing**: Single-pass tokenizer with O(n) complexity
- **Memory**: No intermediate allocations beyond argument storage

### Large Argument Counts

Helix handles large argument counts efficiently:

```bash
# Process thousands of files
$ process *.txt --output results.json
```

### Concurrency

All commands run on the main actor (`@MainActor`) for thread safety:

```swift
@MainActor
public protocol ParsableCommand: Sendable {
    mutating func run() async throws
}
```

---

## FAQ

### Q: How do I handle secret values?

```swift
struct SecureCommand: ParsableCommand {
    @Option(help: "API key (prefer using env var)")
    var apiKey: String?

    mutating func run() async throws {
        let key = apiKey ?? PlatformContext.current.environmentVariable("API_KEY") ?? ""
        // Use key...
    }
}
```

### Q: Can I use Helix in a synchronous context?

`run()` must be `async throws` to conform to `ParsableCommand`, but you can keep the body synchronous:

```swift
struct SyncCommand: ParsableCommand {
    @Option(help: "Name")
    var name: String

    mutating func run() async throws {
        print("Hello, \(name)!")
    }
}
```

### Q: How do I handle `--help` and `--version`?

Helix supports built-in help and version handling:

- `-h` / `--help` prints help and exits before running command logic.
- `-V` / `--version` prints `CommandDescription.version` (if set) and exits before running command logic.
- `CommandDescription.showHelpOnEmptyInvocation = true` prints help when invoked with no arguments.

```swift
struct MyCommand: ParsableCommand {
    static var commandDescription: CommandDescription {
        CommandDescription(version: "1.0.0", showHelpOnEmptyInvocation: true)
    }

    mutating func run() async throws { /* ... */ }
}
```

### Q: Can I use Helix with Vapor or other server frameworks?

Yes! Helix can be used alongside any Swift framework:

```swift
// In a Vapor route
app.post("run") { req async in
    try await MyCommand.main(arguments: req.body.string.split(separator: " ").map(String.init))
    return "Done"
}
```

---

## Contributing

Contributions are welcome. See `CONTRIBUTING.md`.

### Areas for Contribution

1. Shell completion script generation
2. Help text with ANSI colors and richer formatting
3. Additional type conformances (URL, UUID, Decimal)
4. Cross-platform test coverage (Windows, WASI)
5. More example commands and cookbook patterns

## Security

See `SECURITY.md`.

## Changelog

See `CHANGELOG.md`.

---

## License

Helix is released under the MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

Inspired by:
- [Swift ArgumentParser](https://github.com/apple/swift-argument-parser)

---

<p align="center">Made with ❤️ for the Swift community</p>
