import Foundation

/// Declares a named option (short/long) that can parse arbitrary value types.
@propertyWrapper
public struct Option<Value: ExpressibleFromArgument>: HelixMetadata {
    final class _Box: @unchecked Sendable {
        var value: Value?
        var environmentValue: Value?
        var parsedFromArgs: Bool
        let hasDefault: Bool

        init(value: Value?, environmentValue: Value?, parsedFromArgs: Bool, hasDefault: Bool) {
            self.value = value
            self.environmentValue = environmentValue
            self.parsedFromArgs = parsedFromArgs
            self.hasDefault = hasDefault
        }
    }

    private var box: _Box
    private let nameSpecifications: [NameSpecification]
    private let help: String?
    private let envVar: String?

    /// Returns the stored value, environment value, or nil if optional.
    /// Crashes with a helpful message if accessed before being bound and not optional.
    public var wrappedValue: Value {
        get {
            if let value = box.value { return value }
            if let envValue = box.environmentValue { return envValue }
            // For optional types, return nil
            if Value.self is OptionalProtocol.Type {
                return (nil as Value?)!
            }
            // This should not happen in normal usage - options are bound during parsing
            fatalError("Helix option '\(Value.self)' accessed before being parsed. This is a development error.")
        }
        set {
            self.box.value = newValue
            self.box.parsedFromArgs = true
        }
    }

    public init(wrappedValue: Value, name: NameSpecification = .automatic, help: String? = nil, envVar: String? = nil) {
        self.box = _Box(value: wrappedValue, environmentValue: nil, parsedFromArgs: false, hasDefault: true)
        self.nameSpecifications = [name]
        self.help = help
        self.envVar = envVar
    }

    public init(name: NameSpecification = .automatic, help: String? = nil, envVar: String? = nil) {
        self.box = _Box(value: nil, environmentValue: nil, parsedFromArgs: false, hasDefault: false)
        self.nameSpecifications = [name]
        self.help = help
        self.envVar = envVar
    }

    public init(names: [NameSpecification], help: String? = nil, envVar: String? = nil) {
        self.box = _Box(value: nil, environmentValue: nil, parsedFromArgs: false, hasDefault: false)
        self.nameSpecifications = names
        self.help = help
        self.envVar = envVar
    }

    /// Sets the environment variable value to use as fallback.
    /// This is called by the parser after binding.
    mutating func setEnvironmentValue(_ value: Value?) {
        self.box.environmentValue = value
    }

    /// Returns true if this option was parsed from arguments.
    public var wasParsed: Bool {
        box.parsedFromArgs || box.environmentValue != nil
    }

    public func register(label: String, signature: inout CommandSignature) {
        let resolvedLabel = Self.sanitize(label)
        let resolvedNames = self.nameSpecifications.flatMap { $0.resolve(defaultLabel: resolvedLabel) }
        let definition = OptionDefinition(label: resolvedLabel, names: resolvedNames, help: help, envVar: envVar)
        signature.append(.option(definition))
    }

    private static func sanitize(_ label: String) -> String {
        label.hasPrefix("_") ? String(label.dropFirst()) : label
    }
}

extension Option: Sendable where Value: Sendable {}

/// Declares a positional argument, optionally optional.
@propertyWrapper
public struct Argument<Value: ExpressibleFromArgument>: HelixMetadata {
    final class _Box: @unchecked Sendable {
        var value: Value?
        var parsedFromArgs: Bool
        let hasDefault: Bool

        init(value: Value?, parsedFromArgs: Bool, hasDefault: Bool) {
            self.value = value
            self.parsedFromArgs = parsedFromArgs
            self.hasDefault = hasDefault
        }
    }

    private var box: _Box
    private let help: String?

    /// Returns the stored value or nil if optional.
    /// Crashes with a helpful message if accessed before being bound.
    public var wrappedValue: Value {
        get {
            if let value = box.value { return value }
            // For optional types, return nil
            if Value.self is OptionalProtocol.Type {
                return (nil as Value?)!
            }
            // This should not happen in normal usage
            fatalError("Helix argument '\(Value.self)' accessed before being parsed. This is a development error.")
        }
        set {
            self.box.value = newValue
            self.box.parsedFromArgs = true
        }
    }

    public init(wrappedValue: Value, help: String? = nil) {
        self.box = _Box(value: wrappedValue, parsedFromArgs: false, hasDefault: true)
        self.help = help
    }

    public init(help: String? = nil) {
        self.box = _Box(value: nil, parsedFromArgs: false, hasDefault: false)
        self.help = help
    }

    /// Returns true if this argument was parsed from arguments.
    public var wasParsed: Bool {
        box.parsedFromArgs
    }

    public func register(label: String, signature: inout CommandSignature) {
        let resolvedLabel = Self.sanitize(label)
        let definition = ArgumentDefinition(
            label: resolvedLabel,
            help: help,
            isOptional: Value.self is OptionalProtocol.Type)
        signature.append(.argument(definition))
    }

    private static func sanitize(_ label: String) -> String {
        label.hasPrefix("_") ? String(label.dropFirst()) : label
    }
}

extension Argument: Sendable where Value: Sendable {}

/// Declares a boolean flag that defaults to `false` and toggles to `true` when present.
@propertyWrapper
public struct Flag: HelixMetadata, Sendable {
    final class _Box: @unchecked Sendable {
        var value: Bool
        init(_ value: Bool) { self.value = value }
    }

    private var box: _Box
    private let nameSpecifications: [NameSpecification]
    private let help: String?

    public init(wrappedValue: Bool = false, name: NameSpecification = .automatic, help: String? = nil) {
        self.box = _Box(wrappedValue)
        self.nameSpecifications = [name]
        self.help = help
    }

    public init(wrappedValue: Bool = false, names: [NameSpecification], help: String? = nil) {
        self.box = _Box(wrappedValue)
        self.nameSpecifications = names
        self.help = help
    }

    public var wrappedValue: Bool {
        get { box.value }
        set { box.value = newValue }
    }

    public func register(label: String, signature: inout CommandSignature) {
        let resolvedLabel = Self.sanitize(label)
        let definition = FlagDefinition(
            label: resolvedLabel,
            names: nameSpecifications.flatMap { $0.resolve(defaultLabel: resolvedLabel) },
            help: self.help)
        signature.append(.flag(definition))
    }

    private static func sanitize(_ label: String) -> String {
        label.hasPrefix("_") ? String(label.dropFirst()) : label
    }
}

/// Provides nested Helix metadata so you can keep related parameters together.
@propertyWrapper
public struct OptionGroup<Value: HelixParsable>: HelixOptionGroup {
    final class _Box: @unchecked Sendable {
        var value: Value
        init(_ value: Value) { self.value = value }
    }

    private var box: _Box

    public var wrappedValue: Value {
        get { box.value }
        set { box.value = newValue }
    }

    public init(wrappedValue: Value) {
        self.box = _Box(wrappedValue)
    }

    public init() where Value: HelixParsable {
        self.box = _Box(Value())
    }

    public func register(label: String, signature: inout CommandSignature) {
        let groupSignature = CommandSignature.describe(self.wrappedValue)
        signature.append(.group(groupSignature))
    }
}

extension OptionGroup: Sendable where Value: Sendable {}

/// Marker protocol for option-group structs.
public protocol HelixParsable {
    init()
}

protocol HelixMetadata {
    func register(label: String, signature: inout CommandSignature)
}

protocol HelixOptionGroup {
    func register(label: String, signature: inout CommandSignature)
}

protocol DefaultInitializable {
    init()
}

/// Note: HelixParsable already requires init(), so no additional implementation is needed.
/// This protocol exists for potential future use cases.

protocol OptionalProtocol {}
extension Optional: OptionalProtocol {}

// MARK: - Binding conformance

protocol _HelixOptionMultiValueParser {
    static func _helixParseOption(values: [String]) -> Any?
}

protocol _HelixPositionalArrayParser {
    static func _helixParsePositional(values: [String]) -> Any?
}

extension Array: _HelixOptionMultiValueParser where Element: ExpressibleFromArgument {
    static func _helixParseOption(values: [String]) -> Any? {
        var result: [Element] = []
        for value in values {
            let parts = value.split(separator: ",").map(String.init)
            for part in parts {
                guard let parsed = Element(argument: part) else { return nil }
                result.append(parsed)
            }
        }
        return result
    }
}

extension Array: _HelixPositionalArrayParser where Element: ExpressibleFromArgument {
    static func _helixParsePositional(values: [String]) -> Any? {
        var result: [Element] = []
        for value in values {
            guard let parsed = Element(argument: value) else { return nil }
            result.append(parsed)
        }
        return result
    }
}

extension Option: _HelixOptionBinding {
    mutating func _helixBindOption(label: String, values: [String]?, environment: [String: String]) throws {
        if let values, !values.isEmpty {
            if let parser = Value.self as? _HelixOptionMultiValueParser.Type {
                guard let parsed = parser._helixParseOption(values: values) as? Value else {
                    throw HelixError.parsingError("Invalid value for option \(label)")
                }
                box.value = parsed
            } else {
                guard let last = values.last, let parsed = Value(argument: last) else {
                    throw HelixError.parsingError("Invalid value for option \(label)")
                }
                box.value = parsed
            }
            box.parsedFromArgs = true
            return
        }

        if let envVar, let envValue = environment[envVar] {
            guard let parsed = Value(argument: envValue) else {
                throw HelixError.parsingError("Invalid value for environment variable \(envVar)")
            }
            box.environmentValue = parsed
        }

        let isOptional = Value.self is OptionalProtocol.Type
        if !isOptional, !box.hasDefault, box.value == nil, box.environmentValue == nil {
            throw HelixError.parsingError("Missing value for option \(label)")
        }
    }
}

extension Argument: _HelixArgumentBinding {
    mutating func _helixBindArgument(label: String, positional: [String], index: inout Int, isLast: Bool) throws {
        if let parser = Value.self as? _HelixPositionalArrayParser.Type {
            guard isLast else {
                throw HelixError.parsingError("Variadic argument \(label) must be last")
            }
            let remaining = index < positional.count ? Array(positional[index...]) : []
            guard let parsed = parser._helixParsePositional(values: remaining) as? Value else {
                throw HelixError.parsingError("Invalid value for argument \(label)")
            }
            box.value = parsed
            box.parsedFromArgs = true
            index = positional.count
            return
        }

        if index >= positional.count {
            let isOptional = Value.self is OptionalProtocol.Type
            if isOptional || box.hasDefault {
                return
            }
            throw HelixError.parsingError("Missing argument \(label)")
        }

        let raw = positional[index]
        index += 1
        guard let parsed = Value(argument: raw) else {
            throw HelixError.parsingError("Invalid value for argument \(label)")
        }
        box.value = parsed
        box.parsedFromArgs = true
    }
}

extension Flag: _HelixFlagBinding {
    mutating func _helixBindFlag(label: String, flags: Set<String>) {
        if flags.contains(label) {
            box.value = true
        }
    }
}

extension OptionGroup: _HelixOptionGroupBinding {
    mutating func _helixBindGroup(parsed: ParsedValues, environment: [String: String]) throws {
        try _HelixBinder.bindGroupValue(wrappedValue, parsed: parsed, environment: environment)
    }
}
