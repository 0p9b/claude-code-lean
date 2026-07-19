#!/usr/bin/env bash
# Interactive installer for Claude Code Lean.
# Safe to run via:
#   curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | bash
set -euo pipefail

# Prefer GitHub raw — jsDelivr @main can stay stale for a long time after pushes.
# Override if needed: CLAUDE_LEAN_RAW_BASE=https://cdn.jsdelivr.net/gh/0p9b/claude-code-lean@COMMIT
REPO_RAW="${CLAUDE_LEAN_RAW_BASE:-https://raw.githubusercontent.com/0p9b/claude-code-lean/main}"
CLAUDE_DIR="${CLAUDE_LEAN_CLAUDE_DIR:-${HOME}/.claude}"
BIN_DIR="${CLAUDE_LEAN_BIN_DIR:-${HOME}/.local/bin}"
WORKDIR=""
CLEANUP_WORKDIR=0
SELECTED_MODE=""
INSTALLER_VERSION="2026-07-19-12"
VALID_MODES=(ultra regular both custom)

TUI_IN="/dev/tty"
TUI_OUT="/dev/tty"
MENU_SELECTED_IDX=""
PROMPT_REPLY=""

tui_available() {
  [[ -r "$TUI_IN" && -w "$TUI_OUT" ]] 2>/dev/null
}

# UI must go to the real terminal when piped from curl (stdout may be captured).
ui() {
  if tui_available; then
    { printf '%s\n' "$*" >"$TUI_OUT"; } 2>/dev/null && return 0
  fi
  printf '%s\n' "$*" >&2
}

ui_n() {
  if tui_available; then
    { printf '%s' "$*" >"$TUI_OUT"; } 2>/dev/null && return 0
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
# Result is stored in PROMPT_REPLY (never stdout — avoids subshell capture bugs).
prompt_read() {
  PROMPT_REPLY=""
  if [[ -r /dev/tty ]]; then
    read -r PROMPT_REPLY </dev/tty
  else
    read -r PROMPT_REPLY
  fi
}

# Draw a highlighted option list. Sets $1=menu_height for redraw.
menu_draw_options() {
  local selected="$1"
  shift
  local -a options=("$@")
  local count=${#options[@]}
  local i

  MENU_DRAW_HEIGHT=$((count + 2))
  for ((i = 0; i < count; i++)); do
    if ((i == selected)); then
      printf '  \033[7m› %s\033[0m\033[K\n' "${options[i]}" >"$TUI_OUT"
    else
      printf '    %s\033[K\n' "${options[i]}" >"$TUI_OUT"
    fi
  done
  printf '\n\033[K' >"$TUI_OUT"
}

menu_redraw_options() {
  local selected="$1"
  shift
  printf '\033[%dA' "$MENU_DRAW_HEIGHT" >"$TUI_OUT"
  menu_draw_options "$selected" "$@"
}

# Yes/No confirmation menu. Returns 0 for yes, 1 for no.
menu_confirm_yesno() {
  local heading="$1"
  local detail="${2:-}"
  local -a options=("Yes, continue" "No, go back")
  local selected=0
  local key seq

  if ! tui_available; then
    return 1
  fi

  ui ""
  ui "----------------------------------------"
  ui "  Confirm"
  ui "----------------------------------------"
  ui ""
  ui "$heading"
  if [[ -n "$detail" ]]; then
    ui "  ${detail}"
  fi
  ui ""

  while true; do
    menu_draw_options "$selected" "${options[@]}"
    printf '  \033[2m↑↓ or y/n · Enter to select\033[0m\033[K\n' >"$TUI_OUT"
    tui_hide_cursor

    IFS= read -rsn1 key <"$TUI_IN" || break

    case "$key" in
      $'\e')
        IFS= read -rsn2 -t 0.1 seq <"$TUI_IN" 2>/dev/null || true
        case "$seq" in
          '[A' | 'OA')
            ((selected > 0)) && ((selected--))
            menu_redraw_options "$selected" "${options[@]}"
            printf '  \033[2m↑↓ or y/n · Enter to select\033[0m\033[K\n' >"$TUI_OUT"
            ;;
          '[B' | 'OB')
            ((selected < 1)) && ((selected++))
            menu_redraw_options "$selected" "${options[@]}"
            printf '  \033[2m↑↓ or y/n · Enter to select\033[0m\033[K\n' >"$TUI_OUT"
            ;;
        esac
        ;;
      '' | $'\n' | $'\r')
        tui_show_cursor
        return "$selected"
        ;;
      y | Y)
        tui_show_cursor
        return 0
        ;;
      n | N)
        tui_show_cursor
        return 1
        ;;
    esac
  done

  tui_show_cursor
  return 1
}

# Text fallback when no TUI confirm menu is available.
confirm_selection_text() {
  local mode="$1"
  local label="$2"

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

  prompt_read
  case "$PROMPT_REPLY" in
    y | Y | yes | Yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

ask_to_confirm() {
  local mode="$1"
  local label="$2"
  local heading detail

  if [[ "$mode" == "quit" ]]; then
    heading="Quit without installing?"
    detail=""
  else
    heading="Install this option?"
    detail="$label"
  fi

  if tui_available; then
    menu_confirm_yesno "$heading" "$detail"
  else
    confirm_selection_text "$mode" "$label"
  fi
}

# Interactive menu: ↑↓ to move, 1-3/q to pick, Enter to open confirm menu.
# Sets MENU_SELECTED_IDX and returns 0 on success.
menu_select() {
  local -a options=("$@")
  local count=${#options[@]}
  local selected=0
  local key seq

  if ! tui_available; then
    return 1
  fi

  while true; do
    menu_draw_options "$selected" "${options[@]}"
    printf '  \033[2m↑↓ move · number pick · Enter to confirm\033[0m\033[K\n' >"$TUI_OUT"
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
              menu_redraw_options "$selected" "${options[@]}"
              printf '  \033[2m↑↓ move · number pick · Enter to confirm\033[0m\033[K\n' >"$TUI_OUT"
              ;;
          esac
          ;;
        '' | $'\n' | $'\r')
          break
          ;;
        [1-9])
          local pick=$((key - 1))
          if ((pick >= 0 && pick < count)); then
            selected=$pick
            break
          fi
          ;;
        q | Q)
          selected=$((count - 1))
          break
          ;;
      esac
    done

    tui_show_cursor

    local mode="install"
    if ((selected == count - 1)); then
      mode="quit"
    fi

    if ask_to_confirm "$mode" "${options[selected]}"; then
      MENU_SELECTED_IDX="$selected"
      return 0
    fi

    ui ""
    ui "Back to menu — pick another option:"
    ui ""
  done

  tui_show_cursor
  return 1
}

cleanup() {
  if [[ "$CLEANUP_WORKDIR" -eq 1 && -n "$WORKDIR" && -d "$WORKDIR" ]]; then
    rm -rf "$WORKDIR"
  fi
  if declare -F cleanup_custom_gen >/dev/null 2>&1; then
    cleanup_custom_gen
  fi
}
trap cleanup EXIT

say() { printf '%s\n' "$*"; }
err() { printf 'Error: %s\n' "$*" >&2; exit 1; }

normalize_mode() {
  printf '%s' "${1,,}"
}

is_valid_mode() {
  local mode="$1" m
  for m in "${VALID_MODES[@]}"; do
    if [[ "$mode" == "$m" ]]; then
      return 0
    fi
  done
  return 1
}

validate_mode_or_exit() {
  local mode
  mode="$(normalize_mode "$1")"
  if is_valid_mode "$mode"; then
    printf '%s' "$mode"
    return 0
  fi
  err "Unknown install mode: '$1' (expected: ultra, regular, both, or custom)"
}

atomic_install_file() {
  local src="$1" dest="$2"
  local tmp="${dest}.tmp.$$"
  cp "$src" "$tmp"
  chmod --reference="$src" "$tmp" 2>/dev/null || chmod 0644 "$tmp"
  mv -f "$tmp" "$dest"
}

verify_nonempty_file() {
  local path="$1" label="$2"
  if [[ ! -s "$path" ]]; then
    err "Download failed or empty: ${label}"
  fi
}

resolve_sources() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || true)"

  if [[ -n "$script_dir" && -f "$script_dir/config/settings.json" ]]; then
    WORKDIR="$script_dir"
    CLEANUP_WORKDIR=0
    say "Using local repo files from: $WORKDIR"
    # shellcheck disable=SC1091
    source "${WORKDIR}/lib/custom-wizard.sh"
    return
  fi

  WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-code-lean.XXXXXX")"
  CLEANUP_WORKDIR=1
  say "Downloading install files…"

  mkdir -p "$WORKDIR/config" "$WORKDIR/bin" "$WORKDIR/lib" "$WORKDIR/templates/output-styles"

  curl -fsSL "$REPO_RAW/config/settings.json" -o "$WORKDIR/config/settings.json"
  curl -fsSL "$REPO_RAW/config/generate-settings.py" -o "$WORKDIR/config/generate-settings.py"
  curl -fsSL "$REPO_RAW/lib/custom-wizard.sh" -o "$WORKDIR/lib/custom-wizard.sh"
  curl -fsSL "$REPO_RAW/bin/claude-lean" -o "$WORKDIR/bin/claude-lean"
  curl -fsSL "$REPO_RAW/templates/system-prompt-lean.txt" -o "$WORKDIR/templates/system-prompt-lean.txt"
  curl -fsSL "$REPO_RAW/templates/output-styles/lean.md" -o "$WORKDIR/templates/output-styles/lean.md"

  chmod +x "$WORKDIR/bin/claude-lean" "$WORKDIR/config/generate-settings.py"
  # shellcheck disable=SC1091
  source "${WORKDIR}/lib/custom-wizard.sh"

  verify_nonempty_file "$WORKDIR/config/settings.json" "config/settings.json"
  verify_nonempty_file "$WORKDIR/config/generate-settings.py" "config/generate-settings.py"
  verify_nonempty_file "$WORKDIR/lib/custom-wizard.sh" "lib/custom-wizard.sh"
  verify_nonempty_file "$WORKDIR/bin/claude-lean" "bin/claude-lean"
  verify_nonempty_file "$WORKDIR/templates/system-prompt-lean.txt" "templates/system-prompt-lean.txt"
  verify_nonempty_file "$WORKDIR/templates/output-styles/lean.md" "templates/output-styles/lean.md"
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
  local settings_src="${1:-$WORKDIR/config/settings.json}"
  mkdir -p "$CLAUDE_DIR/output-styles" "$BIN_DIR"

  say "Installing shared lean settings…"
  backup_if_exists "${CLAUDE_DIR}/settings.json"
  atomic_install_file "$settings_src" "${CLAUDE_DIR}/settings.json"

  backup_if_exists "${CLAUDE_DIR}/output-styles/lean.md"
  atomic_install_file "$WORKDIR/templates/output-styles/lean.md" "${CLAUDE_DIR}/output-styles/lean.md"
}

install_launcher() {
  local conf_src="${1:-}"

  say "Installing claude-lean launcher…"
  backup_if_exists "${CLAUDE_DIR}/system-prompt-lean.txt"
  atomic_install_file "$WORKDIR/templates/system-prompt-lean.txt" "${CLAUDE_DIR}/system-prompt-lean.txt"

  atomic_install_file "$WORKDIR/bin/claude-lean" "${BIN_DIR}/claude-lean"
  chmod +x "${BIN_DIR}/claude-lean"

  if [[ -n "$conf_src" && -f "$conf_src" ]]; then
    backup_if_exists "${CLAUDE_DIR}/claude-lean.conf"
    atomic_install_file "$conf_src" "${CLAUDE_DIR}/claude-lean.conf"
  fi

  ensure_path_note
}

print_install_summary() {
  say
  say "Installed to:"
  say "  settings:      ${CLAUDE_DIR}/settings.json"
  say "  output style:  ${CLAUDE_DIR}/output-styles/lean.md"
  if [[ -f "${BIN_DIR}/claude-lean" ]]; then
    say "  launcher:      ${BIN_DIR}/claude-lean"
    say "  system prompt: ${CLAUDE_DIR}/system-prompt-lean.txt"
    if [[ -f "${CLAUDE_DIR}/claude-lean.conf" ]]; then
      say "  launcher conf: ${CLAUDE_DIR}/claude-lean.conf"
    fi
  fi
}

install_custom() {
  if [[ -z "$CUSTOM_GENERATED_SETTINGS" ]]; then
    run_custom_wizard || exit 0
  fi

  install_shared "$CUSTOM_GENERATED_SETTINGS"

  case "$CUSTOM_LAUNCHER" in
    ultra)
      install_launcher "$CUSTOM_GENERATED_LAUNCHER_CONF"
      ;;
    both)
      install_launcher "$CUSTOM_GENERATED_LAUNCHER_CONF"
      ;;
    regular)
      :
      ;;
    *)
      cleanup_custom_gen
      err "Unknown custom launcher: $CUSTOM_LAUNCHER"
      ;;
  esac

  say
  say "Installed: Custom configuration"
  say "  • Effort: ${CUSTOM_EFFORT}"
  if ((${#CUSTOM_PACKS[@]} > 0)); then
    say "  • Packs:  $(IFS=,; echo "${CUSTOM_PACKS[*]}")"
  else
    say "  • Packs:  lean only (6 core tools)"
  fi
  say
  case "$CUSTOM_LAUNCHER" in
    ultra) say "Start with:  claude-lean" ;;
    regular) say "Start with:  claude" ;;
    both) say "Start with:  claude-lean (ultra) or claude (regular)" ;;
  esac
  say "  Full breakdown: https://0p9b.github.io/claude-code-lean/config.html"
  print_install_summary
  cleanup_custom_gen
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
  print_install_summary
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
  print_install_summary
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
  print_install_summary
}

choose_mode() {
  local choice="${CLAUDE_LEAN_MODE:-}"
  local -a menu_labels=(
    "1) Ultra Lean — most stripped down (~4.5–5k, claude-lean)"
    "2) Regular Lean — 6 tools + default prompt (~6.5k, claude)"
    "3) Both — install both launchers (recommended)"
    "4) Custom — wizard: pick tools, effort, launcher"
    "q) Quit without installing"
  )
  local -a menu_modes=(ultra regular both custom quit)
  local idx

  if [[ -n "$choice" ]]; then
    SELECTED_MODE="$(validate_mode_or_exit "$choice")"
    if [[ "$SELECTED_MODE" == "custom" ]]; then
      err "Custom mode requires the interactive menu. Re-run without CLAUDE_LEAN_MODE and pick option 4."
    fi
    return
  fi

  ui ""
  ui "========================================"
  ui "  Claude Code Lean installer"
  ui "========================================"
  ui ""
  ui "Profiles: Ultra = minimal prompt · Regular = default prompt · Custom = you choose"
  ui "All lean profiles start with 6 tools; everything else disabled by default."
  ui "Details: https://0p9b.github.io/claude-code-lean/config.html"
  ui ""
  ui "Choose what to install:"
  ui ""

  if tui_available && menu_select "${menu_labels[@]}"; then
    idx="$MENU_SELECTED_IDX"
  else
    while true; do
      ui_n "Type 1 (Ultra), 2 (Regular), 3 (Both), 4 (Custom), or q to quit: "
      prompt_read
      choice="$PROMPT_REPLY"
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
        4 | custom | Custom | CUSTOM)
          idx=3
          ;;
        q | Q | quit | Quit)
          idx=4
          ;;
        *)
          ui "Hmm, \"$choice\" is not valid."
          ui "Please type:  1=Ultra  2=Regular  3=Both  4=Custom  q=Quit"
          continue
          ;;
      esac

      local mode="install"
      if ((idx == 4)); then
        mode="quit"
      fi
      if ask_to_confirm "$mode" "${menu_labels[idx]}"; then
        break
      fi
      ui ""
      ui "Back to menu — pick another option:"
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
    custom)
      SELECTED_MODE="custom"
      ui ""
      ui "→ OK: starting custom configuration wizard"
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
    custom) install_custom ;;
    *) err "Internal error: unhandled mode '$SELECTED_MODE'" ;;
  esac

  say
  say "Restart any open Claude Code sessions, then run /context to verify."
}

main "$@"
