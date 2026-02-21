import Foundation

// Internal binding layer that connects ParsedValues to property wrappers.
// This intentionally avoids Swift SPI/private reflection by using box-backed
// wrapper storage. Mirror copies can still mutate shared box instances.

protocol _HelixOptionBinding {
    mutating func _helixBindOption(label: String, values: [String]?, environment: [String: String]) throws
}

protocol _HelixArgumentBinding {
    mutating func _helixBindArgument(label: String, positional: [String], index: inout Int, isLast: Bool) throws
}

protocol _HelixFlagBinding {
    mutating func _helixBindFlag(label: String, flags: Set<String>)
}

protocol _HelixOptionGroupBinding {
    mutating func _helixBindGroup(parsed: ParsedValues, environment: [String: String]) throws
}

enum _HelixBinder {
    static func bindCommand<Command>(
        _ command: inout Command,
        parsed: ParsedValues,
        environment: [String: String]
    ) throws {
        var argumentBinders: [(label: String, bind: (inout Int, Bool) throws -> Void)] = []

        try walk(
            command,
            parsed: parsed,
            environment: environment,
            allowArguments: true,
            argumentBinders: &argumentBinders
        )

        var index = 0
        for i in 0..<argumentBinders.count {
            let isLast = (i == argumentBinders.count - 1)
            try argumentBinders[i].bind(&index, isLast)
        }

        if index < parsed.positional.count {
            let extras = parsed.positional[index...].joined(separator: " ")
            throw HelixError.parsingError("Unexpected arguments: \(extras)")
        }
    }

    static func bindGroupValue<Group>(
        _ group: Group,
        parsed: ParsedValues,
        environment: [String: String]
    ) throws {
        var argumentBinders: [(label: String, bind: (inout Int, Bool) throws -> Void)] = []
        try walk(
            group,
            parsed: parsed,
            environment: environment,
            allowArguments: false,
            argumentBinders: &argumentBinders
        )
    }

    private static func walk<Value>(
        _ value: Value,
        parsed: ParsedValues,
        environment: [String: String],
        allowArguments: Bool,
        argumentBinders: inout [(label: String, bind: (inout Int, Bool) throws -> Void)]
    ) throws {
        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            guard let rawLabel = child.label else { continue }
            let label = sanitize(rawLabel)

            if var option = child.value as? _HelixOptionBinding {
                try option._helixBindOption(label: label, values: parsed.options[label], environment: environment)
                continue
            }

            if var flag = child.value as? _HelixFlagBinding {
                flag._helixBindFlag(label: label, flags: parsed.flags)
                continue
            }

            if let argument = child.value as? _HelixArgumentBinding {
                if !allowArguments {
                    throw HelixError.parsingError("Positional arguments are not supported in option groups")
                }
                argumentBinders.append(
                    (label: label, bind: { index, isLast in
                        var local = argument
                        try local._helixBindArgument(label: label, positional: parsed.positional, index: &index, isLast: isLast)
                    })
                )
                continue
            }

            if var group = child.value as? _HelixOptionGroupBinding {
                try group._helixBindGroup(parsed: parsed, environment: environment)
                continue
            }
        }
    }

    private static func sanitize(_ label: String) -> String {
        label.hasPrefix("_") ? String(label.dropFirst()) : label
    }
}
