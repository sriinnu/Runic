# Runic CLI Commands

This directory contains the new tracking commands for the Runic CLI, providing enhanced usage monitoring and analytics capabilities.

## Commands Overview

### 1. ModelsCommand.swift
**Command:** `runic models`

Shows which AI models were used across different providers, with token consumption and cost breakdown.

**Features:**
- Filter by provider
- Time-based filtering (last N days)
- JSON output support
- Colorized table output
- Group by project option

**Examples:**
```bash
# Show all models used in the last 30 days
runic models

# Filter by provider
runic models --provider claude --days 7

# Group by project with JSON output
runic models --by-project --json --pretty
```

### 2. ProjectsCommand.swift
**Command:** `runic projects`

Track usage across different projects and codebases.

**Features:**
- List all projects with summary stats
- Detailed stats for specific projects
- Sort by tokens or name
- Provider filtering
- JSON output support

**Examples:**
```bash
# List all projects
runic projects

# Show detailed stats for a specific project
runic projects --stats my-project-id

# Filter by provider and time
runic projects --provider claude --days 7 --sort-name
```

### 3. AlertsCommand.swift
**Command:** `runic alerts`

Manage usage threshold alerts to monitor token consumption.

**Features:**
- Show active alerts
- View alert history
- Clear resolved alerts
- Provider-specific alerts
- Severity levels (critical, warning, info)

**Examples:**
```bash
# Show active alerts
runic alerts

# View alert history
runic alerts --history

# Filter by provider
runic alerts --provider claude

# Clear resolved alerts
runic alerts --clear
```

### 4. ResetCommand.swift
**Command:** `runic reset`

Display when usage limits reset for different providers.

**Features:**
- Show reset times for all providers
- Provider-specific reset info
- Compact or detailed output
- Status indicators
- Time remaining calculations

**Examples:**
```bash
# Show reset times for all providers
runic reset

# Show specific provider reset info
runic reset --when claude

# Compact output
runic reset --compact --no-color
```

### 5. EnhancedUsageCommand.swift
**Command:** `runic usage-enhanced`

Enhanced version of the usage command with analytics and trending.

**Features:**
- Multiple display modes (summary, detailed, breakdown, trending)
- Historical trending analysis
- Cost projections
- Provider comparison
- Projected usage calculations

**Examples:**
```bash
# Quick summary
runic usage-enhanced --mode summary

# Detailed breakdown with cost
runic usage-enhanced --mode detailed --show-cost

# Show 30-day trends
runic usage-enhanced --mode trending --days 30

# Compare providers
runic usage-enhanced --compare --json
```

## Integration with CLIEntry.swift

To integrate these commands into the main CLI, update `/Users/srinivaspendela/Sriinnu/AI/Runic/Sources/RunicCLI/CLIEntry.swift`:

### Step 1: Import the Commands

Add at the top of CLIEntry.swift:
```swift
// Import new command modules
import struct Commands.ModelsCommand
import struct Commands.ProjectsCommand
import struct Commands.AlertsCommand
import struct Commands.ResetCommand
import struct Commands.EnhancedUsageCommand
```

### Step 2: Register Command Descriptors

Add the descriptors to the Program initialization (around line 77):

```swift
let program = Program(descriptors: [
    usageDescriptor,
    costDescriptor,
    insightsDescriptor,
    // Add new commands
    ModelsCommand.descriptor,
    ProjectsCommand.descriptor,
    AlertsCommand.descriptor,
    ResetCommand.descriptor,
    EnhancedUsageCommand.descriptor,
])
```

### Step 3: Handle Command Invocations

Add cases to the switch statement (around line 82):

```swift
switch invocation.descriptor.name {
case "usage":
    await self.runUsage(invocation)
case "cost":
    await self.runCost(invocation)
case "insights":
    await self.runInsights(invocation)
case "models":
    await ModelsCommand.run(invocation)
case "projects":
    await ProjectsCommand.run(invocation)
case "alerts":
    await AlertsCommand.run(invocation)
case "reset":
    await ResetCommand.run(invocation)
case "usage-enhanced":
    await EnhancedUsageCommand.run(invocation)
default:
    Self.exit(code: 1, message: "Unknown command")
}
```

### Step 4: Update Help Text

Update the `printHelp` function to include the new commands:

```swift
private static func printHelp(for command: String?) {
    // ... existing help text ...

    if command == "models" || command == nil {
        print("models - Show model usage breakdown across providers")
        print("  Options:")
        print("    --provider, -p PROVIDER  Filter by provider")
        print("    --days, -d DAYS          Number of days to analyze (default: 30)")
        print("    --json, -j               Output in JSON format")
        print("    --pretty                 Pretty-print JSON output")
        print("    --no-color               Disable ANSI colors")
        print("    --by-project             Group results by project")
    }

    if command == "projects" || command == nil {
        print("projects - Track usage across different projects")
        print("  Options:")
        print("    --stats, -s PROJECT      Show stats for specific project")
        print("    --provider, -p PROVIDER  Filter by provider")
        print("    --days, -d DAYS          Number of days to analyze")
        print("    --json, -j               Output in JSON format")
        print("    --pretty                 Pretty-print JSON output")
        print("    --sort-tokens            Sort by token usage (default)")
        print("    --sort-name              Sort alphabetically")
    }

    if command == "alerts" || command == nil {
        print("alerts - Manage usage threshold alerts")
        print("  Options:")
        print("    --provider, -p PROVIDER  Filter alerts by provider")
        print("    --active, -a             Show only active alerts")
        print("    --history, -h            Show alert history")
        print("    --clear, -c              Clear resolved alerts")
        print("    --json, -j               Output in JSON format")
    }

    if command == "reset" || command == nil {
        print("reset - Show when usage limits reset")
        print("  Options:")
        print("    --when, -w PROVIDER      Show reset for specific provider")
        print("    --all, -a                Show all providers (default)")
        print("    --compact, -c            Show compact output")
        print("    --json, -j               Output in JSON format")
    }

    if command == "usage-enhanced" || command == nil {
        print("usage-enhanced - Enhanced usage display with analytics")
        print("  Options:")
        print("    --mode, -m MODE          Display mode: summary|detailed|breakdown|trending")
        print("    --provider, -p PROVIDER  Filter by provider")
        print("    --days, -d DAYS          Number of days for trending (default: 7)")
        print("    --show-cost              Include cost information")
        print("    --projected              Show projected usage")
        print("    --compare                Compare usage across providers")
    }
}
```

## Common Features

All commands share these common features:

### Output Formats
- **Text**: Human-readable, colorized output (default)
- **JSON**: Machine-readable output with `--json` flag
- **Pretty JSON**: Formatted JSON with `--pretty` flag

### Color Support
- Automatic color detection
- Disable with `--no-color` flag
- Color coding based on severity/usage levels:
  - Green: Healthy/low usage
  - Yellow: Warning/medium usage
  - Red: Critical/high usage
  - Cyan: Headers and highlights
  - Magenta: Very high usage

### Error Handling
- Clear error messages to stderr
- Non-zero exit codes on failure
- Helpful error descriptions

## File Structure

```
Sources/RunicCLI/Commands/
├── README.md                    # This file
├── ModelsCommand.swift          # Model usage breakdown (287 lines)
├── ProjectsCommand.swift        # Project tracking (402 lines)
├── AlertsCommand.swift          # Usage alerts (388 lines)
├── ResetCommand.swift           # Reset timing info (364 lines)
└── EnhancedUsageCommand.swift   # Enhanced usage display (479 lines)
```

## Implementation Notes

### Design Patterns
- **Enum-based commands**: Each command is a public enum with static methods
- **Configuration structs**: Internal configuration parsing
- **Helix integration**: Uses CommandSignature and CommandDescriptor
- **Async/await**: All data loading is asynchronous
- **Type safety**: Leverages Swift's type system

### Dependencies
- **RunicCore**: Core models and data fetchers
- **Helix**: Command-line argument parsing
- **Foundation**: Standard Swift library

### Data Sources
- **Live API**: Fetches current usage from provider APIs
- **Usage Logs**: Reads historical data from local logs
- **Aggregators**: Uses UsageLedgerAggregator for analytics

## Testing

### Manual Testing
```bash
# Build the CLI
swift build

# Test each command
.build/debug/RunicCLI models
.build/debug/RunicCLI projects --list
.build/debug/RunicCLI alerts
.build/debug/RunicCLI reset --all
.build/debug/RunicCLI usage-enhanced --mode summary

# Test JSON output
.build/debug/RunicCLI models --json --pretty
```

### Integration Testing
Test the commands work with existing CLI infrastructure:
1. Help text display
2. Unknown command handling
3. Error messages
4. Exit codes
5. Color output

## Future Enhancements

Potential improvements for future versions:

1. **Persistent Alert Storage**: Store alert history in a database
2. **Custom Thresholds**: Allow users to set custom alert thresholds
3. **Export Capabilities**: Export data to CSV, Excel, etc.
4. **Visualization**: ASCII charts for trending data
5. **Budget Tracking**: Set and track spending budgets
6. **Notifications**: Integration with notification systems
7. **Report Generation**: Automated usage reports
8. **Multi-language Support**: i18n for help text and messages

## License

These commands are part of the Runic project and follow the same license as the main project.

## Support

For issues or questions:
1. Check this README
2. Review the command help text with `--help`
3. Check the main Runic documentation
4. File an issue in the project repository
