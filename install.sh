#!/bin/bash
# install.sh — Symlinks Mighty Router across active agents and IDE configs
set -euo pipefail

# Determine repository directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define agent paths (respecting standard locations)
HERMES_DIR="$HOME/.hermes/skills"
OPENCLAW_DIR="$HOME/.openclaw/skills"
CODEX_DIR="$HOME/.codex/skills"
GEMINI_DIR="$HOME/.gemini/config/skills"
COPILOT_DIR="$HOME/.copilot/agents"

echo "============================================="
echo " Installing Mighty Mouse Router...          "
echo "============================================="

# 1. Install for Hermes (nested structure)
if [ -d "$HERMES_DIR" ]; then
    echo "→ Linking to Hermes..."
    mkdir -p "$HERMES_DIR/mighty"
    ln -sf "$REPO_DIR/categories/mighty/DESCRIPTION.md" "$HERMES_DIR/mighty/DESCRIPTION.md"
    ln -sfn "$REPO_DIR/categories/mighty/mighty-router" "$HERMES_DIR/mighty/mighty-router"
    echo "  [✓] Linked successfully"
else
    echo "  [-] Hermes not detected (skipping)"
fi

# 2. Install for OpenClaw (flat structure)
if [ -d "$OPENCLAW_DIR" ]; then
    echo "→ Linking to OpenClaw..."
    ln -sfn "$REPO_DIR/skills/mighty-router" "$OPENCLAW_DIR/mighty-router"
    echo "  [✓] Linked successfully"
else
    echo "  [-] OpenClaw not detected (skipping)"
fi

# 3. Install for Codex (flat structure)
if [ -d "$CODEX_DIR" ]; then
    echo "→ Linking to Codex..."
    ln -sfn "$REPO_DIR/skills/mighty-router" "$CODEX_DIR/mighty-router"
    echo "  [✓] Linked successfully"
else
    echo "  [-] Codex not detected (skipping)"
fi

# 4. Install for Antigravity (flat structure)
if [ -d "$GEMINI_DIR" ]; then
    echo "→ Linking to Antigravity..."
    ln -sfn "$REPO_DIR/skills/mighty-router" "$GEMINI_DIR/mighty-router"
    echo "  [✓] Linked successfully"
else
    echo "  [-] Antigravity not detected (skipping)"
fi

# 5. Install for VS Code Copilot
if [ -d "$COPILOT_DIR" ]; then
    echo "→ Linking VS Code Copilot custom agent..."
    ln -sf "$REPO_DIR/vscode-agents/mighty-router.agent.md" "$COPILOT_DIR/mighty-router.agent.md"
    echo "  [✓] Linked successfully"
else
    echo "  [-] VS Code Copilot Agents directory not found (skipping)"
fi

echo "============================================="
echo " Installation completed successfully!         "
echo "============================================="
echo "Note: If your IDE window was already open, please reload it"
echo "(Cmd+Shift+P -> 'Developer: Reload Window') to refresh."
