#!/usr/bin/env bash
# Custom install wizard — sourced by install.sh
set -euo pipefail

# Populated by run_custom_wizard
CUSTOM_LAUNCHER=""       # ultra | regular | both
CUSTOM_EFFORT="medium"
CUSTOM_PACKS=()
CUSTOM_GENERATED_SETTINGS=""
CUSTOM_GENERATED_LAUNCHER_CONF=""
CUSTOM_GEN_DIR=""

cleanup_custom_gen() {
  if [[ -n "${CUSTOM_GEN_DIR:-}" && -d "$CUSTOM_GEN_DIR" ]]; then
    rm -rf "$CUSTOM_GEN_DIR"
  fi
  CUSTOM_GEN_DIR=""
}

wizard_yesno() {
  local heading="$1"
  local detail="${2:-}"
  if tui_available; then
    menu_confirm_yesno "$heading" "$detail"
  else
    ui_n "$heading [y/N] "
    prompt_read
    case "$PROMPT_REPLY" in
      y | Y | yes | Yes | YES) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

wizard_pick() {
  local heading="$1"
  shift
  local -a options=("$@")
  local count=${#options[@]}
  local selected=0 key seq

  ui ""
  ui "$heading"
  ui ""

  if ! tui_available; then
    local i=1 o
    for o in "${options[@]}"; do
      ui "  $i) $o"
      i=$((i + 1))
    done
    ui_n "Choice [1-$count]: "
    prompt_read
    if [[ "$PROMPT_REPLY" =~ ^[0-9]+$ ]] && ((PROMPT_REPLY >= 1 && PROMPT_REPLY <= count)); then
      WIZARD_PICK=$((PROMPT_REPLY - 1))
      return 0
    fi
    return 1
  fi

  while true; do
    menu_draw_options "$selected" "${options[@]}"
    printf '  \033[2m↑↓ move · 1-%d pick · Enter to confirm\033[0m\033[K\n' "$count" >"$TUI_OUT"
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
              printf '  \033[2m↑↓ move · 1-%d pick · Enter to confirm\033[0m\033[K\n' "$count" >"$TUI_OUT"
              ;;
          esac
          ;;
        '' | $'\n' | $'\r')
          tui_show_cursor
          WIZARD_PICK=$selected
          return 0
          ;;
        [1-9])
          local pick=$((key - 1))
          if ((pick >= 0 && pick < count)); then
            tui_show_cursor
            WIZARD_PICK=$pick
            return 0
          fi
          ;;
      esac
    done
    tui_show_cursor
    return 1
  done
}

wizard_add_pack_if_yes() {
  local pack="$1"
  local heading="$2"
  local detail="${3:-}"
  if wizard_yesno "$heading" "$detail"; then
    CUSTOM_PACKS+=("$pack")
  fi
}

run_custom_wizard() {
  CUSTOM_PACKS=()
  CUSTOM_EFFORT="medium"
  CUSTOM_LAUNCHER=""

  ui ""
  ui "========================================"
  ui "  Custom configuration wizard"
  ui "========================================"
  ui ""
  ui "Starts from lean defaults (6 core tools). Add only what you need."
  ui ""

  if ! command -v python3 >/dev/null 2>&1; then
    err "python3 is required for custom installs"
  fi

  wizard_pick "How do you want to launch Claude Code?" \
    "Ultra — minimal custom prompt (claude-lean, ~4.5–5k)" \
    "Regular — default Claude prompt (claude, ~6.5k)" \
    "Both — install both launchers"
  case "$WIZARD_PICK" in
    0) CUSTOM_LAUNCHER="ultra" ;;
    1) CUSTOM_LAUNCHER="regular" ;;
    2) CUSTOM_LAUNCHER="both" ;;
    *) err "Invalid launcher choice" ;;
  esac

  wizard_pick "Effort level?" "Low" "Medium (recommended)" "High"
  case "$WIZARD_PICK" in
    0) CUSTOM_EFFORT="low" ;;
    1) CUSTOM_EFFORT="medium" ;;
    2) CUSTOM_EFFORT="high" ;;
    *) CUSTOM_EFFORT="medium" ;;
  esac

  ui ""
  ui "Optional feature packs (lean = all No):"
  ui ""

  wizard_add_pack_if_yes "search" "Enable code search tools?" "Glob + Grep — find files and symbols"
  wizard_add_pack_if_yes "todos" "Enable TodoWrite?" "Simple checklist only (no Task* suite)"
  wizard_add_pack_if_yes "tasks" "Enable full task suite?" "TodoWrite + TaskCreate/Get/List/…"
  wizard_add_pack_if_yes "agents" "Enable agents & plan mode?" "Agent, EnterPlanMode, worktrees"
  wizard_add_pack_if_yes "skills" "Enable skills?" "Skill tool + bundled skills"
  wizard_add_pack_if_yes "mcp" "Enable MCP connectors?" "mcp__* and MCP resource tools"
  wizard_add_pack_if_yes "memory" "Enable memory?" "Auto memory + org memory"
  wizard_add_pack_if_yes "claude_md" "Inject CLAUDE.md?" "Project markdown context"
  wizard_add_pack_if_yes "thinking" "Enable extended thinking?" "Thinking summaries in UI"
  wizard_add_pack_if_yes "git" "Include git instructions?" "Commit/PR guidance"
  wizard_add_pack_if_yes "hooks" "Enable hooks?" "User-defined hook scripts"
  wizard_add_pack_if_yes "cron" "Enable cron & background tasks?" "Scheduled / background work"
  wizard_add_pack_if_yes "comms" "Enable messaging tools?" "AskUserQuestion, SendMessage, etc."
  wizard_add_pack_if_yes "extra" "Enable power-user extras?" "LSP, NotebookEdit, workflows, cron UI, …"

  local packs_csv=""
  if ((${#CUSTOM_PACKS[@]} > 0)); then
    packs_csv=$(IFS=,; echo "${CUSTOM_PACKS[*]}")
  fi

  # Always write into a temp dir — never pollute a local clone of the repo.
  cleanup_custom_gen
  CUSTOM_GEN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-code-lean-gen.XXXXXX")"

  local gen_args=(
    python3 "${WORKDIR}/config/generate-settings.py"
    --base "${WORKDIR}/config/settings.json"
    --out-settings "${CUSTOM_GEN_DIR}/settings.json"
    --effort "$CUSTOM_EFFORT"
    --packs "$packs_csv"
  )

  local use_hooks=0 use_thinking=0
  for p in "${CUSTOM_PACKS[@]}"; do
    [[ "$p" == "hooks" ]] && use_hooks=1
    [[ "$p" == "thinking" ]] && use_thinking=1
  done
  ((use_hooks)) && gen_args+=(--hooks)
  ((use_thinking)) && gen_args+=(--thinking-ui)

  if [[ "$CUSTOM_LAUNCHER" == "ultra" || "$CUSTOM_LAUNCHER" == "both" ]]; then
    gen_args+=(--launcher --out-launcher "${CUSTOM_GEN_DIR}/claude-lean.conf")
  fi

  "${gen_args[@]}"

  CUSTOM_GENERATED_SETTINGS="${CUSTOM_GEN_DIR}/settings.json"
  CUSTOM_GENERATED_LAUNCHER_CONF="${CUSTOM_GEN_DIR}/claude-lean.conf"

  ui ""
  ui "Configuration preview:"
  ui "  Launcher:  $CUSTOM_LAUNCHER"
  ui "  Effort:    $CUSTOM_EFFORT"
  if ((${#CUSTOM_PACKS[@]} > 0)); then
    ui "  Packs:     ${packs_csv}"
  else
    ui "  Packs:     (lean only — 6 core tools)"
  fi
  ui ""

  if ! ask_to_confirm "install" "Custom lean configuration"; then
    ui "Custom configuration cancelled."
    cleanup_custom_gen
    CUSTOM_GENERATED_SETTINGS=""
    CUSTOM_GENERATED_LAUNCHER_CONF=""
    return 1
  fi
  return 0
}
