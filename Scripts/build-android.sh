#!/usr/bin/env bash

################################################################################
# build-android.sh
#
# Purpose: Build Android application
#
# Description:
#   - Builds Runic Android app using Gradle
#   - Runs tests and lint checks
#   - Creates APK or AAB for distribution
#   - Supports different build variants
#   - Outputs build artifacts to standardized location
#
# Usage:
#   ./build-android.sh [OPTIONS]
#
# Options:
#   --dry-run           Show what would be done without executing
#   --verbose           Enable verbose output
#   --skip-tests        Skip running tests
#   --skip-lint         Skip lint checks
#   --variant           Build variant (debug|release) [default: release]
#   --output-dir        Output directory for build artifacts
#   --aab               Build Android App Bundle (AAB) instead of APK
#   --clean             Clean build directory before building
#   --help              Show this help message
#
# Requirements:
#   - Java Development Kit 17+
#   - Android SDK
#   - ANDROID_HOME environment variable set
#   - Node.js (for React Native)
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
ANDROID_PROJECT_DIR="$PROJECT_ROOT/runic-cross-platform"

DRY_RUN=false
VERBOSE=false
SKIP_TESTS=false
SKIP_LINT=false
VARIANT="release"
OUTPUT_DIR="$PROJECT_ROOT/builds/android"
BUILD_AAB=false
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

    local all_ok=true

    # Check Java
    if ! command -v java &> /dev/null; then
        log_error "Java is not installed"
        log_info "Install JDK 17: https://adoptium.net"
        all_ok=false
    else
        local java_version
        java_version=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
        log_success "Java installed: $java_version"
    fi

    # Check ANDROID_HOME
    if [[ -z "${ANDROID_HOME:-}" ]] && [[ -z "${ANDROID_SDK_ROOT:-}" ]]; then
        log_error "ANDROID_HOME is not set"
        log_info "Set ANDROID_HOME to your Android SDK location"
        all_ok=false
    else
        log_success "ANDROID_HOME is set: ${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
    fi

    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed"
        all_ok=false
    else
        log_success "Node.js installed: $(node --version)"
    fi

    # Check Android project
    if [[ ! -d "$ANDROID_PROJECT_DIR" ]]; then
        log_error "Android project directory not found: $ANDROID_PROJECT_DIR"
        all_ok=false
    fi

    if [[ ! -d "$ANDROID_PROJECT_DIR/android" ]]; then
        log_error "Android subdirectory not found: $ANDROID_PROJECT_DIR/android"
        log_info "Initialize with: npx react-native init"
        all_ok=false
    fi

    if [[ "$all_ok" == false ]]; then
        log_error "Some prerequisites are missing"
        return 1
    fi

    log_success "All prerequisites satisfied"
}

setup_environment() {
    log_step "Setting Up Environment"

    cd "$ANDROID_PROJECT_DIR"

    # Install npm dependencies if needed
    if [[ ! -d "node_modules" ]]; then
        log_info "Installing npm dependencies..."
        run_cmd "npm install"
    else
        log_info "npm dependencies already installed"
    fi

    # Create local.properties if needed
    local local_props="android/local.properties"
    if [[ ! -f "$local_props" ]] && [[ -n "${ANDROID_HOME:-}" ]]; then
        log_info "Creating local.properties..."
        if [[ "$DRY_RUN" == false ]]; then
            echo "sdk.dir=${ANDROID_HOME}" > "$local_props"
        fi
    fi

    log_success "Environment setup complete"
}

clean_build_directory() {
    if [[ "$CLEAN_BUILD" == false ]]; then
        return 0
    fi

    log_step "Cleaning Build Directory"

    cd "$ANDROID_PROJECT_DIR/android"

    if [[ -f "gradlew" ]]; then
        run_cmd "./gradlew clean"
        log_success "Build directory cleaned"
    else
        log_warning "gradlew not found, skipping clean"
    fi
}

run_lint() {
    if [[ "$SKIP_LINT" == true ]]; then
        log_info "Skipping lint checks (--skip-lint)"
        return 0
    fi

    log_step "Running Lint Checks"

    cd "$ANDROID_PROJECT_DIR/android"

    if [[ -f "gradlew" ]]; then
        log_info "Running Android lint..."
        run_cmd "./gradlew lint"
        log_success "Lint checks completed"

        # Check for lint report
        if [[ -f "app/build/reports/lint-results.html" ]]; then
            log_info "Lint report: $ANDROID_PROJECT_DIR/android/app/build/reports/lint-results.html"
        fi
    else
        log_warning "gradlew not found, skipping lint"
    fi
}

run_tests() {
    if [[ "$SKIP_TESTS" == true ]]; then
        log_info "Skipping tests (--skip-tests)"
        return 0
    fi

    log_step "Running Tests"

    cd "$ANDROID_PROJECT_DIR/android"

    if [[ -f "gradlew" ]]; then
        log_info "Running Android tests..."
        run_cmd "./gradlew test"
        log_success "Tests completed"

        # Check for test reports
        if [[ -d "app/build/reports/tests" ]]; then
            log_info "Test reports: $ANDROID_PROJECT_DIR/android/app/build/reports/tests"
        fi
    else
        log_warning "gradlew not found, skipping tests"
    fi
}

build_apk() {
    log_step "Building Android APK"

    cd "$ANDROID_PROJECT_DIR/android"

    if [[ ! -f "gradlew" ]]; then
        log_error "gradlew not found"
        return 1
    fi

    # Capitalize variant for Gradle task
    local gradle_variant
    if [[ "$VARIANT" == "release" ]]; then
        gradle_variant="Release"
    else
        gradle_variant="Debug"
    fi

    local build_cmd="./gradlew assemble${gradle_variant}"

    if [[ "$VERBOSE" == true ]]; then
        build_cmd="$build_cmd --info"
    fi

    log_info "Building APK with variant: $VARIANT"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY-RUN] Would run: $build_cmd"
        return 0
    fi

    if eval "$build_cmd"; then
        log_success "APK build completed successfully"
    else
        log_error "APK build failed"
        return 1
    fi

    # Find and copy APK
    local apk_path="app/build/outputs/apk/${VARIANT}/app-${VARIANT}.apk"

    if [[ -f "$apk_path" ]]; then
        mkdir -p "$OUTPUT_DIR"
        cp "$apk_path" "$OUTPUT_DIR/"
        log_success "APK copied to: $OUTPUT_DIR/app-${VARIANT}.apk"

        # Get APK size
        local size
        size=$(du -h "$apk_path" | cut -f1)
        log_info "APK size: $size"
    else
        log_warning "APK not found at expected location: $apk_path"
    fi
}

build_aab() {
    log_step "Building Android App Bundle (AAB)"

    cd "$ANDROID_PROJECT_DIR/android"

    if [[ ! -f "gradlew" ]]; then
        log_error "gradlew not found"
        return 1
    fi

    # AAB is typically for release only
    local build_cmd="./gradlew bundleRelease"

    if [[ "$VERBOSE" == true ]]; then
        build_cmd="$build_cmd --info"
    fi

    log_info "Building AAB..."

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY-RUN] Would run: $build_cmd"
        return 0
    fi

    if eval "$build_cmd"; then
        log_success "AAB build completed successfully"
    else
        log_error "AAB build failed"
        return 1
    fi

    # Find and copy AAB
    local aab_path="app/build/outputs/bundle/release/app-release.aab"

    if [[ -f "$aab_path" ]]; then
        mkdir -p "$OUTPUT_DIR"
        cp "$aab_path" "$OUTPUT_DIR/"
        log_success "AAB copied to: $OUTPUT_DIR/app-release.aab"

        # Get AAB size
        local size
        size=$(du -h "$aab_path" | cut -f1)
        log_info "AAB size: $size"
    else
        log_warning "AAB not found at expected location: $aab_path"
    fi
}

sign_apk() {
    if [[ "$VARIANT" != "release" ]]; then
        log_info "Debug build - signing not needed"
        return 0
    fi

    log_step "Checking Code Signing"

    cd "$ANDROID_PROJECT_DIR/android"

    # Check for keystore configuration
    local keystore_props="keystore.properties"

    if [[ -f "$keystore_props" ]]; then
        log_success "Keystore configuration found"
        log_info "APK will be signed during build"
    else
        log_warning "No keystore configuration found"
        log_info ""
        log_info "To sign your release APK:"
        log_info "  1. Generate keystore: keytool -genkey -v -keystore my-release-key.keystore ..."
        log_info "  2. Create keystore.properties:"
        log_info "     storePassword=YOUR_STORE_PASSWORD"
        log_info "     keyPassword=YOUR_KEY_PASSWORD"
        log_info "     keyAlias=YOUR_KEY_ALIAS"
        log_info "     storeFile=path/to/my-release-key.keystore"
        log_info "  3. Update app/build.gradle to use keystore.properties"
        log_info ""
        log_warning "Release APK will be unsigned"
    fi
}

build_summary() {
    log_step "Build Summary"

    log_success "Android build completed successfully!"
    log_info ""
    log_info "Build artifacts: $OUTPUT_DIR"

    if [[ -f "$OUTPUT_DIR/app-${VARIANT}.apk" ]]; then
        log_info "  APK: $OUTPUT_DIR/app-${VARIANT}.apk"
    fi

    if [[ -f "$OUTPUT_DIR/app-release.aab" ]]; then
        log_info "  AAB: $OUTPUT_DIR/app-release.aab"
    fi

    log_info ""
    log_info "Next steps:"

    if [[ "$VARIANT" == "debug" ]]; then
        log_info "  Install on device: adb install $OUTPUT_DIR/app-debug.apk"
    else
        log_info "  Test on device: adb install $OUTPUT_DIR/app-release.apk"
        log_info "  Upload to Play Console: Use the AAB file"
    fi

    log_info ""
}

run_build() {
    log_step "Starting Android Build"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "Running in DRY-RUN mode - no changes will be made"
    fi

    local start_time=$(date +%s)

    check_prerequisites || exit 1
    setup_environment
    clean_build_directory
    run_lint
    run_tests || log_warning "Tests failed, continuing with build..."
    sign_apk

    if [[ "$BUILD_AAB" == true ]]; then
        build_aab || exit 1
    else
        build_apk || exit 1
    fi

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
            --skip-lint)
                SKIP_LINT=true
                shift
                ;;
            --variant)
                VARIANT="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --aab)
                BUILD_AAB=true
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

    # Validate variant
    if [[ "$VARIANT" != "debug" ]] && [[ "$VARIANT" != "release" ]]; then
        log_error "Invalid variant: $VARIANT"
        log_info "Use 'debug' or 'release'"
        exit 1
    fi

    run_build
}

main "$@"
