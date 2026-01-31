# Runic CLI Commands - Quick Reference

Quick reference guide for all Runic CLI tracking commands.

## Command Overview

| Command | Purpose | Key Options |
|---------|---------|-------------|
| `models` | Model usage breakdown | `--provider`, `--days`, `--by-project` |
| `projects` | Project tracking | `--list`, `--stats`, `--sort-name` |
| `alerts` | Usage alerts | `--active`, `--history`, `--clear` |
| `reset` | Reset timings | `--when`, `--all`, `--compact` |
| `usage-enhanced` | Enhanced usage | `--mode`, `--compare`, `--projected` |

## Global Options

Available on all commands:
- `--json`, `-j` - JSON output
- `--pretty` - Pretty-print JSON
- `--no-color` - Disable colors
- `--help`, `-h` - Show help

## Command Details

### runic models

Show which AI models were used and their token consumption.

```bash
# Basic usage
runic models

# Filter by provider
runic models --provider claude
runic models -p codex

# Time range
runic models --days 7
runic models -d 30

# Group by project
runic models --by-project

# JSON output
runic models --json --pretty
```

**Output:** Table showing model name, provider, tokens, requests, and cost.

---

### runic projects

Track usage across different projects and codebases.

```bash
# List all projects
runic projects
runic projects --list
runic projects -l

# Show stats for specific project
runic projects --stats my-project-id
runic projects -s my-project-id

# Sort options
runic projects --sort-name     # Alphabetical
runic projects --sort-tokens   # By usage (default)

# Filter
runic projects --provider claude --days 7
```

**Output:**
- List mode: Table of all projects
- Stats mode: Detailed project breakdown

---

### runic alerts

Manage usage threshold alerts.

```bash
# Show active alerts
runic alerts
runic alerts --active
runic alerts -a

# View history
runic alerts --history
runic alerts -h

# Clear resolved alerts
runic alerts --clear
runic alerts -c

# Filter by provider
runic alerts --provider claude
runic alerts -p codex
```

**Output:** List of alerts with severity levels.

**Alert Levels:**
- ✗ Critical (>90% used) - Red
- ⚠ Warning (>75% used) - Yellow
- ℹ Info (>50% used) - Cyan

---

### runic reset

Show when usage limits reset.

```bash
# Show all providers
runic reset
runic reset --all
runic reset -a

# Specific provider
runic reset --when claude
runic reset -w codex

# Compact output
runic reset --compact
runic reset -c

# JSON output
runic reset --json --pretty
```

**Output:** Reset times and countdown for each provider window.

**Status Indicators:**
- ✓ Healthy (<50% used) - Green
- ◐ Moderate (50-75%) - Cyan
- ⚠ Warning (75-90%) - Yellow
- ✗ Critical (>90%) - Red

---

### runic usage-enhanced

Enhanced usage display with analytics.

```bash
# Display modes
runic usage-enhanced                      # Summary (default)
runic usage-enhanced --mode summary       # Quick overview
runic usage-enhanced --mode detailed      # Full breakdown
runic usage-enhanced --mode breakdown     # Token types
runic usage-enhanced --mode trending      # Historical trends

# Options
runic usage-enhanced --show-cost          # Include costs
runic usage-enhanced --projected          # Show projections
runic usage-enhanced --compare            # Compare providers

# Time range for trending
runic usage-enhanced --mode trending --days 30

# Filter by provider
runic usage-enhanced --provider claude -m detailed
```

**Display Modes:**
- **summary**: Quick overview with progress bars
- **detailed**: Full window breakdown with reset times
- **breakdown**: Token type analysis (input/output/cache)
- **trending**: Historical usage trends

---

## Common Workflows

### Daily Usage Check
```bash
# Quick summary
runic usage-enhanced

# Check for alerts
runic alerts

# See when limits reset
runic reset --compact
```

### Weekly Analysis
```bash
# Last 7 days by model
runic models --days 7 --json > models-weekly.json

# Project breakdown
runic projects --days 7

# Trending analysis
runic usage-enhanced --mode trending --days 7
```

### Project Tracking
```bash
# List all projects
runic projects --list

# Detailed project stats
runic projects --stats my-project

# Models used in project
runic models --days 30 | grep my-project
```

### Cost Monitoring
```bash
# Enhanced usage with costs
runic usage-enhanced --mode detailed --show-cost

# Models by cost
runic models --json | jq 'sort_by(.cost)'

# Alert when high usage
runic alerts --active
```

### Export for Analysis
```bash
# Export all data to JSON
runic models --json --pretty > models.json
runic projects --json --pretty > projects.json
runic reset --json --pretty > reset-times.json

# Trending data
runic usage-enhanced --mode trending --days 30 --json > trends.json
```

## Output Formats

### Text Output (Default)

Colorized tables with:
- Headers in cyan
- High usage in red/yellow
- Healthy usage in green
- Progress bars for visualization

### JSON Output

Structured data for:
- Scripting and automation
- Data processing
- Integration with other tools
- Long-term storage

Use `--json` for compact JSON
Use `--json --pretty` for formatted JSON

## Tips and Tricks

### 1. Pipe to jq for JSON Processing
```bash
runic models --json | jq '.[] | select(.provider=="claude")'
```

### 2. Watch for Changes
```bash
watch -n 60 'runic alerts --active'
```

### 3. Create Aliases
```bash
alias runic-check='runic usage-enhanced && runic alerts'
alias runic-weekly='runic models --days 7'
```

### 4. Combine with Other Tools
```bash
# Export to CSV
runic models --json | jq -r '.[] | [.model, .tokens, .cost] | @csv'

# Send alerts via notification
runic alerts --active | mail -s "Usage Alerts" user@example.com
```

### 5. Scripting Examples
```bash
#!/bin/bash
# Check if usage is critical
ALERTS=$(runic alerts --json | jq 'map(select(.severity >= 3)) | length')
if [ "$ALERTS" -gt 0 ]; then
    echo "Critical usage alerts detected!"
    runic alerts --active
fi
```

## Troubleshooting

### No data available
- Check provider credentials
- Verify usage logs exist
- Try `--days` with larger value

### Colors not working
- Use `--no-color` flag
- Check terminal supports ANSI codes
- Set `TERM` environment variable

### Slow performance
- Reduce `--days` range
- Use `--provider` to filter
- Consider caching results

### JSON parsing errors
- Use `--pretty` for debugging
- Validate with `jq`
- Check command syntax

## Environment Variables

Set these for customization:
```bash
export RUNIC_NO_COLOR=1           # Disable colors
export RUNIC_DEFAULT_DAYS=30      # Default time range
export RUNIC_DEFAULT_FORMAT=json  # Default output format
```

## Exit Codes

- `0` - Success
- `1` - Error (invalid arguments, no data, etc.)

## Getting Help

```bash
# Global help
runic --help

# Command-specific help
runic models --help
runic projects --help
runic alerts --help
runic reset --help
runic usage-enhanced --help
```

## Version Information

```bash
runic --version
```

## Additional Resources

- Full documentation: See README.md
- Integration guide: See INTEGRATION_GUIDE.md
- Source code: Sources/RunicCLI/Commands/
- Examples: Check command help text

---

**Last Updated:** 2026-01-31
**Runic CLI Version:** 1.0.0
