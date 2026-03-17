#!/usr/bin/env bash
# claude-code-statusline installer
# Copies statusline.sh to ~/.claude/ and configures settings.json
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/AsafSaar/claude-code-statusline/main/install.sh | bash
#   — or —
#   bash install.sh

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SCRIPT_NAME="statusline.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
INSTALL_PATH="$CLAUDE_DIR/$SCRIPT_NAME"

# Determine script source — if running from cloned repo, use local file; otherwise download
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="$SCRIPT_DIR/$SCRIPT_NAME"

REMOTE_URL="https://raw.githubusercontent.com/AsafSaar/claude-code-statusline/main/statusline.sh"

echo "claude-code-statusline installer"
echo "================================"
echo ""

# 1. Ensure ~/.claude exists
mkdir -p "$CLAUDE_DIR"

# 2. Copy or download the script
if [[ -f "$SOURCE_SCRIPT" ]]; then
  echo "Copying statusline.sh from local repo..."
  cp "$SOURCE_SCRIPT" "$INSTALL_PATH"
else
  echo "Downloading statusline.sh from GitHub..."
  if command -v curl &>/dev/null; then
    curl -fsSL "$REMOTE_URL" -o "$INSTALL_PATH"
  elif command -v wget &>/dev/null; then
    wget -qO "$INSTALL_PATH" "$REMOTE_URL"
  else
    echo "Error: curl or wget is required to download the script."
    exit 1
  fi
fi

chmod +x "$INSTALL_PATH"
echo "Installed to $INSTALL_PATH"

# 3. Check for jq (required by the status line script)
if ! command -v jq &>/dev/null; then
  echo ""
  echo "Warning: 'jq' is not installed. The status line requires jq to parse JSON."
  echo "  macOS:  brew install jq"
  echo "  Ubuntu: sudo apt-get install jq"
  echo "  Arch:   sudo pacman -S jq"
  echo ""
fi

# 4. Configure settings.json
STATUS_LINE_CONFIG='{"type":"command","command":"bash ~/.claude/statusline.sh"}'

if [[ -f "$SETTINGS_FILE" ]]; then
  # Check if statusLine is already configured
  existing=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null || true)
  if [[ -n "$existing" ]]; then
    echo ""
    echo "settings.json already has a statusLine configured:"
    echo "  $existing"
    echo ""
    read -rp "Overwrite with claude-code-statusline? [y/N] " answer
    if [[ "${answer,,}" != "y" ]]; then
      echo "Skipped settings.json update. You can manually set:"
      echo "  \"statusLine\": $STATUS_LINE_CONFIG"
      echo ""
      echo "Done! Restart Claude Code to see the status line."
      exit 0
    fi
  fi
  # Merge into existing settings
  tmp=$(mktemp)
  jq --argjson sl "$STATUS_LINE_CONFIG" '.statusLine = $sl' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  echo "Updated $SETTINGS_FILE"
else
  # Create new settings file
  echo "{\"statusLine\": $STATUS_LINE_CONFIG}" | jq '.' > "$SETTINGS_FILE"
  echo "Created $SETTINGS_FILE"
fi

echo ""
echo "Done! Restart Claude Code to see the status line."
echo ""
echo "To customize segments, edit: $INSTALL_PATH"
echo "Look for the ENABLED_SEGMENTS array at the top of the file."
