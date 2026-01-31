#!/usr/bin/env bash

################################################################################
# build-windows.sh
#
# Purpose: Build Windows application (React Native Windows)
#
# Description:
#   - Builds Runic Windows app using MSBuild
#   - Runs tests and code quality checks
#   - Creates distributable package
#   - Supports different build configurations
#   - Outputs build artifacts to standardized location
#
# Usage:
#   ./build-windows.sh [OPTIONS]
#
# Options:
#   --dry-run           Show what would be done without executing
#   --verbose           Enable verbose output
#   --skip-tests        Skip running tests
#   --configuration     Build configuration (Debug|Release) [default: Release]
#   --arch              Target architecture (x64|x86|ARM64) [default: x64]
#   --output-dir        Output directory for build artifacts
#   --clean             Clean build directory before building
#   --help              Show this help message
#
# Requirements:
#   - Windows 10+
#   - Visual Studio 2022 with C++ development tools
#   - Windows 10 SDK
#   - Node.js
#   - React Native Windows CLI
#
# Author: Runic Team
# Version: 1.0.0
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color output configuration
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    BOLD=''
    RESET=''
fi

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WINDOWS_PROJECT_DIR="$PROJECT_ROOT/runic-cross-platform"

DRY_RUN=false
VERBOSE=false
SKIP_TESTS=false
CONFIGURATION="Release"
ARCHITECTURE="x64"
OUTPUT_DIR="$PROJECT_ROOT/builds/windows"
CLEAN_BUILD=false

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
}

log_step() {
    echo -e "\n${CYAN}${BOLD}==>${RESET} ${BOLD}$*${RESET}\n"
}

run_cmd() {
    local cmd="$*"

    if [[ "$VERBOSE" == true ]]; then
        log_info "Running: $cmd"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY-RUN] Would execute: $cmd"
        return 0
    fi

    if [[ "$VERBOSE" == true ]]; then
        eval "$cmd"
    else
        eval "$cmd" > /dev/null 2>&1
    fi
}

show_help() {
    sed -n '/^# Purpose:/,/^################################################################################$/p' "$0" | sed 's/^# \?//'
}

is_windows() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
        *) return 1 ;;
    esac
}

################################################################################
# Build Functions
################################################################################

check_prerequisites() {
    log_step "Checking Prerequisites"

    local all_ok=true

    # Check if running on Windows (or WSL)
    if ! is_windows; then
        log_warning "Not running on native Windows"
        log_info "This script is designed for Windows. For cross-platform builds, use WSL or a Windows VM"
    fi

    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed"
        all_ok=false
    else
        log_success "Node.js installed: $(node --version)"
    fi

    # Check npm
    if ! command -v npm &> /dev/null; then
        log_error "npm is not installed"
        all_ok=false
    else
        log_success "npm installed: $(npm --version)"
    fi

    # Check for Windows project
    if [[ ! -d "$WINDOWS_PROJECT_DIR" ]]; then
        log_error "Windows project directory not found: $WINDOWS_PROJECT_DIR"
        all_ok=false
    fi

    if [[ ! -d "$WINDOWS_PROJECT_DIR/windows" ]]; then
        log_warning "Windows subdirectory not found: $WINDOWS_PROJECT_DIR/windows"
        log_info "Initialize with: npx react-native-windows-init --overwrite"
    fi

    # Check for MSBuild (Windows only)
    if is_windows; then
        if command -v msbuild &> /dev/null || command -v msbuild.exe &> /dev/null; then
            log_success "MSBuild is installed"
        else
            log_warning "MSBuild not found in PATH"
            log_info "MSBuild is typically installed with Visual Studio"
        fi
    fi

    if [[ "$all_ok" == false ]]; then
        log_error "Some prerequisites are missing"
        return 1
    fi

    log_success "Prerequisites check complete"
}

setup_environment() {
    log_step "Setting Up Environment"

    cd "$WINDOWS_PROJECT_DIR"

    # Install npm dependencies if needed
    if [[ ! -d "node_modules" ]]; then
        log_info "Installing npm dependencies..."
        run_cmd "npm install"
    else
        log_info "npm dependencies already installed"
    fi

    log_success "Environment setup complete"
}

clean_build_directory() {
    if [[ "$CLEAN_BUILD" == false ]]; then
        return 0
    fi

    log_step "Cleaning Build Directory"

    cd "$WINDOWS_PROJECT_DIR"

    if is_windows && [[ -d "windows" ]]; then
        log_info "Cleaning Windows build directories..."

        if [[ "$DRY_RUN" == false ]]; then
            # Clean MSBuild output
            find windows -type d -name "obj" -exec rm -rf {} + 2>/dev/null || true
            find windows -type d -name "bin" -exec rm -rf {} + 2>/dev/null || true
            find windows -type d -name "Debug" -exec rm -rf {} + 2>/dev/null || true
            find windows -type d -name "Release" -exec rm -rf {} + 2>/dev/null || true

            log_success "Build directory cleaned"
        fi
    else
        log_info "No Windows build directory to clean"
    fi
}

run_tests() {
    if [[ "$SKIP_TESTS" == true ]]; then
        log_info "Skipping tests (--skip-tests)"
        return 0
    fi

    log_step "Running Tests"

    cd "$WINDOWS_PROJECT_DIR"

    # Run JavaScript/TypeScript tests
    if [[ -f "package.json" ]]; then
        if grep -q '"test"' package.json; then
            log_info "Running tests..."
            run_cmd "npm test -- --passWithNoTests"
            log_success "Tests completed"
        else
            log_info "No test script found in package.json"
        fi
    fi
}

build_windows_app() {
    log_step "Building Windows Application"

    cd "$WINDOWS_PROJECT_DIR"

    if [[ ! -d "windows" ]]; then
        log_error "Windows project not initialized"
        log_info "Run: npx react-native-windows-init --overwrite"
        return 1
    fi

    # React Native Windows build command
    local build_cmd="npx react-native run-windows"
    build_cmd="$build_cmd --no-launch"
    build_cmd="$build_cmd --arch $ARCHITECTURE"

    if [[ "$CONFIGURATION" == "Release" ]]; then
        build_cmd="$build_cmd --release"
    fi

    if [[ "$VERBOSE" == true ]]; then
        build_cmd="$build_cmd --logging"
    fi

    log_info "Building Windows app..."
    log_info "Configuration: $CONFIGURATION"
    log_info "Architecture: $ARCHITECTURE"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY-RUN] Would run: $build_cmd"
        return 0
    fi

    if eval "$build_cmd"; then
        log_success "Windows build completed successfully"
    else
        log_error "Windows build failed"
        log_info ""
        log_info "Common issues:"
        log_info "  - Ensure Visual Studio 2022 is installed with C++ development tools"
        log_info "  - Ensure Windows 10 SDK is installed"
        log_info "  - Run: npx react-native doctor to diagnose issues"
        return 1
    fi
}

copy_build_artifacts() {
    log_step "Copying Build Artifacts"

    cd "$WINDOWS_PROJECT_DIR"

    # Find the build output
    local build_output="windows/$ARCHITECTURE/$CONFIGURATION"

    if [[ ! -d "$build_output" ]]; then
        # Try alternative location
        build_output="windows/x64/$CONFIGURATION"
    fi

    if [[ -d "$build_output" ]]; then
        mkdir -p "$OUTPUT_DIR"

        log_info "Copying build artifacts from: $build_output"

        if [[ "$DRY_RUN" == false ]]; then
            # Copy entire build output
            cp -r "$build_output"/* "$OUTPUT_DIR/" 2>/dev/null || true

            log_success "Build artifacts copied to: $OUTPUT_DIR"

            # List key files
            if [[ -f "$OUTPUT_DIR/RunicApp.exe" ]] || [[ -f "$OUTPUT_DIR/runic.exe" ]]; then
                local exe_file
                exe_file=$(find "$OUTPUT_DIR" -name "*.exe" -type f | head -n 1)
                if [[ -n "$exe_file" ]]; then
                    local size
                    size=$(du -h "$exe_file" | cut -f1)
                    log_info "Executable size: $size"
                    log_info "Executable: $(basename "$exe_file")"
                fi
            fi
        fi
    else
        log_warning "Build output not found at expected location: $build_output"
        log_info "Build may have completed but artifacts couldn't be located"
    fi
}

create_package() {
    log_step "Creating Distribution Package"

    if [[ "$CONFIGURATION" != "Release" ]]; then
        log_info "Package creation is only for Release builds"
        return 0
    fi

    cd "$OUTPUT_DIR"

    if [[ ! -d "$OUTPUT_DIR" ]] || [[ -z "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ]]; then
        log_warning "No build artifacts found, skipping package creation"
        return 0
    fi

    local version="1.0.0"
    if [[ -f "$PROJECT_ROOT/version.env" ]]; then
        source "$PROJECT_ROOT/version.env"
        version="${VERSION:-$version}"
    fi

    local package_name="Runic-${version}-Windows-${ARCHITECTURE}.zip"

    if [[ "$DRY_RUN" == false ]]; then
        log_info "Creating package: $package_name"

        # Create ZIP archive (works in Git Bash on Windows)
        if command -v powershell &> /dev/null; then
            # Use PowerShell's compression
            powershell -Command "Compress-Archive -Path * -DestinationPath $package_name -Force" 2>/dev/null || true
        elif command -v zip &> /dev/null; then
            # Use zip if available
            zip -r "$package_name" . -x "*.zip" > /dev/null 2>&1 || true
        fi

        if [[ -f "$package_name" ]]; then
            log_success "Package created: $OUTPUT_DIR/$package_name"
            local size
            size=$(du -h "$package_name" | cut -f1)
            log_info "Package size: $size"
        else
            log_warning "Could not create package automatically"
            log_info "Manually create a ZIP archive of: $OUTPUT_DIR"
        fi
    fi
}

build_summary() {
    log_step "Build Summary"

    log_success "Windows build completed successfully!"
    log_info ""
    log_info "Build artifacts: $OUTPUT_DIR"
    log_info "  Configuration: $CONFIGURATION"
    log_info "  Architecture: $ARCHITECTURE"
    log_info ""

    if [[ -f "$OUTPUT_DIR"/*.exe ]]; then
        log_info "Executable files:"
        find "$OUTPUT_DIR" -maxdepth 1 -name "*.exe" -type f -exec basename {} \; | while read -r exe; do
            log_info "  - $exe"
        done
        log_info ""
    fi

    log_info "Next steps:"
    log_info "  - Test the application on Windows"
    log_info "  - Create installer with tools like WiX or Inno Setup"
    log_info "  - Sign the executable for distribution"
    log_info ""
}

run_build() {
    log_step "Starting Windows Build"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "Running in DRY-RUN mode - no changes will be made"
    fi

    local start_time=$(date +%s)

    check_prerequisites || exit 1
    setup_environment
    clean_build_directory
    run_tests || log_warning "Tests failed, continuing with build..."
    build_windows_app || exit 1
    copy_build_artifacts
    create_package

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "Build completed in ${duration}s"

    build_summary
}

################################################################################
# Main Script
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --configuration)
                CONFIGURATION="$2"
                shift 2
                ;;
            --arch)
                ARCHITECTURE="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --clean)
                CLEAN_BUILD=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                log_info "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Validate configuration
    if [[ "$CONFIGURATION" != "Debug" ]] && [[ "$CONFIGURATION" != "Release" ]]; then
        log_error "Invalid configuration: $CONFIGURATION"
        log_info "Use 'Debug' or 'Release'"
        exit 1
    fi

    # Validate architecture
    if [[ "$ARCHITECTURE" != "x64" ]] && [[ "$ARCHITECTURE" != "x86" ]] && [[ "$ARCHITECTURE" != "ARM64" ]]; then
        log_error "Invalid architecture: $ARCHITECTURE"
        log_info "Use 'x64', 'x86', or 'ARM64'"
        exit 1
    fi

    run_build
}

main "$@"
