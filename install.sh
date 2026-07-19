#!/usr/bin/env bash
# Interactive installer for Claude Code Lean.
# Safe to run via:
#   curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | bash
set -euo pipefail

REPO_RAW="${CLAUDE_LEAN_RAW_BASE:-https://raw.githubusercontent.com/0p9b/claude-code-lean/main}"
CLAUDE_DIR="${HOME}/.claude"
BIN_DIR="${HOME}/.local/bin"
WORKDIR=""
CLEANUP_WORKDIR=0

# Read user input from the real terminal (curl | bash steals stdin).
prompt_read() {
  local _reply=""
  if [[ -r /dev/tty ]]; then
    read -r _reply </dev/tty
  else
    read -r _reply
  fi
  printf '%s\n' "$_reply"
}

cleanup() {
  if [[ "$CLEANUP_WORKDIR" -eq 1 && -n "$WORKDIR" && -d "$WORKDIR" ]]; then
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

say() { printf '%s\n' "$*"; }
err() { printf 'Error: %s\n' "$*" >&2; exit 1; }

resolve_sources() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"

  if [[ -n "$script_dir" && -f "$script_dir/config/settings.json" ]]; then
    WORKDIR="$script_dir"
    CLEANUP_WORKDIR=0
    say "Using local repo files from: $WORKDIR"
    return
  fi

  WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-code-lean.XXXXXX")"
  CLEANUP_WORKDIR=1
  say "Downloading install files…"

  mkdir -p "$WORKDIR/config" "$WORKDIR/bin" "$WORKDIR/templates/output-styles"

  curl -fsSL "$REPO_RAW/config/settings.json" -o "$WORKDIR/config/settings.json"
  curl -fsSL "$REPO_RAW/bin/claude-lean" -o "$WORKDIR/bin/claude-lean"
  curl -fsSL "$REPO_RAW/templates/system-prompt-lean.txt" -o "$WORKDIR/templates/system-prompt-lean.txt"
  curl -fsSL "$REPO_RAW/templates/output-styles/lean.md" -o "$WORKDIR/templates/output-styles/lean.md"

  chmod +x "$WORKDIR/bin/claude-lean"
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)"
    cp -a "$path" "${path}.bak.${stamp}"
    say "  backed up $(basename "$path") -> $(basename "$path").bak.${stamp}"
  fi
}

ensure_path_note() {
  if ! echo ":$PATH:" | grep -q ":${BIN_DIR}:"; then
    say
    say "Note: ${BIN_DIR} is not on your PATH. Add this to your shell config:"
    say "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
}

install_shared() {
  mkdir -p "$CLAUDE_DIR/output-styles" "$BIN_DIR"

  say "Installing shared lean settings…"
  backup_if_exists "${CLAUDE_DIR}/settings.json"
  cp "$WORKDIR/config/settings.json" "${CLAUDE_DIR}/settings.json"

  backup_if_exists "${CLAUDE_DIR}/output-styles/lean.md"
  cp "$WORKDIR/templates/output-styles/lean.md" "${CLAUDE_DIR}/output-styles/lean.md"
}

install_regular() {
  install_shared
  say
  say "Installed: Regular Lean"
  say "  • Same six tools (Bash, Read, Write, Edit, WebSearch, WebFetch)"
  say "  • Claude Code default lean system prompt"
  say "  • Effort: medium"
  say
  say "Start with:  claude"
}

install_ultra() {
  install_shared

  say "Installing ultra-lean launcher…"
  backup_if_exists "${CLAUDE_DIR}/system-prompt-lean.txt"
  cp "$WORKDIR/templates/system-prompt-lean.txt" "${CLAUDE_DIR}/system-prompt-lean.txt"

  cp "$WORKDIR/bin/claude-lean" "${BIN_DIR}/claude-lean"
  chmod +x "${BIN_DIR}/claude-lean"

  ensure_path_note

  say
  say "Installed: Ultra Lean"
  say "  • Same six tools (Bash, Read, Write, Edit, WebSearch, WebFetch)"
  say "  • Minimal custom system prompt (replaces product prompt)"
  say "  • Effort: medium"
  say
  say "Start with:  claude-lean"
  say "(Plain 'claude' still uses the default system prompt + the same settings.)"
}

choose_mode() {
  local choice="${CLAUDE_LEAN_MODE:-}"

  if [[ -n "$choice" ]]; then
    printf '%s\n' "$choice"
    return
  fi

  say
  say "Claude Code Lean installer"
  say "=========================="
  say
  say "Both options use the same lean settings and these 6 tools:"
  say "  Bash · Read · Write · Edit · WebSearch · WebFetch"
  say "Everything else is disabled/denied. Effort defaults to medium."
  say
  say "Choose a mode:"
  say
  say "  1) Ultra Lean   — custom minimal system prompt (~4.5–5k startup)"
  say "                   command: claude-lean"
  say
  say "  2) Regular Lean — Claude Code default system prompt (~6.5k startup)"
  say "                   command: claude"
  say
  say "  q) Quit"
  say

  while true; do
    printf 'Enter 1, 2, or q: ' >/dev/tty 2>/dev/null || printf 'Enter 1, 2, or q: '
    choice="$(prompt_read)"
    case "$choice" in
      1|ultra|Ultra|ULTRA) printf 'ultra\n'; return ;;
      2|regular|Regular|REGULAR) printf 'regular\n'; return ;;
      q|Q|quit|Quit) say "Cancelled."; exit 0 ;;
      *) say "Please enter 1, 2, or q." ;;
    esac
  done
}

main() {
  if ! command -v curl >/dev/null 2>&1; then
    err "curl is required"
  fi
  if ! command -v claude >/dev/null 2>&1; then
    err "Claude Code CLI ('claude') not found on PATH. Install it first: https://code.claude.com/docs"
  fi

  resolve_sources
  local mode
  mode="$(choose_mode)"

  case "$mode" in
    ultra) install_ultra ;;
    regular) install_regular ;;
    *) err "Unknown mode: $mode" ;;
  esac

  say
  say "Restart any open Claude Code sessions, then run /context to verify."
}

main "$@"
