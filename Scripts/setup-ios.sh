#!/usr/bin/env bash

################################################################################
# setup-ios.sh
#
# Purpose: Setup iOS Xcode project for Runic
#
# Description:
#   - Checks for required dependencies (Xcode, CocoaPods, etc.)
#   - Installs iOS dependencies
#   - Generates/updates Xcode project
#   - Sets up code signing (with placeholders)
#   - Prepares project for development
#
# Usage:
#   ./setup-ios.sh [OPTIONS]
#
# Options:
#   --dry-run     Show what would be done without executing
#   --verbose     Enable verbose output
#   --skip-pods   Skip CocoaPods installation
#   --help        Show this help message
#
# Requirements:
#   - macOS 14.0+
#   - Xcode 15.0+
#   - Command Line Tools
#   - Ruby (for CocoaPods)
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
SKIP_PODS=false

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

check_command() {
    local cmd=$1
    local install_hint=$2

    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd is not installed"
        log_info "Install hint: $install_hint"
        return 1
    else
        log_success "$cmd is installed"
        if [[ "$VERBOSE" == true ]]; then
            local version
            version=$($cmd --version 2>&1 | head -n 1 || echo "version unknown")
            log_info "  $version"
        fi
        return 0
    fi
}

show_help() {
    sed -n '/^# Purpose:/,/^################################################################################$/p' "$0" | sed 's/^# \?//'
}

################################################################################
# Prerequisite Checks
################################################################################

check_prerequisites() {
    log_step "Checking Prerequisites"

    local all_ok=true

    # Check macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script must be run on macOS"
        return 1
    fi
    log_success "Running on macOS $(sw_vers -productVersion)"

    # Check Xcode
    if ! xcodebuild -version &> /dev/null; then
        log_error "Xcode is not installed or command line tools are not configured"
        log_info "Install Xcode from the App Store"
        log_info "Then run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
        all_ok=false
    else
        local xcode_version
        xcode_version=$(xcodebuild -version | head -n 1)
        log_success "$xcode_version installed"

        # Check Xcode version
        local xcode_major
        xcode_major=$(xcodebuild -version | head -n 1 | awk '{print $2}' | cut -d. -f1)
        if [[ $xcode_major -lt 15 ]]; then
            log_warning "Xcode 15.0+ is recommended (found version $xcode_major)"
        fi
    fi

    # Check Ruby
    if ! check_command ruby "Ruby is pre-installed on macOS"; then
        all_ok=false
    fi

    # Check Git
    if ! check_command git "xcode-select --install"; then
        all_ok=false
    fi

    # Check for CocoaPods (optional)
    if command -v pod &> /dev/null; then
        log_success "CocoaPods is installed"
        if [[ "$VERBOSE" == true ]]; then
            pod --version | sed 's/^/  /'
        fi
    else
        log_warning "CocoaPods is not installed (optional)"
        log_info "Install with: sudo gem install cocoapods"
    fi

    # Check for SwiftLint (optional)
    if command -v swiftlint &> /dev/null; then
        log_success "SwiftLint is installed"
    else
        log_warning "SwiftLint is not installed (recommended)"
        log_info "Install with: brew install swiftlint"
    fi

    if [[ "$all_ok" == false ]]; then
        log_error "Some prerequisites are missing. Please install them and try again."
        return 1
    fi

    log_success "All prerequisites satisfied"
    return 0
}

################################################################################
# Setup Functions
################################################################################

setup_ios_project() {
    log_step "Setting Up iOS Project"

    if [[ ! -d "$IOS_PROJECT_DIR" ]]; then
        log_error "iOS project directory not found: $IOS_PROJECT_DIR"
        return 1
    fi

    cd "$IOS_PROJECT_DIR"

    # Check if we need to generate Xcode project
    local xcodeproj_exists=false
    local workspace_exists=false

    if ls *.xcodeproj &> /dev/null; then
        xcodeproj_exists=true
        log_info "Found existing Xcode project"
    fi

    if ls *.xcworkspace &> /dev/null; then
        workspace_exists=true
        log_info "Found existing Xcode workspace"
    fi

    # For now, iOS project uses standard Xcode project structure
    # If using SPM, we might need to generate project
    if [[ "$xcodeproj_exists" == false ]] && [[ "$workspace_exists" == false ]]; then
        log_warning "No Xcode project or workspace found"
        log_info "You may need to create an Xcode project manually or use xcodegen"

        # Placeholder for xcodegen if project.yml exists
        if [[ -f "project.yml" ]]; then
            if command -v xcodegen &> /dev/null; then
                log_info "Generating Xcode project from project.yml"
                run_cmd "xcodegen generate"
            else
                log_warning "xcodegen not found. Install with: brew install xcodegen"
            fi
        fi
    fi

    log_success "iOS project setup complete"
}

install_dependencies() {
    log_step "Installing iOS Dependencies"

    cd "$IOS_PROJECT_DIR"

    # Install CocoaPods dependencies if Podfile exists
    if [[ -f "Podfile" ]] && [[ "$SKIP_PODS" == false ]]; then
        if ! command -v pod &> /dev/null; then
            log_warning "CocoaPods not installed, skipping pod install"
        else
            log_info "Installing CocoaPods dependencies..."
            run_cmd "pod install --repo-update"
            log_success "CocoaPods dependencies installed"
        fi
    else
        log_info "No Podfile found or --skip-pods specified, skipping CocoaPods"
    fi

    # Install Swift Package Manager dependencies
    if ls *.xcworkspace &> /dev/null; then
        local workspace
        workspace=$(ls *.xcworkspace | head -n 1)
        log_info "Resolving Swift Package dependencies for workspace..."
        run_cmd "xcodebuild -workspace \"$workspace\" -scheme RuniciOS -resolvePackageDependencies"
    elif ls *.xcodeproj &> /dev/null; then
        local project
        project=$(ls *.xcodeproj | head -n 1)
        log_info "Resolving Swift Package dependencies for project..."
        run_cmd "xcodebuild -project \"$project\" -scheme RuniciOS -resolvePackageDependencies"
    fi

    log_success "Dependencies installed"
}

setup_code_signing() {
    log_step "Setting Up Code Signing"

    log_warning "Code signing setup is manual for security reasons"
    log_info ""
    log_info "To configure code signing:"
    log_info "  1. Open the Xcode project"
    log_info "  2. Select the 'RuniciOS' target"
    log_info "  3. Go to 'Signing & Capabilities'"
    log_info "  4. Select your team and configure automatic signing"
    log_info ""
    log_info "For CI/CD, you'll need to:"
    log_info "  - Create certificates and provisioning profiles in Apple Developer Portal"
    log_info "  - Add them to your CI environment as secrets"
    log_info "  - Configure fastlane or xcodebuild to use them"
    log_info ""

    # Check for existing certificates
    if [[ "$VERBOSE" == true ]]; then
        log_info "Available signing identities:"
        security find-identity -v -p codesigning 2>/dev/null || log_warning "No signing identities found"
    fi
}

create_local_config() {
    log_step "Creating Local Configuration"

    local config_file="$IOS_PROJECT_DIR/Config.xcconfig"

    if [[ -f "$config_file" ]]; then
        log_info "Configuration file already exists: $config_file"
    else
        log_info "Creating configuration file: $config_file"

        if [[ "$DRY_RUN" == false ]]; then
            cat > "$config_file" << 'EOF'
// Local iOS Configuration
// DO NOT commit this file if it contains sensitive information

// Team ID for code signing (replace with your team ID)
// DEVELOPMENT_TEAM = YOUR_TEAM_ID

// Bundle Identifier
// PRODUCT_BUNDLE_IDENTIFIER = com.yourcompany.runic

// Code Signing Identity
// CODE_SIGN_IDENTITY = Apple Development

// Provisioning Profile
// PROVISIONING_PROFILE_SPECIFIER =

EOF
            log_success "Created configuration template: $config_file"
            log_info "Edit this file to add your team ID and signing configuration"
        fi
    fi
}

run_setup() {
    log_step "Starting iOS Setup"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "Running in DRY-RUN mode - no changes will be made"
    fi

    check_prerequisites || exit 1
    setup_ios_project || exit 1
    install_dependencies || exit 1
    setup_code_signing
    create_local_config

    log_step "iOS Setup Complete!"
    log_success "Your iOS project is ready for development"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Configure code signing in Xcode"
    log_info "  2. Edit $IOS_PROJECT_DIR/Config.xcconfig with your team info"
    log_info "  3. Build the project: ./scripts/build-ios.sh"
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
            --skip-pods)
                SKIP_PODS=true
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

    run_setup
}

main "$@"
