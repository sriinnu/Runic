#!/usr/bin/env bash

################################################################################
# build-macos.sh
#
# Purpose: Build macOS application
#
# Description:
#   - Builds Runic macOS app using Swift Package Manager
#   - Runs tests before building
#   - Creates distributable .app bundle
#   - Optionally signs and notarizes the app
#   - Outputs build artifacts to standardized location
#
# Usage:
#   ./build-macos.sh [OPTIONS]
#
# Options:
#   --dry-run           Show what would be done without executing
#   --verbose           Enable verbose output
#   --skip-tests        Skip running tests
#   --skip-signing      Skip code signing
#   --configuration     Build configuration (debug|release) [default: release]
#   --output-dir        Output directory for build artifacts
#   --clean             Clean build directory before building
#   --help              Show this help message
#
# Requirements:
#   - macOS 14.0+
#   - Xcode 15.0+
#   - Swift 6.0+
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

DRY_RUN=false
VERBOSE=false
SKIP_TESTS=false
SKIP_SIGNING=false
CONFIGURATION="release"
OUTPUT_DIR="$PROJECT_ROOT/builds/macos"
CLEAN_BUILD=false

APP_NAME="Runic"
PRODUCT_NAME="Runic"

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

################################################################################
# Build Functions
################################################################################

check_prerequisites() {
    log_step "Checking Prerequisites"

    # Check macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script must be run on macOS"
        return 1
    fi

    # Check Swift
    if ! command -v swift &> /dev/null; then
        log_error "Swift is not installed"
        return 1
    fi

    local swift_version
    swift_version=$(swift --version 2>&1 | head -n 1)
    log_success "Swift installed: $swift_version"

    # Check Xcode
    if ! xcodebuild -version &> /dev/null; then
        log_error "Xcode is not installed"
        return 1
    fi

    local xcode_version
    xcode_version=$(xcodebuild -version | head -n 1)
    log_success "$xcode_version installed"

    log_success "All prerequisites satisfied"
}

clean_build_directory() {
    if [[ "$CLEAN_BUILD" == false ]]; then
        return 0
    fi

    log_step "Cleaning Build Directory"

    cd "$PROJECT_ROOT"

    if [[ -d ".build" ]]; then
        log_info "Removing .build directory..."
        run_cmd "rm -rf .build"
        log_success "Build directory cleaned"
    else
        log_info "No build directory to clean"
    fi
}

run_tests() {
    if [[ "$SKIP_TESTS" == true ]]; then
        log_info "Skipping tests (--skip-tests)"
        return 0
    fi

    log_step "Running Tests"

    cd "$PROJECT_ROOT"

    log_info "Running Swift tests..."

    local test_cmd="swift test"
    if [[ "$VERBOSE" == true ]]; then
        test_cmd="$test_cmd --verbose"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY-RUN] Would run: $test_cmd"
        return 0
    fi

    if $test_cmd; then
        log_success "All tests passed"
    else
        log_error "Tests failed"
        log_info "Use --skip-tests to bypass test failures"
        return 1
    fi
}

run_linting() {
    log_step "Running Code Quality Checks"

    cd "$PROJECT_ROOT"

    # SwiftLint
    if command -v swiftlint &> /dev/null; then
        log_info "Running SwiftLint..."
        if [[ "$DRY_RUN" == false ]]; then
            if swiftlint lint --quiet; then
                log_success "SwiftLint passed"
            else
                log_warning "SwiftLint found issues (not blocking build)"
            fi
        fi
    else
        log_info "SwiftLint not installed, skipping"
    fi

    # SwiftFormat (check only)
    if command -v swiftformat &> /dev/null; then
        log_info "Checking SwiftFormat..."
        if [[ "$DRY_RUN" == false ]]; then
            if swiftformat --lint . > /dev/null 2>&1; then
                log_success "SwiftFormat check passed"
            else
                log_warning "SwiftFormat found formatting issues (not blocking build)"
            fi
        fi
    else
        log_info "SwiftFormat not installed, skipping"
    fi
}

build_app() {
    log_step "Building macOS Application"

    cd "$PROJECT_ROOT"

    # Read version from version.env if exists
    local version="1.0.0"
    local build_number=$(date +%Y%m%d%H%M%S)

    if [[ -f "version.env" ]]; then
        source "version.env"
        version="${VERSION:-$version}"
    fi

    log_info "Building version: $version (build $build_number)"
    log_info "Configuration: $CONFIGURATION"

    # Build command
    local build_cmd="swift build"
    build_cmd="$build_cmd --product $PRODUCT_NAME"

    if [[ "$CONFIGURATION" == "release" ]]; then
        build_cmd="$build_cmd -c release"
    fi

    if [[ "$VERBOSE" == true ]]; then
        build_cmd="$build_cmd --verbose"
    fi

    log_info "Building: $build_cmd"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY-RUN] Would run: $build_cmd"
        return 0
    fi

    if $build_cmd; then
        log_success "Build completed successfully"
    else
        log_error "Build failed"
        return 1
    fi

    # Determine build output location
    local build_dir=".build"
    if [[ "$CONFIGURATION" == "release" ]]; then
        build_dir="$build_dir/release"
    else
        build_dir="$build_dir/debug"
    fi

    local binary_path="$build_dir/$PRODUCT_NAME"

    if [[ -f "$binary_path" ]]; then
        log_success "Binary created: $binary_path"

        # Get binary size
        local size
        size=$(du -h "$binary_path" | cut -f1)
        log_info "Binary size: $size"
    else
        log_error "Binary not found at expected location: $binary_path"
        return 1
    fi
}

create_app_bundle() {
    log_step "Creating Application Bundle"

    cd "$PROJECT_ROOT"

    local build_dir=".build"
    if [[ "$CONFIGURATION" == "release" ]]; then
        build_dir="$build_dir/release"
    else
        build_dir="$build_dir/debug"
    fi

    local binary_path="$build_dir/$PRODUCT_NAME"
    local app_bundle="$OUTPUT_DIR/$APP_NAME.app"

    # Create output directory
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$OUTPUT_DIR"
        mkdir -p "$app_bundle/Contents/MacOS"
        mkdir -p "$app_bundle/Contents/Resources"
    fi

    log_info "Creating app bundle: $app_bundle"

    # Copy binary
    if [[ "$DRY_RUN" == false ]]; then
        cp "$binary_path" "$app_bundle/Contents/MacOS/$APP_NAME"
        chmod +x "$app_bundle/Contents/MacOS/$APP_NAME"
    fi

    # Copy Sparkle framework
    log_info "Copying Sparkle framework..."
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$app_bundle/Contents/Frameworks"

        # Find Sparkle framework in build directory
        local sparkle_source=""
        if [[ "$CONFIGURATION" == "release" ]]; then
            sparkle_source=".build/arm64-apple-macosx/release/Sparkle.framework"
        else
            sparkle_source=".build/arm64-apple-macosx/debug/Sparkle.framework"
        fi

        if [[ -d "$sparkle_source" ]]; then
            cp -R "$sparkle_source" "$app_bundle/Contents/Frameworks/"
            log_success "Sparkle framework copied"

            # Add rpath to binary
            log_info "Adding framework rpath..."
            install_name_tool -add_rpath @loader_path/../Frameworks "$app_bundle/Contents/MacOS/$APP_NAME" 2>&1 | grep -v "warning: changes being made" || true
            log_success "Framework rpath added"
        else
            log_warning "Sparkle framework not found at $sparkle_source"
        fi
    fi

    # Copy icon if exists
    if [[ -f "Icon.icns" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            cp "Icon.icns" "$app_bundle/Contents/Resources/"
        fi
        log_info "Copied application icon"
    fi

    # Copy Resources (SVG icons, etc.)
    if [[ -d "Sources/Runic/Resources" ]]; then
        log_info "Copying Runic resources (SVG icons)..."
        if [[ "$DRY_RUN" == false ]]; then
            cp -R "Sources/Runic/Resources/"* "$app_bundle/Contents/Resources/"
            log_success "Runic resources copied"
        fi
    fi

    # Create Info.plist
    local version="1.0.0"
    if [[ -f "version.env" ]]; then
        source "version.env"
        version="${VERSION:-$version}"
    fi

    if [[ "$DRY_RUN" == false ]]; then
        cat > "$app_bundle/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>Icon</string>
    <key>CFBundleIdentifier</key>
    <string>com.runic.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>CFBundleVersion</key>
    <string>$version</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF
    fi

    log_success "App bundle created: $app_bundle"
}

sign_app() {
    if [[ "$SKIP_SIGNING" == true ]]; then
        log_info "Skipping code signing (--skip-signing)"
        return 0
    fi

    log_step "Code Signing"

    local app_bundle="$OUTPUT_DIR/$APP_NAME.app"

    # Check for signing identity
    local identity
    identity=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | awk -F'"' '{print $2}')

    if [[ -z "$identity" ]]; then
        log_warning "No Developer ID Application certificate found"
        log_info "Skipping code signing"
        log_info "For distribution, you need to:"
        log_info "  1. Create a Developer ID Application certificate"
        log_info "  2. Run: codesign --deep --force --sign \"Developer ID Application: Your Name\" $app_bundle"
        return 0
    fi

    log_info "Found signing identity: $identity"

    if [[ "$DRY_RUN" == false ]]; then
        log_info "Signing app bundle..."
        codesign --deep --force --sign "$identity" --options runtime "$app_bundle"
        log_success "App bundle signed"

        # Verify signature
        log_info "Verifying signature..."
        if codesign --verify --verbose "$app_bundle"; then
            log_success "Signature verification passed"
        else
            log_error "Signature verification failed"
            return 1
        fi
    fi
}

create_build_artifacts() {
    log_step "Creating Build Artifacts"

    cd "$OUTPUT_DIR"

    local app_bundle="$APP_NAME.app"
    local version="1.0.0"

    if [[ -f "$PROJECT_ROOT/version.env" ]]; then
        source "$PROJECT_ROOT/version.env"
        version="${VERSION:-$version}"
    fi

    # Create ZIP archive
    local zip_name="${APP_NAME}-${version}-macos.zip"

    if [[ "$DRY_RUN" == false ]]; then
        log_info "Creating ZIP archive: $zip_name"
        ditto -c -k --keepParent "$app_bundle" "$zip_name"
        log_success "ZIP archive created: $OUTPUT_DIR/$zip_name"

        # Get archive size
        local size
        size=$(du -h "$zip_name" | cut -f1)
        log_info "Archive size: $size"
    fi
}

build_summary() {
    log_step "Build Summary"

    log_success "macOS build completed successfully!"
    log_info ""
    log_info "Build artifacts:"
    log_info "  App bundle: $OUTPUT_DIR/$APP_NAME.app"

    if [[ -f "$OUTPUT_DIR/${APP_NAME}-*.zip" ]]; then
        log_info "  ZIP archive: $OUTPUT_DIR/$(ls -t "$OUTPUT_DIR"/${APP_NAME}-*.zip | head -n 1 | xargs basename)"
    fi

    log_info ""
    log_info "To run the app:"
    log_info "  open $OUTPUT_DIR/$APP_NAME.app"
    log_info ""

    if [[ "$SKIP_SIGNING" == true ]]; then
        log_warning "App was not signed. For distribution, run with signing enabled."
    fi
}

run_build() {
    log_step "Starting macOS Build"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "Running in DRY-RUN mode - no changes will be made"
    fi

    local start_time=$(date +%s)

    check_prerequisites || exit 1
    clean_build_directory
    run_linting
    run_tests || exit 1
    build_app || exit 1
    create_app_bundle || exit 1
    sign_app
    create_build_artifacts

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
            --skip-signing)
                SKIP_SIGNING=true
                shift
                ;;
            --configuration)
                CONFIGURATION="$2"
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
    if [[ "$CONFIGURATION" != "debug" ]] && [[ "$CONFIGURATION" != "release" ]]; then
        log_error "Invalid configuration: $CONFIGURATION"
        log_info "Use 'debug' or 'release'"
        exit 1
    fi

    run_build
}

main "$@"
