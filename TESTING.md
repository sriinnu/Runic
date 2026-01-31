# Runic Testing Guide

## Comprehensive Test Script

The `test-all.sh` script provides a comprehensive verification of all Runic components.

### Quick Start

```bash
# From the project root
./test-all.sh
```

### What It Tests

The script performs 7 major test suites:

#### 1. File Integrity & Structure
- Verifies critical files exist (Package.swift, README.md, LICENSE, etc.)
- Checks for important directories
- Scans for broken symbolic links

#### 2. Git Repository Health
- Confirms git repository initialization
- Reports uncommitted changes
- Displays current branch
- Validates .gitignore

#### 3. Swift macOS Application
- Builds the Swift package in release mode
- Checks for compilation errors
- Verifies Package.swift configuration

#### 4. Swift iOS Components
- Scans RuniciOS directory for Swift files
- Validates SwiftUI and WidgetKit imports
- Reports component structure

#### 5. API Server (Node.js/TypeScript)
- Installs npm dependencies
- Runs TypeScript type checking (`tsc --noEmit`)
- Verifies project structure and configuration

#### 6. MCP Servers
Tests all three MCP servers individually:
- **persistence-server**: State management and data sync
- **intuition-server**: Pattern recognition and insights
- **consciousness-server**: Advanced AI coordination

For each server:
- Installs dependencies
- Runs TypeScript compilation check
- Verifies source files exist

#### 7. React Native Cross-Platform App
- Installs React Native dependencies
- Runs TypeScript type checking
- Validates Metro and Babel configurations
- Checks for Android and Windows platform directories

### Output Format

The script provides colored, formatted output:

- **Green ✓**: Test passed
- **Red ✗**: Test failed
- **Yellow ⚠**: Warning (non-critical)
- **Blue ▶**: Test in progress
- **Cyan ℹ**: Informational message

### Exit Codes

- `0`: All tests passed (warnings allowed)
- `1`: One or more tests failed

### Example Output

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           RUNIC COMPREHENSIVE TEST SUITE                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

ℹ Project root: /Users/you/Runic
ℹ Starting comprehensive test suite...

═══════════════════════════════════════════════════════════════
  Test 1: File Integrity & Structure
═══════════════════════════════════════════════════════════════

✓ Found Package.swift
✓ Found README.md
✓ Found LICENSE
...

═══════════════════════════════════════════════════════════════
  Test Summary
═══════════════════════════════════════════════════════════════

Results:
  ✓ Passed:  45
  ✗ Failed:  0
  ⚠ Warnings: 2
  ━━━━━━━━━━━━
  Total:    47

Success Rate: 95%

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                  🎉 ALL TESTS PASSED! 🎉                      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

### Troubleshooting

#### Swift Build Errors

If Swift builds fail:
```bash
# Clean build artifacts
rm -rf .build

# Try building manually
swift build --configuration release
```

#### TypeScript Errors

If TypeScript compilation fails:
```bash
# Clean and reinstall dependencies
cd api-server  # or mcp-servers/*, runic-cross-platform
rm -rf node_modules package-lock.json
npm install
npx tsc --noEmit
```

#### React Native Issues

```bash
cd runic-cross-platform

# Clean React Native cache
rm -rf node_modules
npx react-native start --reset-cache

# Reinstall dependencies
npm install
```

### CI/CD Integration

The script is designed to work in CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run comprehensive tests
  run: ./test-all.sh
```

```yaml
# GitLab CI example
test:
  script:
    - chmod +x test-all.sh
    - ./test-all.sh
```

### Development Workflow

Recommended usage during development:

1. **Before committing**: Run `./test-all.sh` to catch issues early
2. **After merging**: Verify all components still work together
3. **Before releases**: Ensure full test suite passes
4. **On pull requests**: Automated CI runs validate changes

### Advanced Usage

#### Running Individual Tests

You can modify the script to run specific tests by commenting out test functions in the `main()` function:

```bash
# Edit test-all.sh
main() {
    # test_file_integrity
    # test_git_health
    test_swift_macos      # Only run this
    # test_swift_ios
    # test_api_server
    # test_mcp_servers
    # test_react_native
}
```

#### Verbose Output

The script already provides detailed output. For even more details, modify individual test functions to remove output redirection:

```bash
# Change this:
npm install --silent --no-progress > /dev/null 2>&1

# To this:
npm install
```

### Performance Notes

- **Swift build**: 30-120 seconds (first run, or after clean)
- **npm installs**: 10-30 seconds per project (if node_modules exists)
- **TypeScript checks**: 5-10 seconds per project
- **Total runtime**: 2-5 minutes (varies by system and cache state)

### Prerequisites

Ensure you have these tools installed:

- **Swift**: 6.2 or later
- **Node.js**: 18 or later
- **npm**: 9 or later
- **TypeScript**: Installed via npm
- **Git**: Any recent version

Check versions:
```bash
swift --version
node --version
npm --version
git --version
```

### Continuous Improvement

The test script is designed to be extended. To add new tests:

1. Create a new test function following the pattern
2. Add it to the `main()` function
3. Use the logging functions for consistent output
4. Update this documentation

### Related Documentation

- [Architecture](./ARCHITECTURE.md) - System architecture overview
- [Integration Guide](./INTEGRATION_GUIDE.md) - Component integration details
- [Project Summary](./PROJECT_SUMMARY.md) - High-level project overview
- [MCP Servers](./mcp-servers/README.md) - MCP server documentation
