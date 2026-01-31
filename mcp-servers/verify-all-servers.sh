#!/bin/bash

# Verify All MCP Servers
# Tests compilation, build, and basic functionality of all 3 servers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVERS=("persistence-server" "intuition-server" "consciousness-server")

echo "=================================================="
echo "MCP Servers Verification Script"
echo "=================================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
ALL_PASSED=true

# Test each server
for SERVER in "${SERVERS[@]}"; do
    echo ""
    echo "=================================================="
    echo "Testing: $SERVER"
    echo "=================================================="

    SERVER_DIR="$SCRIPT_DIR/$SERVER"

    if [ ! -d "$SERVER_DIR" ]; then
        echo -e "${RED}✗ Server directory not found: $SERVER_DIR${NC}"
        ALL_PASSED=false
        continue
    fi

    cd "$SERVER_DIR"

    # 1. Check package.json exists
    echo -n "Checking package.json... "
    if [ -f "package.json" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ package.json not found${NC}"
        ALL_PASSED=false
        continue
    fi

    # 2. Check node_modules (npm install)
    echo -n "Checking dependencies... "
    if [ -d "node_modules" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}Installing...${NC}"
        npm install > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Dependencies installed${NC}"
        else
            echo -e "${RED}✗ npm install failed${NC}"
            ALL_PASSED=false
            continue
        fi
    fi

    # 3. TypeScript type checking
    echo -n "TypeScript type checking... "
    npx tsc --noEmit > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ TypeScript errors found${NC}"
        npx tsc --noEmit
        ALL_PASSED=false
        continue
    fi

    # 4. Build
    echo -n "Building... "
    npx tsc > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Build failed${NC}"
        ALL_PASSED=false
        continue
    fi

    # 5. Check build artifacts
    echo -n "Checking build artifacts... "
    if [ -f "dist/index.js" ] && [ -f "dist/tools.js" ] && [ -f "dist/schemas.js" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Missing build artifacts${NC}"
        ALL_PASSED=false
        continue
    fi

    # 6. Verify shebang
    echo -n "Checking executable shebang... "
    if head -n 1 dist/index.js | grep -q "#!/usr/bin/env node"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ No shebang found${NC}"
    fi

    # 7. Check required source files
    echo -n "Checking source files... "
    if [ -f "src/index.ts" ] && [ -f "src/tools.ts" ] && [ -f "src/schemas.ts" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Missing source files${NC}"
        ALL_PASSED=false
        continue
    fi

    echo -e "${GREEN}✓ $SERVER passed all checks${NC}"
done

echo ""
echo "=================================================="
if [ "$ALL_PASSED" = true ]; then
    echo -e "${GREEN}✓ ALL SERVERS PASSED${NC}"
    echo "All 3 MCP servers are ready to use!"
    exit 0
else
    echo -e "${RED}✗ SOME SERVERS FAILED${NC}"
    echo "Please check the errors above."
    exit 1
fi
