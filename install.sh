#!/usr/bin/env bash
# Install lean Claude Code CLI config into ~/.claude and ~/.local/bin
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
BIN_DIR="${HOME}/.local/bin"

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)"
    cp -a "$path" "${path}.bak.${stamp}"
    echo "Backed up $path -> ${path}.bak.${stamp}"
  fi
}

mkdir -p "$CLAUDE_DIR/output-styles" "$BIN_DIR"

echo "Installing settings -> ${CLAUDE_DIR}/settings.json"
backup_if_exists "${CLAUDE_DIR}/settings.json"
cp "$ROOT/config/settings.json" "${CLAUDE_DIR}/settings.json"

echo "Installing lean system prompt -> ${CLAUDE_DIR}/system-prompt-lean.txt"
backup_if_exists "${CLAUDE_DIR}/system-prompt-lean.txt"
cp "$ROOT/templates/system-prompt-lean.txt" "${CLAUDE_DIR}/system-prompt-lean.txt"

echo "Installing output style -> ${CLAUDE_DIR}/output-styles/lean.md"
backup_if_exists "${CLAUDE_DIR}/output-styles/lean.md"
cp "$ROOT/templates/output-styles/lean.md" "${CLAUDE_DIR}/output-styles/lean.md"

echo "Installing launcher -> ${BIN_DIR}/claude-lean"
cp "$ROOT/bin/claude-lean" "${BIN_DIR}/claude-lean"
chmod +x "${BIN_DIR}/claude-lean"

if ! echo ":$PATH:" | grep -q ":${BIN_DIR}:"; then
  echo
  echo "Note: ${BIN_DIR} is not on your PATH."
  echo "Add this to your shell rc (e.g. ~/.bashrc):"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo
echo "Done."
echo "  claude       -> lean settings + default Claude Code system prompt"
echo "  claude-lean  -> same settings + replaced (minimal) system prompt"
echo
echo "Restart any open Claude Code sessions, then run /context to verify."
