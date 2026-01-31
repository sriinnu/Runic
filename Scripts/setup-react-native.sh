#!/usr/bin/env bash

################################################################################
# setup-react-native.sh
#
# Purpose: Setup React Native project for Windows and Android
#
# Description:
#   - Checks for required dependencies (Node.js, npm, Java, Android SDK)
#   - Installs React Native dependencies
#   - Sets up Android SDK and emulator
#   - Configures Windows React Native environment
#   - Prepares project for development
#
# Usage:
#   ./setup-react-native.sh [OPTIONS]
#
# Options:
#   --dry-run         Show what would be done without executing
#   --verbose         Enable verbose output
#   --skip-android    Skip Android setup
#   --skip-windows    Skip Windows setup
#   --help            Show this help message
#
# Requirements:
#   - Node.js 18+
#   - npm or yarn
#   - Java Development Kit 17+
#   - Android SDK (for Android)
#   - Windows 10+ with Visual Studio (for Windows)
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
RN_PROJECT_DIR="$PROJECT_ROOT/runic-cross-platform"

DRY_RUN=false
VERBOSE=false
SKIP_ANDROID=false
SKIP_WINDOWS=false

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

    # Check Node.js
    if ! check_command node "Install from https://nodejs.org or use nvm"; then
        all_ok=false
    else
        local node_version
        node_version=$(node --version | sed 's/v//')
        local node_major
        node_major=$(echo "$node_version" | cut -d. -f1)
        if [[ $node_major -lt 18 ]]; then
            log_warning "Node.js 18+ is recommended (found version $node_version)"
        fi
    fi

    # Check npm
    if ! check_command npm "Comes with Node.js"; then
        all_ok=false
    fi

    # Check for yarn (optional)
    if command -v yarn &> /dev/null; then
        log_success "Yarn is installed"
    else
        log_info "Yarn is not installed (optional, npm will be used)"
    fi

    # Check Git
    if ! check_command git "Install from https://git-scm.com"; then
        all_ok=false
    fi

    # Platform-specific checks
    if [[ "$(uname)" == "Darwin" ]]; then
        log_info "Running on macOS - can build Android"
        check_android_prerequisites
    elif [[ "$(uname)" == "Linux" ]]; then
        log_info "Running on Linux - can build Android"
        check_android_prerequisites
    elif [[ "$(uname)" =~ MINGW|MSYS|CYGWIN ]]; then
        log_info "Running on Windows - can build Android and Windows"
        check_android_prerequisites
        check_windows_prerequisites
    fi

    # Check for Watchman (recommended for React Native on macOS)
    if [[ "$(uname)" == "Darwin" ]]; then
        if command -v watchman &> /dev/null; then
            log_success "Watchman is installed"
        else
            log_warning "Watchman is not installed (recommended for React Native)"
            log_info "Install with: brew install watchman"
        fi
    fi

    if [[ "$all_ok" == false ]]; then
        log_error "Some prerequisites are missing. Please install them and try again."
        return 1
    fi

    log_success "All prerequisites satisfied"
    return 0
}

check_android_prerequisites() {
    if [[ "$SKIP_ANDROID" == true ]]; then
        log_info "Skipping Android prerequisite checks (--skip-android)"
        return 0
    fi

    log_info "Checking Android prerequisites..."

    # Check Java
    if command -v java &> /dev/null; then
        log_success "Java is installed"
        local java_version
        java_version=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
        if [[ "$VERBOSE" == true ]]; then
            log_info "  Java version: $java_version"
        fi
    else
        log_warning "Java is not installed (required for Android)"
        log_info "Install JDK 17: https://adoptium.net"
    fi

    # Check for ANDROID_HOME
    if [[ -n "${ANDROID_HOME:-}" ]] || [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
        log_success "ANDROID_HOME is set"
        if [[ "$VERBOSE" == true ]]; then
            log_info "  ANDROID_HOME=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
        fi
    else
        log_warning "ANDROID_HOME is not set"
        log_info "Set ANDROID_HOME to your Android SDK location"
        log_info "  macOS/Linux: export ANDROID_HOME=\$HOME/Library/Android/sdk"
        log_info "  Windows: setx ANDROID_HOME %LOCALAPPDATA%\\Android\\Sdk"
    fi

    # Check for Android SDK tools
    if command -v adb &> /dev/null; then
        log_success "Android SDK platform tools are installed"
    else
        log_warning "Android SDK platform tools not found in PATH"
    fi
}

check_windows_prerequisites() {
    if [[ "$SKIP_WINDOWS" == true ]]; then
        log_info "Skipping Windows prerequisite checks (--skip-windows)"
        return 0
    fi

    log_info "Checking Windows prerequisites..."

    # This would need to be enhanced for actual Windows checks
    log_warning "Windows-specific checks not fully implemented in bash"
    log_info "Ensure you have:"
    log_info "  - Windows 10 SDK (10.0.19041.0 or higher)"
    log_info "  - Visual Studio 2022 with C++ development tools"
    log_info "  - React Native Windows CLI"
}

################################################################################
# Setup Functions
################################################################################

setup_react_native_project() {
    log_step "Setting Up React Native Project"

    if [[ ! -d "$RN_PROJECT_DIR" ]]; then
        log_error "React Native project directory not found: $RN_PROJECT_DIR"
        return 1
    fi

    cd "$RN_PROJECT_DIR"

    if [[ ! -f "package.json" ]]; then
        log_error "package.json not found in $RN_PROJECT_DIR"
        return 1
    fi

    log_success "React Native project found"
}

install_dependencies() {
    log_step "Installing Dependencies"

    cd "$RN_PROJECT_DIR"

    # Determine package manager
    local pkg_manager="npm"
    if command -v yarn &> /dev/null && [[ -f "yarn.lock" ]]; then
        pkg_manager="yarn"
    fi

    log_info "Using package manager: $pkg_manager"

    # Install dependencies
    if [[ "$pkg_manager" == "yarn" ]]; then
        run_cmd "yarn install"
    else
        run_cmd "npm install"
    fi

    log_success "Dependencies installed"
}

setup_android() {
    if [[ "$SKIP_ANDROID" == true ]]; then
        log_info "Skipping Android setup (--skip-android)"
        return 0
    fi

    log_step "Setting Up Android"

    cd "$RN_PROJECT_DIR"

    # Check if android directory exists
    if [[ ! -d "android" ]]; then
        log_warning "Android directory not found"
        log_info "You may need to initialize it with: npx react-native init"
        return 0
    fi

    # Setup local.properties with ANDROID_HOME
    local local_props="android/local.properties"
    if [[ -n "${ANDROID_HOME:-}" ]] || [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
        local sdk_dir="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
        if [[ "$DRY_RUN" == false ]]; then
            echo "sdk.dir=$sdk_dir" > "$local_props"
            log_success "Created $local_props"
        fi
    else
        log_warning "ANDROID_HOME not set, skipping local.properties creation"
    fi

    # Make gradlew executable
    if [[ -f "android/gradlew" ]]; then
        run_cmd "chmod +x android/gradlew"
    fi

    # Download Gradle dependencies
    if [[ -f "android/gradlew" ]]; then
        log_info "Downloading Gradle dependencies..."
        cd android
        run_cmd "./gradlew --version"
        run_cmd "./gradlew dependencies"
        cd ..
    fi

    log_success "Android setup complete"
}

setup_windows() {
    if [[ "$SKIP_WINDOWS" == true ]]; then
        log_info "Skipping Windows setup (--skip-windows)"
        return 0
    fi

    log_step "Setting Up Windows"

    cd "$RN_PROJECT_DIR"

    # Check if windows directory exists
    if [[ ! -d "windows" ]]; then
        log_warning "Windows directory not found"
        log_info "Initialize it with: npx react-native-windows-init --overwrite"

        if [[ "$DRY_RUN" == false ]]; then
            if command -v npx &> /dev/null; then
                read -p "Initialize Windows project now? (y/N) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    run_cmd "npx react-native-windows-init --overwrite"
                fi
            fi
        fi
        return 0
    fi

    log_success "Windows setup complete"
}

setup_environment_files() {
    log_step "Setting Up Environment Files"

    cd "$RN_PROJECT_DIR"

    local env_file=".env"
    local env_example=".env.example"

    if [[ -f "$env_file" ]]; then
        log_info "Environment file already exists: $env_file"
    elif [[ -f "$env_example" ]]; then
        log_info "Copying $env_example to $env_file"
        if [[ "$DRY_RUN" == false ]]; then
            cp "$env_example" "$env_file"
            log_success "Created $env_file from template"
            log_warning "Edit $env_file with your configuration"
        fi
    else
        log_info "Creating environment file template: $env_file"
        if [[ "$DRY_RUN" == false ]]; then
            cat > "$env_file" << 'EOF'
# React Native Environment Configuration
# DO NOT commit sensitive information to version control

# API Configuration
API_URL=https://api.example.com
API_KEY=your_api_key_here

# Build Configuration
APP_ENV=development

# Feature Flags
ENABLE_DEBUG_MENU=true
EOF
            log_success "Created environment template: $env_file"
            log_warning "Edit this file with your actual configuration"
        fi
    fi
}

run_code_quality_setup() {
    log_step "Setting Up Code Quality Tools"

    cd "$RN_PROJECT_DIR"

    # Check for ESLint
    if [[ -f ".eslintrc.js" ]] || [[ -f ".eslintrc.json" ]]; then
        log_success "ESLint configuration found"
    else
        log_warning "ESLint configuration not found"
        log_info "Consider adding ESLint for code quality"
    fi

    # Check for Prettier
    if [[ -f ".prettierrc" ]] || [[ -f ".prettierrc.js" ]]; then
        log_success "Prettier configuration found"
    else
        log_warning "Prettier configuration not found"
        log_info "Consider adding Prettier for code formatting"
    fi

    # Check for TypeScript
    if [[ -f "tsconfig.json" ]]; then
        log_success "TypeScript configuration found"
    else
        log_info "Not using TypeScript"
    fi
}

run_setup() {
    log_step "Starting React Native Setup"

    if [[ "$DRY_RUN" == true ]]; then
        log_warning "Running in DRY-RUN mode - no changes will be made"
    fi

    check_prerequisites || exit 1
    setup_react_native_project || exit 1
    install_dependencies || exit 1
    setup_android
    setup_windows
    setup_environment_files
    run_code_quality_setup

    log_step "React Native Setup Complete!"
    log_success "Your React Native project is ready for development"
    log_info ""
    log_info "Next steps:"
    log_info "  Android: ./scripts/build-android.sh"
    log_info "  Windows: ./scripts/build-windows.sh"
    log_info ""
    log_info "To start development:"
    log_info "  Metro bundler: npm start"
    log_info "  Android: npm run android"
    log_info "  Windows: npm run windows"
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
            --skip-android)
                SKIP_ANDROID=true
                shift
                ;;
            --skip-windows)
                SKIP_WINDOWS=true
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
