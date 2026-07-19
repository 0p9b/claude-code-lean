#!/usr/bin/env bash
# Interactive installer for Claude Code Lean.
# Safe to run via:
#   curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | bash
set -euo pipefail

# Prefer GitHub raw — jsDelivr @main can stay stale for a long time after pushes.
# Override if needed: CLAUDE_LEAN_RAW_BASE=https://cdn.jsdelivr.net/gh/0p9b/claude-code-lean@COMMIT
REPO_RAW="${CLAUDE_LEAN_RAW_BASE:-https://raw.githubusercontent.com/0p9b/claude-code-lean/main}"
CLAUDE_DIR="${HOME}/.claude"
BIN_DIR="${HOME}/.local/bin"
WORKDIR=""
CLEANUP_WORKDIR=0
SELECTED_MODE=""
INSTALLER_VERSION="2026-07-19-7"

TUI_IN="/dev/tty"
TUI_OUT="/dev/tty"

tui_available() {
  [[ -r "$TUI_IN" && -w "$TUI_OUT" ]] 2>/dev/null
}

# UI must go to the real terminal when piped from curl (stdout may be captured).
ui() {
  if tui_available && printf '%s\n' "$*" >"$TUI_OUT" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$*" >&2
}

ui_n() {
  if tui_available && printf '%s' "$*" >"$TUI_OUT" 2>/dev/null; then
    return 0
  fi
  printf '%s' "$*" >&2
}

tui_hide_cursor() {
  if tui_available; then
    printf '\033[?25l' >"$TUI_OUT"
  fi
}

tui_show_cursor() {
  if tui_available; then
    printf '\033[?25h' >"$TUI_OUT"
  fi
}

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

# Ask y/N before proceeding. Returns 0 for yes, 1 for no.
confirm_selection() {
  local mode="$1"
  local label="$2"
  local reply=""

  ui ""
  case "$mode" in
    quit)
      ui_n "Quit without installing? [y/N] "
      ;;
    *)
      ui "Selected: ${label}"
      ui_n "Continue with this install? [y/N] "
      ;;
  esac

  reply="$(prompt_read)"
  case "$reply" in
    y | Y | yes | Yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

# Interactive menu: ↑↓ or 1-3/q to highlight, Enter to confirm (with y/N prompt).
# Prints the chosen index (0-based) to stdout.
menu_select() {
  local -a options=("$@")
  local count=${#options[@]}
  local selected=0
  local menu_height=$((count + 2))
  local i key seq

  if ! tui_available; then
    return 1
  fi

  draw_menu() {
    for ((i = 0; i < count; i++)); do
      if ((i == selected)); then
        printf '  \033[7m› %s\033[0m\033[K\n' "${options[i]}" >"$TUI_OUT"
      else
        printf '    %s\033[K\n' "${options[i]}" >"$TUI_OUT"
      fi
    done
    printf '\n\033[K' >"$TUI_OUT"
    printf '  \033[2m↑↓ or 1-3/q to choose · Enter to confirm\033[0m\033[K\n' >"$TUI_OUT"
  }

  redraw_menu() {
    printf '\033[%dA' "$menu_height" >"$TUI_OUT"
    draw_menu
  }

  while true; do
    draw_menu
    tui_hide_cursor

    while true; do
      IFS= read -rsn1 key <"$TUI_IN" || break

      case "$key" in
        $'\e')
          IFS= read -rsn2 -t 0.1 seq <"$TUI_IN" 2>/dev/null || true
          case "$seq" in
            '[A' | '[B' | 'OA' | 'OB')
              if [[ "$seq" == '[A' || "$seq" == 'OA' ]]; then
                ((selected > 0)) && ((selected--))
              else
                ((selected < count - 1)) && ((selected++))
              fi
              redraw_menu
              ;;
          esac
          ;;
        '' | $'\n' | $'\r')
          break 2
          ;;
        [1-3])
          selected=$((key - 1))
          redraw_menu
          ;;
        q | Q)
          selected=$((count - 1))
          redraw_menu
          ;;
      esac
    done

    tui_show_cursor

    local mode="install"
    if ((selected == count - 1)); then
      mode="quit"
    fi

    if confirm_selection "$mode" "${options[selected]}"; then
      printf '%s\n' "$selected"
      return 0
    fi

    ui ""
    ui "Cancelled — pick another option:"
    ui ""
  done

  tui_show_cursor
  return 1
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

install_launcher() {
  say "Installing claude-lean launcher…"
  backup_if_exists "${CLAUDE_DIR}/system-prompt-lean.txt"
  cp "$WORKDIR/templates/system-prompt-lean.txt" "${CLAUDE_DIR}/system-prompt-lean.txt"

  cp "$WORKDIR/bin/claude-lean" "${BIN_DIR}/claude-lean"
  chmod +x "${BIN_DIR}/claude-lean"
  ensure_path_note
}

install_regular() {
  install_shared
  say
  say "Installed: Regular Lean only"
  say "  • Six tools (Bash, Read, Write, Edit, WebSearch, WebFetch)"
  say "  • Claude Code default lean system prompt"
  say "  • Effort: medium"
  say
  say "Start with:  claude"
}

install_ultra() {
  install_shared
  install_launcher

  say
  say "Installed: Ultra Lean only"
  say "  • Six tools (Bash, Read, Write, Edit, WebSearch, WebFetch)"
  say "  • Minimal custom system prompt (overrides product prompt)"
  say "  • Effort: medium"
  say
  say "Start with:  claude-lean"
}

install_both() {
  install_shared
  install_launcher

  say
  say "Installed: Both (recommended)"
  say "  • Same lean settings + six tools for either command"
  say "  • Effort: medium"
  say
  say "Use either launcher anytime:"
  say "  claude-lean  → Ultra Lean (custom minimal system prompt, ~4.5–5k)"
  say "  claude       → Regular Lean (default Claude Code system prompt, ~6.5k)"
}

choose_mode() {
  local choice="${CLAUDE_LEAN_MODE:-}"
  local -a menu_labels=(
    "1) Ultra Lean only — settings + claude-lean (~4.5–5k)"
    "2) Regular Lean only — settings only, use: claude (~6.5k)"
    "3) Both (recommended) — claude-lean OR claude per session"
    "q) Quit without installing"
  )
  local -a menu_modes=(ultra regular both quit)
  local idx

  if [[ -n "$choice" ]]; then
    SELECTED_MODE="$choice"
    return
  fi

  ui ""
  ui "========================================"
  ui "  Claude Code Lean installer"
  ui "========================================"
  ui ""
  ui "All options use the SAME lean settings and these 6 tools:"
  ui "  Bash · Read · Write · Edit · WebSearch · WebFetch"
  ui "Everything else is disabled. Effort defaults to medium."
  ui ""
  ui "Choose what to install:"
  ui ""

  if tui_available && idx="$(menu_select "${menu_labels[@]}")"; then
    :
  else
    while true; do
      ui_n "Type 1 (Ultra), 2 (Regular), 3 (Both), or q to quit: "
      choice="$(prompt_read)"
      case "$choice" in
        1 | ultra | Ultra | ULTRA)
          idx=0
          ;;
        2 | regular | Regular | REGULAR)
          idx=1
          ;;
        3 | both | Both | BOTH)
          idx=2
          ;;
        q | Q | quit | Quit)
          idx=3
          ;;
        *)
          ui "Hmm, \"$choice\" is not valid."
          ui "Please type:  1 = Ultra  |  2 = Regular  |  3 = Both  |  q = Quit"
          continue
          ;;
      esac

      local mode="install"
      if ((idx == 3)); then
        mode="quit"
      fi
      if confirm_selection "$mode" "${menu_labels[idx]}"; then
        break
      fi
      ui ""
      ui "Cancelled — pick another option:"
      ui ""
    done
  fi

  case "${menu_modes[idx]}" in
    ultra)
      SELECTED_MODE="ultra"
      ui ""
      ui "→ OK: installing Ultra Lean only (use: claude-lean)"
      ;;
    regular)
      SELECTED_MODE="regular"
      ui ""
      ui "→ OK: installing Regular Lean only (use: claude)"
      ;;
    both)
      SELECTED_MODE="both"
      ui ""
      ui "→ OK: installing Both (use: claude-lean OR claude)"
      ;;
    quit)
      ui "Cancelled."
      exit 0
      ;;
    *)
      err "Unknown menu selection: ${idx}"
      ;;
  esac
}

main() {
  if ! command -v curl >/dev/null 2>&1; then
    err "curl is required"
  fi
  if ! command -v claude >/dev/null 2>&1; then
    err "Claude Code CLI ('claude') not found on PATH. Install it first: https://code.claude.com/docs"
  fi

  ui "Installer version: ${INSTALLER_VERSION}"

  resolve_sources
  choose_mode

  case "$SELECTED_MODE" in
    ultra) install_ultra ;;
    regular) install_regular ;;
    both) install_both ;;
    *) err "Unknown mode: $SELECTED_MODE" ;;
  esac

  say
  say "Restart any open Claude Code sessions, then run /context to verify."
}

main "$@"
