#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🐉 Runic - AI Usage Tracker"
echo "=============================="

# Paths
BUILD_DIR="$SCRIPT_DIR/.build"
APP_DIR="$BUILD_DIR/Runic.app"
EXE_NAME="Runic"

show_help() {
    cat << EOF
Usage: ./run.sh [command]

Commands:
    build           Build the app bundle
    run             Run the macOS app (builds if needed)
    cli [args]      Run the CLI (pass args through)
    install         Install to /Applications
    watch           Build and run with file watching (requires entr)
    test            Run tests
    clean           Clean build artifacts
    help            Show this help message

Examples:
    ./run.sh build
    ./run.sh run
    ./run.sh cli usage claude
    ./run.sh install
EOF
}

# Create app bundle structure
create_app_bundle() {
    echo "📦 Creating app bundle structure..."

    # Remove old bundle if exists
    rm -rf "$APP_DIR"

    # Create bundle directories
    mkdir -p "$APP_DIR/Contents/MacOS"
    mkdir -p "$APP_DIR/Contents/Resources"

    # Copy the executable
    EXE_PATH=$(swift build --show-bin-path 2>/dev/null)/$EXE_NAME
    if [ ! -f "$EXE_PATH" ]; then
        echo "🔨 Building first..."
        swift build
        EXE_PATH=$(swift build --show-bin-path 2>/dev/null)/$EXE_NAME
    fi

    cp "$EXE_PATH" "$APP_DIR/Contents/MacOS/$EXE_NAME"
    chmod +x "$APP_DIR/Contents/MacOS/$EXE_NAME"

    # Find and copy Sparkle framework
    SPARKLE_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Sparkle.framework" -type d 2>/dev/null | grep -v xcframework | head -1)
    if [ -z "$SPARKLE_PATH" ]; then
        SPARKLE_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Sparkle.framework" -type d 2>/dev/null | head -1)
    fi

    if [ -d "$SPARKLE_PATH" ]; then
        echo "   Copying Sparkle framework..."
        cp -r "$SPARKLE_PATH" "$APP_DIR/Contents/MacOS/"
    fi

    # Copy SVG icons
    echo "   Copying provider icons..."
    cp "$SCRIPT_DIR/Sources/Runic/Resources"/*.svg "$APP_DIR/Contents/Resources/" 2>/dev/null || true

    # Create Info.plist with app icon reference
    cat > "$APP_DIR/Contents/Info.plist" << 'INFOPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Runic</string>
    <key>CFBundleIdentifier</key>
    <string>com.sriinnu.athena.runic</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Runic</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
INFOPLIST

    # Copy icon if exists
    if [ -f "$SCRIPT_DIR/Sources/Runic/Resources/AppIcon.icns" ]; then
        cp "$SCRIPT_DIR/Sources/Runic/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/"
    fi

    echo "✅ App bundle created at: $APP_DIR"
}

build() {
    echo "🧹 Cleaning old build..."
    rm -rf "$BUILD_DIR"

    echo "🔨 Building Runic..."
    swift build
    create_app_bundle
    echo "✅ Build complete!"
}

run_app() {
    # Always rebuild to get latest changes
    echo "📦 Building app bundle..."
    rm -rf "$BUILD_DIR"
    swift build
    create_app_bundle

    echo "🚀 Launching Runic..."
    open "$APP_DIR"

    echo "✅ Runic should now be in your menu bar"
    echo "   (Look for the rune icon)"
}

run_cli() {
    swift run RunicCLI "$@"
}

install_app() {
    if [ ! -f "$APP_DIR/Contents/MacOS/$EXE_NAME" ]; then
        echo "📦 Building app bundle first..."
        create_app_bundle
    fi

    echo "📍 Installing to /Applications..."
    if [ -d "/Applications/Runic.app" ]; then
        rm -rf "/Applications/Runic.app"
    fi
    cp -r "$APP_DIR" "/Applications/"
    echo "✅ Installed to /Applications/Runic.app"
}

run_tests() {
    echo "🧪 Running tests..."
    swift test
}

clean() {
    echo "🧹 Cleaning..."
    swift clean
    rm -rf "$APP_DIR"
    rm -rf "$BUILD_DIR"
    echo "✅ Clean complete!"
}

watch_build() {
    if ! command -v entr &> /dev/null; then
        echo "❌ 'entr' not found. Install with: brew install entr"
        exit 1
    fi

    echo "👀 Watching for changes... (Ctrl+C to stop)"
    find Sources -name "*.swift" | entr -c ./run.sh build
}

case "${1:-help}" in
    build)
        build
        ;;
    run)
        run_app
        ;;
    cli)
        shift
        run_cli "$@"
        ;;
    install)
        install_app
        ;;
    watch)
        watch_build
        ;;
    test)
        run_tests
        ;;
    clean)
        clean
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run './run.sh help' for usage"
        exit 1
        ;;
esac
