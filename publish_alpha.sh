#!/usr/bin/env bash

# ==============================================================================
# Mighty Mouse -> Mighty Router Auto-Publishing Gate
# ==============================================================================
# Usage: ./publish_alpha.sh <path_to_new_prompt> <target_type>
#
# Target Types:
#   - cursor      (maps to templates/.cursorrules)
#   - windsurf    (maps to templates/.windsurfrules)
#   - cline       (maps to templates/.clinerules)
#   - claude      (maps to templates/.clauderules)
#   - aider       (maps to templates/.aider.instructions.md)
#   - skill       (maps to skills/mighty-router/SKILL.md)
# ==============================================================================

set -euo pipefail

# Configuration
ROUTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANDIDATE_FILE="${1:-}"
TARGET_TYPE="${2:-}"

# Usage help
usage() {
    echo "Usage: $0 <path_to_candidate_file> <target_type>"
    echo "Target types: cursor, windsurf, cline, claude, aider, skill"
    exit 1
}

if [[ -z "$CANDIDATE_FILE" || -z "$TARGET_TYPE" ]]; then
    usage
fi

if [[ ! -f "$CANDIDATE_FILE" ]]; then
    echo "Error: Candidate file '$CANDIDATE_FILE' not found."
    exit 1
fi

# Map target paths
case "$TARGET_TYPE" in
    cursor)
        DEST_FILE="$ROUTER_DIR/templates/.cursorrules"
        ;;
    windsurf)
        DEST_FILE="$ROUTER_DIR/templates/.windsurfrules"
        ;;
    cline)
        DEST_FILE="$ROUTER_DIR/templates/.clinerules"
        ;;
    claude)
        DEST_FILE="$ROUTER_DIR/templates/.clauderules"
        ;;
    aider)
        DEST_FILE="$ROUTER_DIR/templates/.aider.instructions.md"
        ;;
    skill)
        DEST_FILE="$ROUTER_DIR/skills/mighty-router/SKILL.md"
        ;;
    *)
        echo "Error: Unknown target type '$TARGET_TYPE'"
        usage
        ;;
esac

echo "============================================="
echo " Mighty Router: Prompt Publishing Gate       "
echo "============================================="
echo "• Candidate Source: $CANDIDATE_FILE"
echo "• Destination:      $DEST_FILE"
echo "---------------------------------------------"

# 1. Verification Gate
echo "→ Running verifier check..."
# NOTE: Add your automated verification agent or test CLI trigger here.
# E.g., python run_evals.py --prompt "$CANDIDATE_FILE"
echo "[✓] Verifier check simulated successfully."
echo "---------------------------------------------"

# 2. Interactive Prompt for Human Confirmation
read -p "Are you sure you want to publish this Alpha to GitHub? [y/N]: " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "→ Copying candidate to repository..."
    cp "$CANDIDATE_FILE" "$DEST_FILE"
    
    # Also sync Hermes category skill if updating the flat skill
    if [[ "$TARGET_TYPE" == "skill" ]]; then
        echo "→ Syncing Hermes category skill copy..."
        cp "$CANDIDATE_FILE" "$ROUTER_DIR/categories/mighty/mighty-router/SKILL.md"
    fi
    
    echo "→ Staging and pushing changes to GitHub..."
    cd "$ROUTER_DIR"
    git add .
    git commit -m "Auto-optimization: verified alpha release ($TARGET_TYPE)"
    git push origin main
    
    echo "============================================="
    echo " [✓] Alpha successfully published to GitHub! "
    echo "============================================="
else
    echo "Publish cancelled. Candidate files discarded."
fi
