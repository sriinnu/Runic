#!/usr/bin/env bash

################################################################################
# setup-all.sh
#
# Purpose: One-command setup for all Runic platforms
#
# Description:
#   - Detects current platform
#   - Runs appropriate setup scripts for all available platforms
#   - Sets up macOS, iOS, React Native (Android/Windows) projects
#   - Installs all dependencies
#   - Prepares entire project for development
#
# Usage:
#   ./setup-all.sh [OPTIONS]
#
# Options:
#   --dry-run         Show what would be done without executing
#   --verbose         Enable verbose output
#   --only-macos      Only setup macOS
#   --only-ios        Only setup iOS
#   --only-rn         Only setup React Native
#   --skip-macos      Skip macOS setup
#   --skip-ios        Skip iOS setup
#   --skip-rn         Skip React Native setup
#   --help            Show this help message
#
# Requirements:
#   Platform-dependent (see individual setup scripts)
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
ONLY_MACOS=false
ONLY_IOS=false
ONLY_RN=false
SKIP_MACOS=false
SKIP_IOS=false
SKIP_RN=false

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

log_section() {
    echo -e "\n${MAGENTA}${BOLD}$*${RESET}"
    echo -e "${MAGENTA}$(printf '=%.0s' {1..80})${RESET}\n"
}

show_help() {
    sed -n '/^# Purpose:/,/^################################################################################$/p' "$0" | sed 's/^# \?//'
}

################################################################################
# Setup Orchestration
################################################################################

detect_platform() {
    local platform=$(uname)
    log_info "Detected platform: $platform"

    case "$platform" in
        Darwin)
            log_info "Running on macOS - can build macOS and iOS"
            return 0
            ;;
        Linux)
            log_info "Running on Linux - can build React Native (Android)"
            SKIP_MACOS=true
            SKIP_IOS=true
            return 0
            ;;
        MINGW*|MSYS*|CYGWIN*)
            log_info "Running on Windows - can build React Native (Android/Windows)"
            SKIP_MACOS=true
            SKIP_IOS=true
            return 0
            ;;
        *)
            log_warning "Unknown platform: $platform"
            return 0
            ;;
    esac
}

check_script_exists() {
    local script=$1
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
        return 0
    else
        log_error "Setup script not found: $script"
        return 1
    fi
}

run_setup_script() {
    local script=$1
    local description=$2
    shift 2
    local args=("$@")

    log_section "$description"

    if ! check_script_exists "$script"; then
        log_warning "Skipping $description (script not found)"
        return 0
    fi

    # Make script executable
    chmod +x "$SCRIPT_DIR/$script"

    # Build command
    local cmd="$SCRIPT_DIR/$script"

    # Add common flags
    if [[ "$DRY_RUN" == true ]]; then
        cmd="$cmd --dry-run"
    fi
    if [[ "$VERBOSE" == true ]]; then
        cmd="$cmd --verbose"
    fi

    # Add additional args
    for arg in "${args[@]}"; do
        cmd="$cmd $arg"
    done

    log_info "Running: $cmd"
    eval "$cmd"

    log_success "$description completed"
}

setup_macos() {
    if [[ "$SKIP_MACOS" == true ]]; then
        log_info "Skipping macOS setup"
        return 0
    fi

    # macOS setup is primarily Swift Package Manager
    log_section "Setting Up macOS Project"

    cd "$PROJECT_ROOT"

    log_info "Resolving Swift Package dependencies..."
    if [[ "$DRY_RUN" == false ]]; then
        swift package resolve
    else
        log_warning "[DRY-RUN] Would run: swift package resolve"
    fi

    # Check for SwiftLint
    if command -v swiftlint &> /dev/null; then
        log_success "SwiftLint is installed"
    else
        log_warning "SwiftLint not installed (recommended)"
        log_info "Install with: brew install swiftlint"
    fi

    # Check for SwiftFormat
    if command -v swiftformat &> /dev/null; then
        log_success "SwiftFormat is installed"
    else
        log_warning "SwiftFormat not installed (optional)"
        log_info "Install with: brew install swiftformat"
    fi

    log_success "macOS setup completed"
}

setup_all() {
    log_step "Starting Complete Runic Setup"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "Running in DRY-RUN mode - no changes will be made"
    fi

    local start_time=$(date +%s)

    # Detect platform capabilities
    detect_platform

    # Determine what to setup
    local setup_macos=true
    local setup_ios=true
    local setup_rn=true

    if [[ "$ONLY_MACOS" == true ]]; then
        setup_ios=false
        setup_rn=false
    fi

    if [[ "$ONLY_IOS" == true ]]; then
        setup_macos=false
        setup_rn=false
    fi

    if [[ "$ONLY_RN" == true ]]; then
        setup_macos=false
        setup_ios=false
    fi

    if [[ "$SKIP_MACOS" == true ]]; then
        setup_macos=false
    fi

    if [[ "$SKIP_IOS" == true ]]; then
        setup_ios=false
    fi

    if [[ "$SKIP_RN" == true ]]; then
        setup_rn=false
    fi

    # Run setups
    local setup_count=0

    if [[ "$setup_macos" == true ]]; then
        setup_macos
        ((setup_count++))
    fi

    if [[ "$setup_ios" == true ]]; then
        if [[ -d "$PROJECT_ROOT/RuniciOS" ]]; then
            run_setup_script "setup-ios.sh" "iOS Setup"
            ((setup_count++))
        else
            log_warning "iOS project directory not found, skipping iOS setup"
        fi
    fi

    if [[ "$setup_rn" == true ]]; then
        if [[ -d "$PROJECT_ROOT/runic-cross-platform" ]]; then
            run_setup_script "setup-react-native.sh" "React Native Setup"
            ((setup_count++))
        else
            log_warning "React Native project directory not found, skipping React Native setup"
        fi
    fi

    # Setup summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_section "Setup Complete!"

    log_success "Completed $setup_count platform setup(s) in ${duration}s"
    log_info ""
    log_info "Project structure:"
    log_info "  macOS:         $PROJECT_ROOT (Swift Package Manager)"
    log_info "  iOS:           $PROJECT_ROOT/RuniciOS"
    log_info "  React Native:  $PROJECT_ROOT/runic-cross-platform"
    log_info ""
    log_info "Next steps:"
    log_info "  Build macOS:   ./scripts/build-macos.sh"
    log_info "  Build iOS:     ./scripts/build-ios.sh"
    log_info "  Build Android: ./scripts/build-android.sh"
    log_info "  Build Windows: ./scripts/build-windows.sh"
    log_info ""
    log_info "Run all builds: ./scripts/build-all.sh"
    log_info ""
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
            --only-macos)
                ONLY_MACOS=true
                shift
                ;;
            --only-ios)
                ONLY_IOS=true
                shift
                ;;
            --only-rn)
                ONLY_RN=true
                shift
                ;;
            --skip-macos)
                SKIP_MACOS=true
                shift
                ;;
            --skip-ios)
                SKIP_IOS=true
                shift
                ;;
            --skip-rn)
                SKIP_RN=true
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

    # Validate conflicting options
    if [[ "$ONLY_MACOS" == true ]] && [[ "$SKIP_MACOS" == true ]]; then
        log_error "Cannot use --only-macos and --skip-macos together"
        exit 1
    fi

    if [[ "$ONLY_IOS" == true ]] && [[ "$SKIP_IOS" == true ]]; then
        log_error "Cannot use --only-ios and --skip-ios together"
        exit 1
    fi

    if [[ "$ONLY_RN" == true ]] && [[ "$SKIP_RN" == true ]]; then
        log_error "Cannot use --only-rn and --skip-rn together"
        exit 1
    fi

    setup_all
}

main "$@"
