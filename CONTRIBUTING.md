# Contributing to Runic

Thank you for your interest in contributing to Runic! This document provides guidelines and instructions for contributing.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Code Quality Standards](#code-quality-standards)
- [Pull Request Process](#pull-request-process)
- [Testing Guidelines](#testing-guidelines)

---

## 📜 Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors.

### Our Standards

- ✅ Use welcoming and inclusive language
- ✅ Be respectful of differing viewpoints and experiences
- ✅ Accept constructive criticism gracefully
- ✅ Focus on what is best for the community
- ✅ Show empathy towards other community members

### Unacceptable Behavior

- ❌ Harassment, trolling, or derogatory comments
- ❌ Personal or political attacks
- ❌ Publishing others' private information
- ❌ Unprofessional conduct

---

## 🤝 How Can I Contribute?

### Reporting Bugs

Before creating a bug report:
1. Check existing issues to avoid duplicates
2. Collect relevant information (OS, version, steps to reproduce)
3. Include error messages and logs if applicable

**Bug Report Template:**
```markdown
**Description**: Clear description of the bug
**Steps to Reproduce**:
1. Step one
2. Step two
3. ...

**Expected Behavior**: What should happen
**Actual Behavior**: What actually happens
**Environment**:
- OS: macOS 14.0
- Version: Runic 2.0
- Platform: macOS/iOS/Windows/Android
```

### Suggesting Enhancements

Enhancement suggestions are welcome! Please include:
- Clear use case description
- Why this enhancement would be useful
- Potential implementation approach (if you have ideas)

### Security Issues

**DO NOT** open public issues for security vulnerabilities. Instead:
1. Review [SECURITY_AUDIT.md](SECURITY_AUDIT.md)
2. Email security concerns privately
3. Allow reasonable time for fixes before disclosure

---

## 💻 Development Setup

### Prerequisites

- **macOS/iOS**: Xcode 15.0+, Swift 6.2+
- **Windows/Android**: Node.js 18+, React Native CLI
- **API/MCP**: Node.js 18+, TypeScript 5.7+
- **Git**: For version control

### Initial Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/Runic.git
cd Runic

# Add upstream remote
git remote add upstream https://github.com/sriinnu/Runic.git

# Setup all platforms
./Scripts/setup-all.sh

# Run tests to verify setup
./test-all.sh
```

### Building Components

```bash
# macOS app (complete build with frameworks)
./Scripts/build-macos.sh --skip-tests

# Swift CLI tool only
swift build

# API Server
cd api-server && npm install && npx tsc

# MCP Servers
cd mcp-servers && ./setup.sh

# React Native
cd runic-cross-platform && npm install
```

---

## ✨ Code Quality Standards

### Swift Code

**Documentation:**
```swift
/// Brief description of what this function does
///
/// - Parameters:
///   - param1: Description of param1
///   - param2: Description of param2
/// - Returns: Description of return value
/// - Throws: Description of errors that can be thrown
func myFunction(param1: String, param2: Int) throws -> Bool {
    // Implementation
}
```

**File Size:**
- Maximum 300 lines per Swift file
- Split large files into logical modules

**Concurrency:**
```swift
// ✅ Good - Explicit concurrency
actor MyActor {
    func doSomething() async throws { }
}

// ❌ Bad - No concurrency annotation
class MyClass {
    func doSomething() { /* async work */ }
}
```

### TypeScript Code

**Documentation:**
```typescript
/**
 * Brief description of the function
 *
 * @param param1 - Description of param1
 * @param param2 - Description of param2
 * @returns Description of return value
 * @throws Description of errors
 */
function myFunction(param1: string, param2: number): boolean {
  // Implementation
}
```

**File Size:**
- Maximum 400 lines per TypeScript file
- Use module splitting for large files

**Type Safety:**
```typescript
// ✅ Good - Strict typing
interface User {
  id: string;
  name: string;
  email: string;
}

function getUser(id: string): User {
  // Implementation
}

// ❌ Bad - Using 'any'
function getUser(id: any): any {
  // Implementation
}
```

### General Guidelines

1. **No Secrets in Code**
   - Never commit API keys, tokens, or credentials
   - Use environment variables or Keychain
   - Check .gitignore before committing

2. **Error Handling**
   - Always handle errors gracefully
   - Log errors appropriately (never log tokens!)
   - Provide user-friendly error messages

3. **Performance**
   - Keep UI responsive (60 FPS target)
   - Minimize network requests
   - Cache data appropriately

4. **Security**
   - Store credentials in Keychain
   - Use HTTPS only
   - No token logging
   - Validate all inputs

---

## 🔀 Pull Request Process

### Before Submitting

1. **Update from upstream:**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run all tests:**
   ```bash
   ./test-all.sh
   ```

3. **Verify no sensitive data:**
   ```bash
   git diff --cached | grep -i "api.*key\|token\|secret"
   ```

### PR Checklist

- [ ] Code follows style guidelines
- [ ] All files have appropriate documentation
- [ ] No file exceeds size limits (300-400 lines)
- [ ] All tests pass (`./test-all.sh`)
- [ ] No compiler warnings
- [ ] No sensitive data in commit
- [ ] Commit messages are clear and descriptive

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change
- [ ] Documentation update

## Testing
How was this tested?

## Screenshots (if UI changes)
Add screenshots here

## Checklist
- [ ] Code follows guidelines
- [ ] All tests pass
- [ ] Documentation updated
```

### Review Process

1. Automated CI checks must pass
2. At least one maintainer review required
3. All review comments addressed
4. Squash commits before merge (if requested)

---

## 🧪 Testing Guidelines

### Running Tests

```bash
# All tests
./test-all.sh

# Swift only
swift test

# TypeScript (API Server)
cd api-server && npm test

# TypeScript (MCP Servers)
cd mcp-servers/persistence-server && npm test

# React Native
cd runic-cross-platform && npm test
```

### Writing Tests

**Swift:**
```swift
import XCTest
@testable import RunicCore

final class MyTests: XCTestCase {
    func testExample() throws {
        let result = myFunction()
        XCTAssertEqual(result, expectedValue)
    }
}
```

**TypeScript:**
```typescript
import { describe, it, expect } from '@jest/globals';

describe('MyModule', () => {
  it('should do something', () => {
    const result = myFunction();
    expect(result).toBe(expectedValue);
  });
});
```

### Test Coverage

- Aim for 80%+ code coverage
- Test edge cases and error conditions
- Mock external dependencies
- No tests should require network access

---

## 📝 Commit Message Guidelines

### Format

```
<type>: <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

### Examples

```bash
# Good
feat: Add model usage tracking to CLI

Added new 'models' command to CLI that shows usage breakdown
by AI model. Includes JSON output mode and filtering options.

Closes #123

# Bad
update stuff
```

---

## 🎨 Code Style

### Swift

Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

```swift
// ✅ Good
func fetchUserData(for userID: String) async throws -> User

// ❌ Bad
func FetchUserData(userID: String) -> User
```

### TypeScript

Follow [TypeScript Coding Guidelines](https://github.com/Microsoft/TypeScript/wiki/Coding-guidelines)

```typescript
// ✅ Good
async function fetchUserData(userId: string): Promise<User>

// ❌ Bad
function FetchUserData(userID: any)
```

---

## 🏗️ Architecture Decisions

When making architectural decisions:

1. **Document the decision** in appropriate markdown file
2. **Consider multi-platform impact** - will this work on all platforms?
3. **Security implications** - does this affect security?
4. **Performance impact** - benchmarks if significant
5. **Breaking changes** - document and version appropriately

---

## 📬 Communication

### Where to Ask Questions

- **General Questions**: GitHub Discussions
- **Bug Reports**: GitHub Issues
- **Feature Requests**: GitHub Issues (with `enhancement` label)
- **Security**: Private email (see SECURITY_AUDIT.md)

### Response Times

- We aim to respond to issues within 48 hours
- Pull requests reviewed within 1 week
- Security issues get priority response

---

## 🎁 Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md (if file exists)
- Credited in release notes
- Mentioned in project documentation

Thank you for contributing to Runic! 🙏

---

**Questions?** Open a discussion on GitHub or check our [documentation](docs/).
