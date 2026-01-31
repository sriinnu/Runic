#!/bin/bash

# Build Verification Script for Runic Cross-Platform
# This script verifies that all build fixes are working correctly

set -e  # Exit on error

echo "======================================"
echo "Runic Cross-Platform Build Verification"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error message
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print info message
info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if we're in the correct directory
if [ ! -f "package.json" ]; then
    error "package.json not found. Please run this script from the project root."
    exit 1
fi

echo "Step 1: Checking project structure..."
if [ -f "package.json" ] && [ -f "tsconfig.json" ] && [ -f "babel.config.js" ]; then
    success "Project structure is valid"
else
    error "Missing required configuration files"
    exit 1
fi

echo ""
echo "Step 2: Cleaning previous installation..."
if [ -d "node_modules" ] || [ -f "package-lock.json" ]; then
    info "Removing node_modules and package-lock.json..."
    rm -rf node_modules package-lock.json
    success "Cleaned previous installation"
else
    info "No previous installation found"
fi

echo ""
echo "Step 3: Installing dependencies..."
info "This may take a few minutes..."
if npm install --loglevel=error; then
    success "Dependencies installed successfully"
else
    error "Failed to install dependencies"
    exit 1
fi

echo ""
echo "Step 4: Checking for non-existent packages..."
if grep -q "react-native-system-tray" package.json; then
    error "Found react-native-system-tray in package.json (should be removed)"
    exit 1
else
    success "No non-existent packages found"
fi

echo ""
echo "Step 5: Verifying babel-plugin-module-resolver..."
if npm list babel-plugin-module-resolver --depth=0 > /dev/null 2>&1; then
    success "babel-plugin-module-resolver is installed"
else
    error "babel-plugin-module-resolver is missing"
    exit 1
fi

echo ""
echo "Step 6: Running TypeScript type check..."
if npx tsc --noEmit; then
    success "TypeScript compilation successful (no errors)"
else
    error "TypeScript compilation failed"
    info "Review the errors above and fix them"
    exit 1
fi

echo ""
echo "Step 7: Verifying critical files..."
critical_files=(
    "src/types/index.ts"
    "src/types/provider.types.ts"
    "src/types/app.types.ts"
    "src/services/NotificationService.ts"
    "src/services/ApiClient.ts"
    "src/services/SyncService.ts"
    "src/stores/useProviderStore.ts"
    "src/stores/useAppStore.ts"
    "src/theme/colors.ts"
    "src/theme/theme.ts"
    "src/hooks/useTheme.ts"
    "src/utils/formatters.ts"
    "src/utils/storage.ts"
    "src/screens/HomeScreen.tsx"
    "src/components/ProviderCard.tsx"
    "App.tsx"
    "index.js"
)

missing_files=0
for file in "${critical_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}  ✓${NC} $file"
    else
        echo -e "${RED}  ✗${NC} $file ${RED}(MISSING)${NC}"
        missing_files=$((missing_files + 1))
    fi
done

if [ $missing_files -eq 0 ]; then
    success "All critical files present"
else
    error "Missing $missing_files critical file(s)"
    exit 1
fi

echo ""
echo "Step 8: Checking for common import issues..."
if npx tsc --noEmit 2>&1 | grep -q "Cannot find module"; then
    error "Found unresolved module imports"
    info "Run 'npx tsc --noEmit' to see details"
    exit 1
else
    success "All imports resolve correctly"
fi

echo ""
echo "======================================"
echo -e "${GREEN}✓ Build verification completed successfully!${NC}"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Run 'npm start' to start Metro bundler"
echo "2. Run 'npm run android' to launch on Android (if Android SDK is set up)"
echo "3. Run 'npm run windows' to launch on Windows (if Windows SDK is set up)"
echo ""
echo "For more information, see BUILD_FIXES.md"
echo ""
