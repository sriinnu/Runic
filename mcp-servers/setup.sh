#!/bin/bash

# Runic MCP Servers Setup Script
# Builds all three servers: persistence, intuition, consciousness

set -e

echo "🔮 Setting up Runic MCP Servers"
echo "================================"
echo ""

SERVERS=("persistence-server" "intuition-server" "consciousness-server")
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

for server in "${SERVERS[@]}"; do
  echo "📦 Building $server..."
  cd "$SCRIPT_DIR/$server"

  if [ ! -d "node_modules" ]; then
    echo "  → Installing dependencies..."
    npm install
  else
    echo "  → Dependencies already installed"
  fi

  echo "  → Compiling TypeScript..."
  npm run build

  echo "  ✅ $server ready"
  echo ""
done

echo "🎉 All MCP servers built successfully!"
echo ""
echo "Next steps:"
echo "1. Add servers to Claude Desktop config:"
echo "   ~/.../Claude/claude_desktop_config.json"
echo ""
echo "2. Restart Claude Desktop"
echo ""
echo "3. Test with: 'Use the runic-persistence server'"
echo ""
echo "📖 See mcp-servers/README.md for full documentation"
