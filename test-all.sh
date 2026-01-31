#!/bin/bash

################################################################################
# Runic Comprehensive Test Script
#
# This script verifies that all components of the Runic project are properly
# configured and can build successfully.
#
# Components tested:
# 1. Swift/SwiftUI macOS application
# 2. Swift iOS widget/app
# 3. API Server (Node.js/TypeScript)
# 4. MCP Servers (persistence, intuition, consciousness)
# 5. React Native cross-platform app
# 6. File integrity checks
#
# Exit codes:
# - 0: All tests passed
# - 1: One or more tests failed
#
# Usage: ./test-all.sh
################################################################################

set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Log functions
log_section() {
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

log_test() {
    echo -e "${BLUE}▶${NC} Testing: $1"
}

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED_TESTS++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

log_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# Test execution wrapper
run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TOTAL_TESTS++))
    log_test "$test_name"

    # Create temporary file for output
    local temp_output=$(mktemp)

    # Run the test command
    if eval "$test_command" > "$temp_output" 2>&1; then
        log_pass "$test_name"
        rm "$temp_output"
        return 0
    else
        log_fail "$test_name"
        echo -e "${RED}Error output:${NC}"
        cat "$temp_output" | head -20
        if [ $(wc -l < "$temp_output") -gt 20 ]; then
            echo -e "${YELLOW}... (output truncated, showing first 20 lines)${NC}"
        fi
        rm "$temp_output"
        return 1
    fi
}

################################################################################
# Test 1: Swift macOS Application
################################################################################
test_swift_macos() {
    log_section "Test 1: Swift macOS Application Build"

    cd "$PROJECT_ROOT" || return 1

    # Check if Package.swift exists
    if [ ! -f "Package.swift" ]; then
        log_fail "Package.swift not found"
        return 1
    fi

    log_info "Building Swift package (this may take a while)..."

    # Build in release mode and check for errors
    if swift build --configuration release 2>&1 | tee /tmp/swift_build.log | grep -qi "error:"; then
        log_fail "Swift build completed with errors"
        echo -e "${RED}Build errors:${NC}"
        grep -i "error:" /tmp/swift_build.log | head -10
        return 1
    else
        # Check if build actually succeeded
        if swift build --configuration release > /dev/null 2>&1; then
            log_pass "Swift macOS application builds successfully"
            return 0
        else
            log_fail "Swift build failed"
            return 1
        fi
    fi
}

################################################################################
# Test 2: Swift iOS Components
################################################################################
test_swift_ios() {
    log_section "Test 2: Swift iOS Components"

    cd "$PROJECT_ROOT/RuniciOS" || {
        log_warning "RuniciOS directory not found, skipping iOS tests"
        ((TOTAL_TESTS++))
        return 0
    }

    # Check for Swift files
    local swift_files=$(find . -name "*.swift" -type f | wc -l)
    if [ "$swift_files" -gt 0 ]; then
        log_pass "Found $swift_files Swift source files"

        # Check for common iOS patterns
        if grep -r "import SwiftUI" . > /dev/null 2>&1; then
            log_pass "SwiftUI imports found"
        fi

        if grep -r "import WidgetKit" . > /dev/null 2>&1; then
            log_pass "WidgetKit imports found"
        fi
    else
        log_warning "No Swift files found in RuniciOS"
    fi
}

################################################################################
# Test 3: API Server
################################################################################
test_api_server() {
    log_section "Test 3: API Server (Node.js/TypeScript)"

    cd "$PROJECT_ROOT/api-server" || {
        log_fail "api-server directory not found"
        return 1
    }

    # Check package.json exists
    if [ ! -f "package.json" ]; then
        log_fail "package.json not found in api-server"
        return 1
    fi

    # Install dependencies silently
    log_info "Installing API server dependencies..."
    if npm install --silent --no-progress > /dev/null 2>&1; then
        log_pass "Dependencies installed successfully"
    else
        log_warning "Dependency installation had warnings (this might be okay)"
    fi

    # TypeScript type checking
    log_info "Running TypeScript type check..."
    run_test "API Server TypeScript compilation" "npx tsc --noEmit"

    # Check for TypeScript config
    if [ -f "tsconfig.json" ]; then
        log_pass "tsconfig.json exists"
    else
        log_warning "tsconfig.json not found"
    fi

    # Verify source files exist
    if [ -d "src" ] && [ "$(find src -name '*.ts' | wc -l)" -gt 0 ]; then
        log_pass "TypeScript source files found"
    else
        log_warning "No TypeScript source files found in src/"
    fi
}

################################################################################
# Test 4: MCP Servers
################################################################################
test_mcp_servers() {
    log_section "Test 4: MCP Servers"

    local mcp_servers=("persistence-server" "intuition-server" "consciousness-server")

    for server in "${mcp_servers[@]}"; do
        echo ""
        log_info "Testing $server..."

        cd "$PROJECT_ROOT/mcp-servers/$server" || {
            log_fail "$server directory not found"
            continue
        }

        # Check package.json
        if [ ! -f "package.json" ]; then
            log_fail "$server: package.json not found"
            continue
        fi

        # Install dependencies
        log_info "$server: Installing dependencies..."
        if npm install --silent --no-progress > /dev/null 2>&1; then
            log_pass "$server: Dependencies installed"
        else
            log_warning "$server: Dependency installation warnings"
        fi

        # TypeScript type checking
        log_info "$server: Type checking..."
        run_test "$server: TypeScript compilation" "npx tsc --noEmit"

        # Check for source files
        if [ -d "src" ] && [ "$(find src -name '*.ts' | wc -l)" -gt 0 ]; then
            log_pass "$server: TypeScript source files found"
        else
            log_warning "$server: No TypeScript source files in src/"
        fi
    done
}

################################################################################
# Test 5: React Native Cross-Platform App
################################################################################
test_react_native() {
    log_section "Test 5: React Native Cross-Platform App"

    cd "$PROJECT_ROOT/runic-cross-platform" || {
        log_fail "runic-cross-platform directory not found"
        return 1
    }

    # Check package.json
    if [ ! -f "package.json" ]; then
        log_fail "package.json not found in runic-cross-platform"
        return 1
    fi

    # Install dependencies
    log_info "Installing React Native dependencies (this may take a while)..."
    if npm install --silent --no-progress > /dev/null 2>&1; then
        log_pass "React Native dependencies installed"
    else
        log_warning "React Native dependency installation had warnings"
    fi

    # TypeScript type checking
    log_info "Running TypeScript type check..."
    run_test "React Native TypeScript compilation" "npx tsc --noEmit"

    # Check for React Native config files
    if [ -f "metro.config.js" ] || [ -f "metro.config.ts" ]; then
        log_pass "Metro config found"
    else
        log_warning "Metro config not found"
    fi

    if [ -f "babel.config.js" ]; then
        log_pass "Babel config found"
    else
        log_warning "Babel config not found"
    fi

    # Check platform directories
    if [ -d "android" ]; then
        log_pass "Android platform directory exists"
    else
        log_warning "Android platform directory not found"
    fi

    if [ -d "windows" ]; then
        log_pass "Windows platform directory exists"
    else
        log_warning "Windows platform directory not found"
    fi
}

################################################################################
# Test 6: File Integrity Checks
################################################################################
test_file_integrity() {
    log_section "Test 6: File Integrity & Structure"

    cd "$PROJECT_ROOT" || return 1

    # Critical files
    local critical_files=(
        "Package.swift"
        "README.md"
        "LICENSE"
        ".gitignore"
    )

    for file in "${critical_files[@]}"; do
        if [ -f "$file" ]; then
            log_pass "Found $file"
        else
            log_fail "Missing critical file: $file"
        fi
    done

    # Check for important directories
    local important_dirs=(
        "Sources"
        "api-server"
        "mcp-servers"
        "runic-cross-platform"
        "Scripts"
    )

    for dir in "${important_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_pass "Found directory: $dir"
        else
            log_warning "Directory not found: $dir"
        fi
    done

    # Check for broken symlinks
    log_info "Checking for broken symbolic links..."
    local broken_links=$(find . -type l ! -exec test -e {} \; -print 2>/dev/null | grep -v node_modules | grep -v .build)
    if [ -z "$broken_links" ]; then
        log_pass "No broken symbolic links found"
    else
        log_warning "Found broken symbolic links:"
        echo "$broken_links"
    fi
}

################################################################################
# Test 7: Git Repository Health
################################################################################
test_git_health() {
    log_section "Test 7: Git Repository Health"

    cd "$PROJECT_ROOT" || return 1

    # Check if it's a git repo
    if [ -d ".git" ]; then
        log_pass "Git repository initialized"
    else
        log_fail "Not a git repository"
        return 1
    fi

    # Check for uncommitted changes
    if [ -n "$(git status --porcelain)" ]; then
        log_info "Repository has uncommitted changes"
        local modified=$(git status --porcelain | wc -l)
        log_info "$modified files modified/untracked"
    else
        log_pass "Working tree is clean"
    fi

    # Check current branch
    local branch=$(git rev-parse --abbrev-ref HEAD)
    log_info "Current branch: $branch"

    # Check for .gitignore
    if [ -f ".gitignore" ]; then
        log_pass ".gitignore exists"
        local ignored_patterns=$(grep -v '^#' .gitignore | grep -v '^$' | wc -l)
        log_info "$ignored_patterns ignore patterns defined"
    fi
}

################################################################################
# Main Execution
################################################################################
main() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║           RUNIC COMPREHENSIVE TEST SUITE                      ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    log_info "Project root: $PROJECT_ROOT"
    log_info "Starting comprehensive test suite..."

    # Run all tests
    test_file_integrity
    test_git_health
    test_swift_macos
    test_swift_ios
    test_api_server
    test_mcp_servers
    test_react_native

    # Print summary
    log_section "Test Summary"

    echo ""
    echo -e "${BOLD}Results:${NC}"
    echo -e "  ${GREEN}✓ Passed:${NC}  $PASSED_TESTS"
    echo -e "  ${RED}✗ Failed:${NC}  $FAILED_TESTS"
    echo -e "  ${YELLOW}⚠ Warnings:${NC} $WARNINGS"
    echo -e "  ${BLUE}━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}Total:${NC}    $TOTAL_TESTS"
    echo ""

    # Calculate success rate
    if [ $TOTAL_TESTS -gt 0 ]; then
        local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo -e "${BOLD}Success Rate:${NC} $success_rate%"
    fi

    echo ""

    # Final verdict
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${GREEN}║                                                               ║${NC}"
        echo -e "${BOLD}${GREEN}║                  🎉 ALL TESTS PASSED! 🎉                      ║${NC}"
        echo -e "${BOLD}${GREEN}║                                                               ║${NC}"
        echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        if [ $WARNINGS -gt 0 ]; then
            log_warning "There were $WARNINGS warnings, but no critical failures"
        fi
        exit 0
    else
        echo -e "${BOLD}${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${RED}║                                                               ║${NC}"
        echo -e "${BOLD}${RED}║                  ❌ TESTS FAILED ❌                            ║${NC}"
        echo -e "${BOLD}${RED}║                                                               ║${NC}"
        echo -e "${BOLD}${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        log_fail "$FAILED_TESTS test(s) failed"
        echo ""
        log_info "Review the output above to identify and fix the issues"
        exit 1
    fi
}

# Run main function
main "$@"
