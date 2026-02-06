#!/usr/bin/env bash

################################################################################
# build-and-run.sh
#
# Purpose: Quick build and run script for Runic
#
# Description:
#   - Builds Runic with swift build -c release
#   - Copies executable to app bundle
#   - Copies frameworks (Sparkle) to app bundle
#   - Sets up proper directory structure
#   - Optionally opens the app after building
#
# Usage:
#   ./build-and-run.sh [OPTIONS]
#
# Options:
#   --no-build          Skip building, just copy frameworks
#   --no-run            Build but don't open the app
#   --debug             Build in debug mode instead of release
#   --clean             Clean before building
#   --verbose           Show verbose output
#   --help              Show this help message
#
# Requirements:
#   - macOS 14.0+
#   - Swift 6.0+
#
# Author: Runic Team
# Version: 1.0.0
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

DO_BUILD=true
DO_RUN=true
CONFIGURATION="release"
DO_CLEAN=false
VERBOSE=false

# Color output
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    GREEN=''
    YELLOW=''
    RED=''
    BLUE=''
    CYAN=''
    BOLD=''
    RESET=''
fi

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

show_help() {
    sed -n '/^# Purpose:/,/^################################################################################$/p' "$0" | sed 's/^# \?//'
}

################################################################################
# Build Functions
################################################################################

clean_build() {
    if [[ "$DO_CLEAN" == false ]]; then
        return 0
    fi

    log_step "Cleaning Build Directory"

    cd "$PROJECT_ROOT"

    if [[ -d ".build" ]]; then
        log_info "Removing .build directory..."
        rm -rf .build
        log_success "Build directory cleaned"
    else
        log_info "No build directory to clean"
    fi
}

build_executable() {
    if [[ "$DO_BUILD" == false ]]; then
        log_info "Skipping build (--no-build)"
        return 0
    fi

    log_step "Building Runic Executable"

    cd "$PROJECT_ROOT"

    local build_cmd="swift build -c $CONFIGURATION"

    if [[ "$VERBOSE" == true ]]; then
        build_cmd="$build_cmd --verbose"
    fi

    log_info "Running: $build_cmd"

    if $build_cmd; then
        log_success "Build completed successfully"
    else
        log_error "Build failed"
        return 1
    fi
}

create_app_bundle() {
    log_step "Creating Application Bundle"

    cd "$PROJECT_ROOT"

    local app_dir="builds/macos/Runic.app"

    # Create app bundle structure
    log_info "Creating app bundle structure at $app_dir"
    mkdir -p "$app_dir/Contents/MacOS"
    mkdir -p "$app_dir/Contents/Resources"
    mkdir -p "$app_dir/Contents/Frameworks"

    # Determine build directory based on configuration
    local build_dir
    if [[ "$CONFIGURATION" == "release" ]]; then
        build_dir=".build/release"
    else
        build_dir=".build/debug"
    fi

    # Copy executable
    local executable="$build_dir/Runic"
    if [[ ! -f "$executable" ]]; then
        log_error "Executable not found at $executable"
        log_error "Please run swift build first"
        return 1
    fi

    log_info "Copying executable..."
    cp "$executable" "$app_dir/Contents/MacOS/Runic"
    chmod +x "$app_dir/Contents/MacOS/Runic"
    log_success "Executable copied"

    # Copy Sparkle framework
    local sparkle_source=".build/arm64-apple-macosx/$CONFIGURATION/Sparkle.framework"

    if [[ -d "$sparkle_source" ]]; then
        log_info "Copying Sparkle.framework..."
        cp -R "$sparkle_source" "$app_dir/Contents/Frameworks/"
        log_success "Sparkle.framework copied"

        # Add rpath to executable
        log_info "Adding framework rpath..."
        install_name_tool -add_rpath @loader_path/../Frameworks "$app_dir/Contents/MacOS/Runic" 2>&1 | grep -v "warning: changes being made" || true
        log_success "Framework rpath added"
    else
        log_warning "Sparkle.framework not found at $sparkle_source"
    fi

    # Copy resources
    if [[ -d "Sources/Runic/Resources" ]]; then
        log_info "Copying resources..."
        cp -R Sources/Runic/Resources/* "$app_dir/Contents/Resources/" 2>/dev/null || true
        log_success "Resources copied"
    fi

    # Copy icon if exists
    if [[ -f "Icon.icns" ]]; then
        cp "Icon.icns" "$app_dir/Contents/Resources/"
        log_info "Icon copied"
    fi

    # Create Info.plist
    local version="1.0.0"
    if [[ -f "version.env" ]]; then
        source "version.env"
        version="${VERSION:-$version}"
    fi

    log_info "Creating Info.plist (version: $version)..."
    cat > "$app_dir/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Runic</string>
    <key>CFBundleIconFile</key>
    <string>Icon</string>
    <key>CFBundleIdentifier</key>
    <string>com.sriinnu.athena.Runic</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Runic</string>
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
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
EOF

    # Sign the entire app bundle after all contents are in place.
    # Signing must happen last — install_name_tool and Info.plist creation
    # invalidate any earlier signature.
    log_info "Signing app bundle..."

    local cert_name=""
    local cert_type=""

    if [[ "$CONFIGURATION" == "release" ]]; then
        cert_type="Developer ID Application"
        cert_name=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | awk -F'"' '{print $2}')
    else
        cert_type="Apple Development"
        cert_name=$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}')
    fi

    if [[ -n "$cert_name" ]]; then
        codesign --deep --force --sign "$cert_name" --options runtime "$app_dir" 2>&1 | grep -v "replacing existing signature" || true
        log_success "Signed with $cert_type: $cert_name"
    else
        log_warning "No $cert_type certificate found - using ad-hoc signing"
        codesign --deep --force --sign "-" "$app_dir" 2>&1 | grep -v "replacing existing signature" || true
    fi

    # Verify signature
    if codesign --verify --deep --strict "$app_dir" 2>/dev/null; then
        log_success "Signature verification passed"
    else
        log_warning "Signature verification failed — app may not launch"
    fi

    log_success "App bundle created at $app_dir"
}

run_app() {
    if [[ "$DO_RUN" == false ]]; then
        log_info "Skipping app launch (--no-run)"
        return 0
    fi

    log_step "Launching Application"

    local app_path="builds/macos/Runic.app"

    if [[ ! -d "$app_path" ]]; then
        log_error "App bundle not found at $app_path"
        return 1
    fi

    log_info "Opening $app_path..."
    open "$app_path"
    log_success "Application launched"
}

################################################################################
# Main Script
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-build)
                DO_BUILD=false
                shift
                ;;
            --no-run)
                DO_RUN=false
                shift
                ;;
            --debug)
                CONFIGURATION="debug"
                shift
                ;;
            --clean)
                DO_CLEAN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
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

    local start_time=$(date +%s)

    log_step "Building and Running Runic"

    clean_build
    build_executable || exit 1
    create_app_bundle || exit 1
    run_app

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    log_success "Completed in ${duration}s"

    if [[ "$DO_RUN" == false ]]; then
        echo ""
        log_info "To run the app: open builds/macos/Runic.app"
    fi
}

main "$@"
