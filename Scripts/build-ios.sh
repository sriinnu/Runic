#!/usr/bin/env bash

################################################################################
# build-ios.sh
#
# Purpose: Build iOS application
#
# Description:
#   - Builds Runic iOS app using Xcode
#   - Runs tests before building
#   - Creates IPA for distribution
#   - Supports different build configurations
#   - Outputs build artifacts to standardized location
#
# Usage:
#   ./build-ios.sh [OPTIONS]
#
# Options:
#   --dry-run           Show what would be done without executing
#   --verbose           Enable verbose output
#   --skip-tests        Skip running tests
#   --configuration     Build configuration (Debug|Release) [default: Release]
#   --scheme            Build scheme [default: RuniciOS]
#   --output-dir        Output directory for build artifacts
#   --simulator         Build for iOS Simulator
#   --device            Build for iOS Device [default]
#   --archive           Create archive and IPA
#   --clean             Clean build directory before building
#   --help              Show this help message
#
# Requirements:
#   - macOS 14.0+
#   - Xcode 15.0+
#   - iOS SDK 17.0+
#   - Configured code signing
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
IOS_PROJECT_DIR="$PROJECT_ROOT/RuniciOS"

DRY_RUN=false
VERBOSE=false
SKIP_TESTS=false
CONFIGURATION="Release"
SCHEME="RuniciOS"
OUTPUT_DIR="$PROJECT_ROOT/builds/ios"
BUILD_SIMULATOR=false
BUILD_DEVICE=true
CREATE_ARCHIVE=false
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

    # Check Xcode
    if ! xcodebuild -version &> /dev/null; then
        log_error "Xcode is not installed"
        return 1
    fi

    local xcode_version
    xcode_version=$(xcodebuild -version | head -n 1)
    log_success "$xcode_version installed"

    # Check iOS project
    if [[ ! -d "$IOS_PROJECT_DIR" ]]; then
        log_error "iOS project directory not found: $IOS_PROJECT_DIR"
        return 1
    fi

    log_success "All prerequisites satisfied"
}

find_project_or_workspace() {
    cd "$IOS_PROJECT_DIR"

    # Prefer workspace over project
    if ls *.xcworkspace &> /dev/null 2>&1; then
        WORKSPACE=$(ls *.xcworkspace | head -n 1)
        log_info "Using workspace: $WORKSPACE"
        echo "-workspace $WORKSPACE"
    elif ls *.xcodeproj &> /dev/null 2>&1; then
        PROJECT=$(ls *.xcodeproj | head -n 1)
        log_info "Using project: $PROJECT"
        echo "-project $PROJECT"
    else
        log_error "No Xcode project or workspace found"
        return 1
    fi
}

clean_build_directory() {
    if [[ "$CLEAN_BUILD" == false ]]; then
        return 0
    fi

    log_step "Cleaning Build Directory"

    cd "$IOS_PROJECT_DIR"

    local project_arg
    project_arg=$(find_project_or_workspace)

    if [[ "$DRY_RUN" == false ]]; then
        log_info "Cleaning build directory..."
        xcodebuild $project_arg -scheme "$SCHEME" clean
        log_success "Build directory cleaned"
    fi
}

run_tests() {
    if [[ "$SKIP_TESTS" == true ]]; then
        log_info "Skipping tests (--skip-tests)"
        return 0
    fi

    log_step "Running Tests"

    cd "$IOS_PROJECT_DIR"

    local project_arg
    project_arg=$(find_project_or_workspace)

    log_info "Running iOS tests..."

    local test_cmd="xcodebuild $project_arg -scheme $SCHEME"
    test_cmd="$test_cmd -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'"
    test_cmd="$test_cmd test"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY-RUN] Would run: $test_cmd"
        return 0
    fi

    if [[ "$VERBOSE" == true ]]; then
        eval "$test_cmd"
    else
        eval "$test_cmd" | grep -E "Test Suite|Test Case|Testing failed|Testing passed" || true
    fi

    log_success "Tests completed"
}

build_for_simulator() {
    log_step "Building for iOS Simulator"

    cd "$IOS_PROJECT_DIR"

    local project_arg
    project_arg=$(find_project_or_workspace)

    local build_cmd="xcodebuild $project_arg"
    build_cmd="$build_cmd -scheme $SCHEME"
    build_cmd="$build_cmd -configuration $CONFIGURATION"
    build_cmd="$build_cmd -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'"
    build_cmd="$build_cmd -derivedDataPath $OUTPUT_DIR/DerivedData"

    if [[ "$VERBOSE" == true ]]; then
        build_cmd="$build_cmd -verbose"
    fi

    log_info "Building: $build_cmd"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY-RUN] Would run: $build_cmd"
        return 0
    fi

    if eval "$build_cmd"; then
        log_success "Simulator build completed successfully"
    else
        log_error "Simulator build failed"
        return 1
    fi
}

build_for_device() {
    log_step "Building for iOS Device"

    cd "$IOS_PROJECT_DIR"

    local project_arg
    project_arg=$(find_project_or_workspace)

    local build_cmd="xcodebuild $project_arg"
    build_cmd="$build_cmd -scheme $SCHEME"
    build_cmd="$build_cmd -configuration $CONFIGURATION"
    build_cmd="$build_cmd -destination 'generic/platform=iOS'"
    build_cmd="$build_cmd -derivedDataPath $OUTPUT_DIR/DerivedData"

    if [[ "$VERBOSE" == true ]]; then
        build_cmd="$build_cmd -verbose"
    fi

    log_info "Building: $build_cmd"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY-RUN] Would run: $build_cmd"
        return 0
    fi

    if eval "$build_cmd"; then
        log_success "Device build completed successfully"
    else
        log_error "Device build failed"
        log_info "Make sure code signing is properly configured"
        return 1
    fi
}

create_archive_and_ipa() {
    if [[ "$CREATE_ARCHIVE" == false ]]; then
        log_info "Skipping archive creation (use --archive to enable)"
        return 0
    fi

    log_step "Creating Archive and IPA"

    cd "$IOS_PROJECT_DIR"

    local project_arg
    project_arg=$(find_project_or_workspace)

    local archive_path="$OUTPUT_DIR/$SCHEME.xcarchive"
    local export_path="$OUTPUT_DIR/Export"

    # Create archive
    log_info "Creating archive..."

    local archive_cmd="xcodebuild $project_arg"
    archive_cmd="$archive_cmd -scheme $SCHEME"
    archive_cmd="$archive_cmd -configuration $CONFIGURATION"
    archive_cmd="$archive_cmd -archivePath $archive_path"
    archive_cmd="$archive_cmd archive"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY-RUN] Would run: $archive_cmd"
        return 0
    fi

    if ! eval "$archive_cmd"; then
        log_error "Archive creation failed"
        return 1
    fi

    log_success "Archive created: $archive_path"

    # Create export options plist
    local export_options="$OUTPUT_DIR/ExportOptions.plist"

    cat > "$export_options" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

    log_warning "Export options created with placeholder team ID"
    log_info "Edit $export_options and replace YOUR_TEAM_ID with your actual team ID"
    log_info "For App Store distribution, change method to 'app-store'"

    # Export IPA
    log_info "Exporting IPA..."

    local export_cmd="xcodebuild -exportArchive"
    export_cmd="$export_cmd -archivePath $archive_path"
    export_cmd="$export_cmd -exportPath $export_path"
    export_cmd="$export_cmd -exportOptionsPlist $export_options"

    if eval "$export_cmd" 2>/dev/null; then
        log_success "IPA exported to: $export_path"

        # Find and display IPA info
        if ls "$export_path"/*.ipa &> /dev/null; then
            local ipa_file
            ipa_file=$(ls "$export_path"/*.ipa | head -n 1)
            local size
            size=$(du -h "$ipa_file" | cut -f1)
            log_info "IPA size: $size"
        fi
    else
        log_warning "IPA export failed (likely due to placeholder team ID)"
        log_info "Archive is still available at: $archive_path"
        log_info "Export manually from Xcode or update ExportOptions.plist"
    fi
}

build_summary() {
    log_step "Build Summary"

    log_success "iOS build completed successfully!"
    log_info ""
    log_info "Build artifacts location: $OUTPUT_DIR"

    if [[ "$BUILD_SIMULATOR" == true ]]; then
        log_info "  Simulator build: Available in DerivedData"
    fi

    if [[ "$BUILD_DEVICE" == true ]]; then
        log_info "  Device build: Available in DerivedData"
    fi

    if [[ "$CREATE_ARCHIVE" == true ]] && [[ -d "$OUTPUT_DIR/$SCHEME.xcarchive" ]]; then
        log_info "  Archive: $OUTPUT_DIR/$SCHEME.xcarchive"

        if ls "$OUTPUT_DIR/Export"/*.ipa &> /dev/null 2>&1; then
            log_info "  IPA: $OUTPUT_DIR/Export/*.ipa"
        fi
    fi

    log_info ""
    log_info "Next steps:"

    if [[ "$BUILD_SIMULATOR" == true ]]; then
        log_info "  Run in simulator: Open Xcode and run the scheme"
    fi

    if [[ "$CREATE_ARCHIVE" == true ]]; then
        log_info "  Upload to TestFlight: Use Xcode or altool"
        log_info "  Install on device: Use Xcode Devices or iTunes"
    fi

    log_info ""
}

run_build() {
    log_step "Starting iOS Build"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "Running in DRY-RUN mode - no changes will be made"
    fi

    local start_time=$(date +%s)

    # Create output directory
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$OUTPUT_DIR"
    fi

    check_prerequisites || exit 1
    clean_build_directory

    if [[ "$SKIP_TESTS" == false ]]; then
        run_tests || log_warning "Tests failed, continuing with build..."
    fi

    if [[ "$BUILD_SIMULATOR" == true ]]; then
        build_for_simulator || exit 1
    fi

    if [[ "$BUILD_DEVICE" == true ]]; then
        build_for_device || exit 1
    fi

    create_archive_and_ipa

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
            --scheme)
                SCHEME="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --simulator)
                BUILD_SIMULATOR=true
                BUILD_DEVICE=false
                shift
                ;;
            --device)
                BUILD_DEVICE=true
                BUILD_SIMULATOR=false
                shift
                ;;
            --archive)
                CREATE_ARCHIVE=true
                BUILD_DEVICE=true
                shift
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

    run_build
}

main "$@"
