#!/bin/bash

###############################################################################
# @file setup.sh
# @description Automated setup script for Runic Cross-Platform development.
# Checks prerequisites, installs dependencies, and configures the environment.
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored message
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "ℹ $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Node.js version
check_node() {
    print_info "Checking Node.js installation..."

    if ! command_exists node; then
        print_error "Node.js is not installed"
        print_info "Please install Node.js 18+ from https://nodejs.org/"
        exit 1
    fi

    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Node.js version must be 18 or higher (found: $(node -v))"
        exit 1
    fi

    print_success "Node.js $(node -v) installed"
}

# Check npm version
check_npm() {
    print_info "Checking npm installation..."

    if ! command_exists npm; then
        print_error "npm is not installed"
        exit 1
    fi

    NPM_VERSION=$(npm -v | cut -d'.' -f1)
    if [ "$NPM_VERSION" -lt 9 ]; then
        print_error "npm version must be 9 or higher (found: $(npm -v))"
        exit 1
    fi

    print_success "npm $(npm -v) installed"
}

# Check Android setup (optional)
check_android() {
    print_info "Checking Android development environment..."

    if [ -z "$ANDROID_HOME" ]; then
        print_warning "ANDROID_HOME not set (Android development not configured)"
        print_info "Set ANDROID_HOME to your Android SDK path to enable Android development"
        return 1
    fi

    if [ ! -d "$ANDROID_HOME" ]; then
        print_warning "ANDROID_HOME directory does not exist: $ANDROID_HOME"
        return 1
    fi

    print_success "Android SDK found at $ANDROID_HOME"
    return 0
}

# Check Windows setup (optional, only on Windows)
check_windows() {
    if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
        print_info "Skipping Windows setup (not on Windows)"
        return 1
    fi

    print_info "Checking Windows development environment..."

    if ! command_exists msbuild.exe; then
        print_warning "MSBuild not found (Visual Studio 2022 may not be installed)"
        print_info "Install Visual Studio 2022 with Windows 10 SDK for Windows development"
        return 1
    fi

    print_success "Windows development environment configured"
    return 0
}

# Install npm dependencies
install_dependencies() {
    print_info "Installing npm dependencies..."

    if npm install; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
}

# Setup Android (if configured)
setup_android() {
    if check_android; then
        print_info "Setting up Android..."

        # Create local.properties if it doesn't exist
        if [ ! -f "android/local.properties" ]; then
            echo "sdk.dir=$ANDROID_HOME" > android/local.properties
            print_success "Created android/local.properties"
        fi

        # Make gradlew executable
        if [ -f "android/gradlew" ]; then
            chmod +x android/gradlew
            print_success "Made gradlew executable"
        fi
    fi
}

# Setup Windows (if on Windows)
setup_windows() {
    if check_windows; then
        print_info "Setting up Windows..."

        # Initialize React Native for Windows
        if [ ! -d "windows" ]; then
            print_info "Initializing React Native for Windows..."
            npx react-native-windows-init --overwrite
            print_success "Windows project initialized"
        else
            print_success "Windows project already exists"
        fi
    fi
}

# Create .env file if it doesn't exist
setup_env() {
    print_info "Checking environment configuration..."

    if [ ! -f ".env" ]; then
        print_info "Creating .env file..."
        cat > .env << EOF
# Environment Configuration
NODE_ENV=development

# API Configuration
API_BASE_URL=https://api.example.com

# Feature Flags
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=true

# Development
DEV_MODE=true
EOF
        print_success "Created .env file"
        print_warning "Please update .env with your configuration"
    else
        print_success ".env file already exists"
    fi
}

# Run setup checks
run_checks() {
    print_info "Running setup checks..."

    # TypeScript check
    if npm run type-check; then
        print_success "TypeScript checks passed"
    else
        print_warning "TypeScript checks failed (you may need to fix type errors)"
    fi
}

# Print success summary
print_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    print_success "Setup completed successfully!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Update .env file with your configuration"
    echo "  2. Add provider API tokens in app settings"
    echo ""
    echo "To start development:"
    echo ""
    if check_android >/dev/null 2>&1; then
        echo "  Android: npm run android"
    fi
    if check_windows >/dev/null 2>&1; then
        echo "  Windows: npm run windows"
    fi
    echo ""
    echo "For more information, see:"
    echo "  - QUICKSTART.md for getting started"
    echo "  - ARCHITECTURE.md for project structure"
    echo "  - CONTRIBUTING.md for development guidelines"
    echo ""
}

# Main setup function
main() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Runic Cross-Platform Setup"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Check prerequisites
    check_node
    check_npm

    # Install dependencies
    install_dependencies

    # Platform-specific setup
    setup_android
    setup_windows

    # Environment setup
    setup_env

    # Run checks
    run_checks

    # Print summary
    print_summary
}

# Run main function
main
