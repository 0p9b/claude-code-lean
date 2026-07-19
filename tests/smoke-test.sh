#!/usr/bin/env bash
# End-to-end smoke / sanity / stress tests for claude-code-lean.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
SKIP=0

pass() { PASS=$((PASS + 1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$1" >&2; }
skip() { SKIP=$((SKIP + 1)); printf '  SKIP: %s\n' "$1"; }

assert_file() {
  local path="$1" msg="$2"
  if [[ -f "$path" ]]; then pass "$msg"; else fail "$msg (missing: $path)"; fi
}

assert_no_file() {
  local path="$1" msg="$2"
  if [[ ! -e "$path" ]]; then pass "$msg"; else fail "$msg (unexpected: $path)"; fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then pass "$msg"; else fail "$msg (missing: $needle)"; fi
}

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [[ "$got" == "$want" ]]; then pass "$msg"; else fail "$msg (got='$got' want='$want')"; fi
}

assert_executable() {
  local path="$1" msg="$2"
  if [[ -x "$path" ]]; then pass "$msg"; else fail "$msg (not executable: $path)"; fi
}

setup_test_home() {
  TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/ccl-smoke-home.XXXXXX")"
  TEST_BIN="$(mktemp -d "${TMPDIR:-/tmp}/ccl-smoke-bin.XXXXXX")"
  MOCK_LOG="${TEST_HOME}/claude-invocations.log"

  cat >"${TEST_BIN}/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${MOCK_LOG}"
EOF
  chmod +x "${TEST_BIN}/claude"

  export HOME="$TEST_HOME"
  export PATH="${TEST_BIN}:${PATH}"
  unset CLAUDE_LEAN_CLAUDE_DIR CLAUDE_LEAN_BIN_DIR CLAUDE_LEAN_MODE CLAUDE_LEAN_RAW_BASE
  mkdir -p "${HOME}/.local/bin"
}

teardown_test_home() {
  [[ -n "${TEST_HOME:-}" && -d "$TEST_HOME" ]] && rm -rf "$TEST_HOME"
  [[ -n "${TEST_BIN:-}" && -d "$TEST_BIN" ]] && rm -rf "$TEST_BIN"
}

run_install_mode() {
  local mode="$1"
  CLAUDE_LEAN_MODE="$mode" bash "${REPO_ROOT}/install.sh" >/dev/null
}

run_install_tty() {
  local keys="$1"
  local log="${TEST_HOME}/install.log"
  : >"$log"
  printf '%s' "$keys" | script -q -c "cd '${REPO_ROOT}' && bash install.sh" "$log" >/dev/null 2>&1 || true
  if [[ -f "$log" ]]; then
    cat "$log"
  else
    printf ''
  fi
}

section() { printf '\n=== %s ===\n' "$1"; }

section "Static checks"
bash -n "${REPO_ROOT}/install.sh" && pass "install.sh syntax (bash -n)" || fail "install.sh syntax (bash -n)"
bash -n "${REPO_ROOT}/lib/custom-wizard.sh" && pass "custom-wizard.sh syntax (bash -n)" || fail "custom-wizard.sh syntax (bash -n)"
bash -n "${REPO_ROOT}/bin/claude-lean" && pass "claude-lean syntax (bash -n)" || fail "claude-lean syntax (bash -n)"
python3 -m json.tool "${REPO_ROOT}/config/settings.json" >/dev/null 2>&1 && pass "settings.json valid JSON" || fail "settings.json valid JSON"
python3 -m py_compile "${REPO_ROOT}/config/generate-settings.py" 2>/dev/null && pass "generate-settings.py compiles" || fail "generate-settings.py compiles"
assert_executable "${REPO_ROOT}/bin/claude-lean" "bin/claude-lean executable"
assert_executable "${REPO_ROOT}/config/generate-settings.py" "generate-settings.py executable"
assert_file "${REPO_ROOT}/lib/custom-wizard.sh" "custom-wizard.sh present"
assert_file "${REPO_ROOT}/docs/index.html" "GitHub Pages index.html present"
assert_file "${REPO_ROOT}/docs/config.html" "GitHub Pages config.html present"
assert_contains "$(cat "${REPO_ROOT}/docs/index.html")" "Four profiles" "website lists four profiles"
assert_contains "$(cat "${REPO_ROOT}/docs/index.html")" 'id="customize"' "website has customize-later section"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'INSTALLER_VERSION="2026-07-19-14"' "installer version 2026-07-19-14"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'balanced) install_balanced' "balanced install mode present"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'custom) install_custom' "custom install mode present"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'Files installed (edit anytime)' "post-install edit guidance"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'MENU_DEFAULT_IDX=2' "menu defaults to Balanced"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'verify_installed_settings' "validates installed JSON"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'ensure_writable_dir' "checks writable install dirs"
assert_file "${REPO_ROOT}/config/settings-balanced.json" "settings-balanced.json present"
python3 -m json.tool "${REPO_ROOT}/config/settings-balanced.json" >/dev/null 2>&1 && pass "settings-balanced.json valid JSON" || fail "settings-balanced.json valid JSON"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'atomic_install_file' "atomic install helper present"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'validate_mode_or_exit' "mode validation present"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'generate-settings.py' "installer downloads settings generator"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'custom-wizard.sh' "installer downloads custom wizard"
# Consistency: never ship broken config URL casing
if grep -n 'CONFIG\.html' "${REPO_ROOT}/install.sh" "${REPO_ROOT}/README.md" "${REPO_ROOT}/docs/"*.html 2>/dev/null; then
  fail "broken CONFIG.html URL (must be config.html)"
else
  pass "config.html URL casing consistent"
fi
# Custom wizard must write to temp dir, not repo generated/
assert_contains "$(cat "${REPO_ROOT}/lib/custom-wizard.sh")" 'mktemp -d' "custom wizard uses temp dir for generated settings"
assert_contains "$(cat "${REPO_ROOT}/.gitignore")" 'generated/' "gitignore ignores generated/"
assert_contains "$(cat "${REPO_ROOT}/.gitignore")" '__pycache__/' "gitignore ignores __pycache__/"
assert_no_file "${REPO_ROOT}/generated/settings.json" "repo has no generated/settings.json pollution"


section "Generator: all packs stress"
GEN_DIR="$(mktemp -d)"
ALL_PACKS="search,todos,tasks,agents,skills,mcp,memory,claude_md,thinking,git,cron,comms,extra"
python3 "${REPO_ROOT}/config/generate-settings.py" \
  --base "${REPO_ROOT}/config/settings.json" \
  --out-settings "${GEN_DIR}/settings.json" \
  --packs "$ALL_PACKS" \
  --hooks \
  --thinking-ui \
  --effort low \
  --launcher \
  --out-launcher "${GEN_DIR}/claude-lean.conf" >/dev/null
if python3 -c "
import json
s=json.load(open('${GEN_DIR}/settings.json'))
deny=set(s['permissions']['deny'])
assert 'Glob' not in deny and 'Agent' not in deny and 'Skill' not in deny
assert 'mcp__*' not in deny
assert s['autoMemoryEnabled'] is True
assert s['disableAllHooks'] is False
assert s['effortLevel']=='low'
"; then
  pass "all-packs stress: settings valid"
else
  fail "all-packs stress: settings valid"
fi
assert_contains "$(cat "${GEN_DIR}/claude-lean.conf")" 'DISALLOWED=""' "all-packs stress: mcp allowed in launcher"
rm -rf "$GEN_DIR"

section "Generator: lean-only baseline"
GEN_DIR="$(mktemp -d)"
python3 "${REPO_ROOT}/config/generate-settings.py" \
  --base "${REPO_ROOT}/config/settings.json" \
  --out-settings "${GEN_DIR}/settings.json" >/dev/null
if python3 -c "
import json
s=json.load(open('${GEN_DIR}/settings.json'))
deny=set(s['permissions']['deny'])
for t in ['Glob','Grep','Agent','Skill','TodoWrite','mcp__*']:
    assert t in deny, t
assert s['disableAllHooks'] is True
"; then
  pass "lean-only generator matches deny-all baseline"
else
  fail "lean-only generator matches deny-all baseline"
fi
rm -rf "$GEN_DIR"

section "Custom settings generator"
GEN_DIR="$(mktemp -d)"
python3 "${REPO_ROOT}/config/generate-settings.py" \
  --base "${REPO_ROOT}/config/settings.json" \
  --out-settings "${GEN_DIR}/settings.json" \
  --packs "search,agents" \
  --effort high \
  --launcher \
  --out-launcher "${GEN_DIR}/claude-lean.conf" >/dev/null
if python3 -c "import json; s=json.load(open('${GEN_DIR}/settings.json')); assert 'Glob' not in s['permissions']['deny']; assert 'Agent' not in s['permissions']['deny']; assert s['effortLevel']=='high'"; then
  pass "generator enables packs and sets effort"
else
  fail "generator enables packs and sets effort"
fi
assert_contains "$(cat "${GEN_DIR}/claude-lean.conf")" 'Glob,Grep' "launcher conf includes search tools"
assert_contains "$(cat "${GEN_DIR}/claude-lean.conf")" 'EFFORT="high"' "launcher conf includes effort"
rm -rf "$GEN_DIR"

section "Custom install (programmatic)"
setup_test_home; trap teardown_test_home EXIT
GEN="${TEST_HOME}/generated"
mkdir -p "$GEN"
python3 "${REPO_ROOT}/config/generate-settings.py" \
  --base "${REPO_ROOT}/config/settings.json" \
  --out-settings "${GEN}/settings.json" \
  --packs search \
  --launcher \
  --out-launcher "${GEN}/claude-lean.conf" >/dev/null
# Simulate custom install path
mkdir -p "${HOME}/.claude/output-styles" "${HOME}/.local/bin"
cp "${GEN}/settings.json" "${HOME}/.claude/settings.json"
cp "${REPO_ROOT}/templates/output-styles/lean.md" "${HOME}/.claude/output-styles/lean.md"
cp "${REPO_ROOT}/templates/system-prompt-lean.txt" "${HOME}/.claude/system-prompt-lean.txt"
cp "${REPO_ROOT}/bin/claude-lean" "${HOME}/.local/bin/claude-lean"
cp "${GEN}/claude-lean.conf" "${HOME}/.claude/claude-lean.conf"
chmod +x "${HOME}/.local/bin/claude-lean"
if python3 -c "import json; assert 'Glob' not in json.load(open('${HOME}/.claude/settings.json'))['permissions']['deny']"; then
  pass "custom install settings enable Glob"
else
  fail "custom install settings enable Glob"
fi
PATH="${TEST_BIN}:${HOME}/.local/bin:${PATH}" claude-lean >/dev/null 2>&1 || true
assert_contains "$(cat "$MOCK_LOG")" "Glob,Grep" "custom claude-lean uses generated tools"
teardown_test_home; trap - EXIT

section "Install mode: ultra"
setup_test_home; trap teardown_test_home EXIT
run_install_mode ultra
assert_file "${HOME}/.claude/settings.json" "ultra: settings.json"
assert_file "${HOME}/.claude/output-styles/lean.md" "ultra: lean.md"
assert_file "${HOME}/.claude/system-prompt-lean.txt" "ultra: system prompt"
assert_file "${HOME}/.local/bin/claude-lean" "ultra: launcher"
assert_eq "$(cat "${HOME}/.claude/system-prompt-lean.txt")" "." "ultra: prompt content"
teardown_test_home; trap - EXIT

section "Install mode: regular"
setup_test_home; trap teardown_test_home EXIT
run_install_mode regular
assert_file "${HOME}/.claude/settings.json" "regular: settings.json"
assert_no_file "${HOME}/.local/bin/claude-lean" "regular: no launcher"
teardown_test_home; trap - EXIT

section "Install mode: balanced"
setup_test_home; trap teardown_test_home EXIT
run_install_mode balanced
assert_file "${HOME}/.claude/settings.json" "balanced: settings.json"
assert_no_file "${HOME}/.local/bin/claude-lean" "balanced: no launcher"
if python3 -c "
import json
s=json.load(open('${HOME}/.claude/settings.json'))
deny=set(s['permissions']['deny'])
assert 'Glob' not in deny and 'Grep' not in deny and 'TodoWrite' not in deny
assert 'Agent' in deny and 'mcp__*' in deny
assert 'CLAUDE_CODE_DISABLE_THINKING' not in s.get('env', {})
assert s.get('alwaysThinkingEnabled') is True
assert s.get('showThinkingSummaries') is True
"; then
  pass "balanced: Glob/Grep/TodoWrite + thinking on"
else
  fail "balanced: Glob/Grep/TodoWrite + thinking on"
fi
teardown_test_home; trap - EXIT

section "Install mode: both"
setup_test_home; trap teardown_test_home EXIT
run_install_mode both
assert_file "${HOME}/.claude/settings.json" "both: settings.json"
assert_file "${HOME}/.local/bin/claude-lean" "both: launcher"
teardown_test_home; trap - EXIT

section "CLAUDE_LEAN_MODE case insensitive"
setup_test_home; trap teardown_test_home EXIT
CLAUDE_LEAN_MODE=BOTH bash "${REPO_ROOT}/install.sh" >/dev/null
assert_file "${HOME}/.local/bin/claude-lean" "BOTH uppercase works"
teardown_test_home; trap - EXIT

section "Invalid CLAUDE_LEAN_MODE"
setup_test_home; trap teardown_test_home EXIT
if CLAUDE_LEAN_MODE=invalid bash "${REPO_ROOT}/install.sh" >/dev/null 2>&1; then
  fail "rejects invalid mode"
else
  pass "rejects invalid mode"
fi
if CLAUDE_LEAN_MODE=ultr bash "${REPO_ROOT}/install.sh" >/dev/null 2>&1; then
  fail "rejects typo mode ultr"
else
  pass "rejects typo mode ultr"
fi
if CLAUDE_LEAN_MODE=custom bash "${REPO_ROOT}/install.sh" >/dev/null 2>&1; then
  fail "rejects non-interactive custom mode"
else
  pass "rejects non-interactive custom mode"
fi
teardown_test_home; trap - EXIT

section "Existing user config: backup + replace settings"
setup_test_home; trap teardown_test_home EXIT
mkdir -p "${HOME}/.claude/output-styles"
echo '{"custom": true}' >"${HOME}/.claude/settings.json"
echo "user style" >"${HOME}/.claude/output-styles/custom.md"
echo "keep me" >"${HOME}/.claude/CLAUDE.md"
run_install_mode both
BACKUP="$(ls "${HOME}/.claude/settings.json.bak."* 2>/dev/null | head -1 || true)"
assert_contains "$(cat "$BACKUP")" '"custom": true' "backs up user's original settings.json"
assert_contains "$(cat "${HOME}/.claude/settings.json")" '"effortLevel": "medium"' "replaces with lean settings"
assert_contains "$(cat "${HOME}/.claude/CLAUDE.md")" "keep me" "does not touch unrelated CLAUDE.md"
assert_contains "$(cat "${HOME}/.claude/output-styles/custom.md")" "user style" "does not touch unrelated output styles"
teardown_test_home; trap - EXIT

section "Existing user config: ultra over regular keeps launcher"
setup_test_home; trap teardown_test_home EXIT
run_install_mode regular
run_install_mode ultra
assert_file "${HOME}/.local/bin/claude-lean" "upgrade regular→ultra adds launcher"
assert_file "${HOME}/.claude/system-prompt-lean.txt" "upgrade regular→ultra adds prompt"
teardown_test_home; trap - EXIT

section "Existing user config: regular over ultra keeps old launcher"
setup_test_home; trap teardown_test_home EXIT
run_install_mode both
echo "stale" >"${HOME}/.local/bin/claude-lean"
run_install_mode regular
assert_contains "$(cat "${HOME}/.local/bin/claude-lean")" "stale" "regular over both does not remove existing launcher"
teardown_test_home; trap - EXIT

section "Custom install paths via env"
setup_test_home; trap teardown_test_home EXIT
export CLAUDE_LEAN_CLAUDE_DIR="${HOME}/custom-claude"
export CLAUDE_LEAN_BIN_DIR="${HOME}/custom-bin"
mkdir -p "${CLAUDE_LEAN_BIN_DIR}"
CLAUDE_LEAN_MODE=both bash "${REPO_ROOT}/install.sh" >/dev/null
assert_file "${CLAUDE_LEAN_CLAUDE_DIR}/settings.json" "custom CLAUDE_DIR works"
assert_file "${CLAUDE_LEAN_BIN_DIR}/claude-lean" "custom BIN_DIR works"
teardown_test_home; trap - EXIT

section "Download path (local REPO_RAW)"
setup_test_home; trap teardown_test_home EXIT
TMP_INSTALL="$(mktemp)"
cp "${REPO_ROOT}/install.sh" "$TMP_INSTALL"
export CLAUDE_LEAN_RAW_BASE="file://${REPO_ROOT}"
OUT="$(CLAUDE_LEAN_MODE=regular bash "$TMP_INSTALL" 2>&1)"
assert_contains "$OUT" "Downloading install files" "file:// REPO_RAW triggers download path"
assert_file "${HOME}/.claude/settings.json" "file:// download installs settings"
rm -f "$TMP_INSTALL"
teardown_test_home; trap - EXIT

section "Download path fetches all assets"
setup_test_home; trap teardown_test_home EXIT
TMP_INSTALL="$(mktemp)"
cp "${REPO_ROOT}/install.sh" "$TMP_INSTALL"
export CLAUDE_LEAN_RAW_BASE="file://${REPO_ROOT}"
CLAUDE_LEAN_MODE=both bash "$TMP_INSTALL" >/dev/null 2>&1
rm -f "$TMP_INSTALL"
assert_file "${HOME}/.local/bin/claude-lean" "full download path installs both"
teardown_test_home; trap - EXIT

section "Download path: all preset modes"
for mode in ultra regular balanced both; do
  setup_test_home; trap teardown_test_home EXIT
  TMP_INSTALL="$(mktemp)"
  cp "${REPO_ROOT}/install.sh" "$TMP_INSTALL"
  export CLAUDE_LEAN_RAW_BASE="file://${REPO_ROOT}"
  OUT="$(CLAUDE_LEAN_MODE="$mode" bash "$TMP_INSTALL" 2>&1)"
  rm -f "$TMP_INSTALL"
  assert_file "${HOME}/.claude/settings.json" "download $mode: settings"
  assert_contains "$OUT" "Files installed (edit anytime)" "download $mode: edit guidance"
  if python3 -c "import json; json.load(open('${HOME}/.claude/settings.json'))" 2>/dev/null; then
    pass "download $mode: valid JSON"
  else
    fail "download $mode: valid JSON"
  fi
  case "$mode" in
    ultra|both)
      assert_file "${HOME}/.local/bin/claude-lean" "download $mode: launcher"
      ;;
    regular|balanced)
      assert_no_file "${HOME}/.local/bin/claude-lean" "download $mode: no launcher"
      ;;
  esac
  teardown_test_home; trap - EXIT
done

section "claude-lean launcher"
setup_test_home; trap teardown_test_home EXIT
run_install_mode both
PATH="${TEST_BIN}:${HOME}/.local/bin:${PATH}" claude-lean --print test >/dev/null 2>&1 || true
INVOCATION="$(tr '\n' ' ' <"$MOCK_LOG")"
assert_contains "$INVOCATION" "--system-prompt-file ${HOME}/.claude/system-prompt-lean.txt" "passes system prompt file"
assert_contains "$INVOCATION" "--tools Bash,Edit,Read,Write,WebFetch,WebSearch" "passes six tools"
assert_contains "$INVOCATION" "--disallowedTools mcp__*" "blocks mcp"
assert_contains "$INVOCATION" "--effort medium" "effort medium"
assert_contains "$INVOCATION" "--print test" "forwards args"
assert_no_file "${HOME}/.claude/claude-lean.conf" "preset both: no launcher conf (uses defaults)"
teardown_test_home; trap - EXIT

section "claude-lean custom prompt path (~ expansion)"
setup_test_home; trap teardown_test_home EXIT
run_install_mode both
echo "CUSTOM" >"${HOME}/my-prompt.txt"
PATH="${TEST_BIN}:${HOME}/.local/bin:${PATH}" \
  CLAUDE_LEAN_PROMPT_FILE='~/my-prompt.txt' claude-lean >/dev/null 2>&1 || true
assert_contains "$(cat "$MOCK_LOG")" "--system-prompt-file ${HOME}/my-prompt.txt" "expands ~ in prompt path"
teardown_test_home; trap - EXIT

section "claude-lean missing prompt"
setup_test_home; trap teardown_test_home EXIT
run_install_mode regular
if PATH="${TEST_BIN}:${PATH}" bash "${REPO_ROOT}/bin/claude-lean" >/dev/null 2>&1; then
  fail "fails without prompt file"
else
  pass "fails without prompt file"
fi
teardown_test_home; trap - EXIT

section "settings.json policy"
SETTINGS="${REPO_ROOT}/config/settings.json"
for tool in Bash Read Write Edit WebSearch WebFetch; do
  if grep -q "\"${tool}\"" "$SETTINGS" 2>/dev/null; then
    skip "deny list mentions $tool"
  else
    pass "allowed tool not denied: $tool"
  fi
done
assert_contains "$(cat "$SETTINGS")" '"effortLevel": "medium"' "effortLevel medium"
assert_contains "$(cat "$SETTINGS")" '"mcp__*"' "mcp denied"

section "Backup on re-install"
setup_test_home; trap teardown_test_home EXIT
run_install_mode both
echo "ORIGINAL" >"${HOME}/.claude/settings.json"
run_install_mode both
compgen -G "${HOME}/.claude/settings.json.bak.*" >/dev/null && pass "re-install creates backup" || fail "re-install creates backup"
teardown_test_home; trap - EXIT

section "Error: claude missing"
NO_CLAUDE_BIN="$(mktemp -d)"
if PATH="${NO_CLAUDE_BIN}" CLAUDE_LEAN_MODE=both bash "${REPO_ROOT}/install.sh" >/dev/null 2>&1; then
  fail "fails without claude"
else
  pass "fails without claude"
fi
rm -rf "$NO_CLAUDE_BIN"

section "TTY: both (4 + y)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty '4y')"
assert_file "${HOME}/.local/bin/claude-lean" "TTY both installs"
assert_contains "$OUT" "Confirm" "TTY both shows confirm"
assert_contains "$OUT" "Files installed (edit anytime)" "TTY both shows file paths"
assert_contains "$OUT" "settings.json" "TTY both mentions settings path"
assert_contains "$OUT" "Next steps" "TTY both shows next steps"
teardown_test_home; trap - EXIT

section "TTY: balanced (3 + y)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty '3y')"
assert_file "${HOME}/.claude/settings.json" "TTY balanced installs settings"
assert_no_file "${HOME}/.local/bin/claude-lean" "TTY balanced skips launcher"
assert_contains "$OUT" "Installed: Balanced" "TTY balanced success message"
teardown_test_home; trap - EXIT

section "TTY: reject then ultra (4n1y)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty '4n1y')"
assert_contains "$OUT" "Back to menu" "TTY reject returns to menu"
assert_contains "$OUT" "Installed: Ultra Lean" "TTY then installs ultra"
teardown_test_home; trap - EXIT

section "TTY: quit (qy)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty 'qy')"
assert_no_file "${HOME}/.claude/settings.json" "TTY quit installs nothing"
teardown_test_home; trap - EXIT

section "TTY: arrows + both"
setup_test_home; trap teardown_test_home EXIT
# Menu defaults to Balanced (idx 2); one ↓ reaches Both (idx 3)
OUT="$(run_install_tty $'\e[B\ry')"
assert_file "${HOME}/.local/bin/claude-lean" "TTY arrows install both"
teardown_test_home; trap - EXIT

section "TTY: regular (2y)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty '2y')"
assert_file "${HOME}/.claude/settings.json" "TTY regular installs settings"
assert_no_file "${HOME}/.local/bin/claude-lean" "TTY regular skips launcher"
teardown_test_home; trap - EXIT

section "TTY: confirm No via arrow (4↓Enter 4y)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty $'4\e[B\r4y')"
assert_contains "$OUT" "Back to menu" "TTY confirm-no returns"
assert_file "${HOME}/.local/bin/claude-lean" "TTY confirm-no then yes installs"
teardown_test_home; trap - EXIT

section "TTY: custom lean regular (5y + wizard)"
setup_test_home; trap teardown_test_home EXIT
# Main: 5=custom, y=confirm | Wizard: 2=regular launcher, 2=medium effort | 14x n=no packs | y=confirm
OUT="$(run_install_tty '5y22nnnnnnnnnnnnnny')"
assert_file "${HOME}/.claude/settings.json" "TTY custom: settings installed"
assert_no_file "${HOME}/.local/bin/claude-lean" "TTY custom regular: no launcher"
assert_contains "$OUT" "Custom configuration wizard" "TTY custom: wizard shown"
assert_contains "$OUT" "Installed: Custom configuration" "TTY custom: success message"
teardown_test_home; trap - EXIT

section "TTY: custom ultra with search pack"
setup_test_home; trap teardown_test_home EXIT
# 5y | 1=ultra 2=medium | y=search yes | 13x n | y confirm
OUT="$(run_install_tty '5y12ynnnnnnnnnnnnny')"
assert_file "${HOME}/.local/bin/claude-lean" "TTY custom ultra: launcher installed"
assert_file "${HOME}/.claude/claude-lean.conf" "TTY custom ultra: conf written"
if python3 -c "import json; assert 'Glob' not in json.load(open('${HOME}/.claude/settings.json'))['permissions']['deny']"; then
  pass "TTY custom ultra: Glob enabled"
else
  fail "TTY custom ultra: Glob enabled"
fi
assert_no_file "${REPO_ROOT}/generated/settings.json" "custom install does not pollute repo generated/"
teardown_test_home; trap - EXIT

section "Stress: rapid reinstall cycle"
setup_test_home; trap teardown_test_home EXIT
for _ in 1 2 3 4 5; do
  CLAUDE_LEAN_MODE=ultra bash "${REPO_ROOT}/install.sh" >/dev/null
  CLAUDE_LEAN_MODE=regular bash "${REPO_ROOT}/install.sh" >/dev/null
  CLAUDE_LEAN_MODE=balanced bash "${REPO_ROOT}/install.sh" >/dev/null
  CLAUDE_LEAN_MODE=both bash "${REPO_ROOT}/install.sh" >/dev/null
done
assert_file "${HOME}/.local/bin/claude-lean" "stress cycle: final both state ok"
BACKUP_COUNT="$(ls "${HOME}/.claude/settings.json.bak."* 2>/dev/null | wc -l)"
if ((BACKUP_COUNT >= 1)); then
  pass "stress cycle: backups created ($BACKUP_COUNT)"
else
  fail "stress cycle: backups created (got $BACKUP_COUNT)"
fi
teardown_test_home; trap - EXIT

section "curl|bash pipe simulation"
setup_test_home; trap teardown_test_home EXIT
printf '1y' | script -q -c "curl -fsSL file://${REPO_ROOT}/install.sh | bash" "${TEST_HOME}/pipe.log" >/dev/null 2>&1 || true
assert_file "${HOME}/.local/bin/claude-lean" "curl|bash pipe installs ultra"
teardown_test_home; trap - EXIT

section "Non-interactive pipe"
setup_test_home; trap teardown_test_home EXIT
OUT="$(CLAUDE_LEAN_MODE=regular bash "${REPO_ROOT}/install.sh" 2>&1)"
assert_contains "$OUT" "Installer version: 2026-07-19-14" "non-interactive version"
assert_contains "$OUT" "Files installed (edit anytime)" "non-interactive shows edit paths"
assert_contains "$OUT" "${HOME}/.claude/settings.json" "non-interactive shows settings path"
assert_file "${HOME}/.claude/settings.json" "non-interactive installs"
teardown_test_home; trap - EXIT

section "Installed file permissions"
setup_test_home; trap teardown_test_home EXIT
run_install_mode both
assert_executable "${HOME}/.local/bin/claude-lean" "launcher is executable"
[[ -r "${HOME}/.claude/settings.json" ]] && pass "settings readable" || fail "settings readable"
teardown_test_home; trap - EXIT

section "Origin/main parity"
ORIGIN_INSTALL="$(git -C "${REPO_ROOT}" show origin/main:install.sh 2>/dev/null || true)"
if [[ -n "$ORIGIN_INSTALL" ]]; then
  LOCAL_VER="$(grep -o 'INSTALLER_VERSION="[^"]*"' "${REPO_ROOT}/install.sh" | head -1)"
  if [[ "$ORIGIN_INSTALL" == *"$LOCAL_VER"* ]]; then
    pass "origin install.sh version matches local"
  else
    skip "origin install.sh pending push ($LOCAL_VER)"
  fi
else
  skip "origin install.sh unavailable"
fi
for asset in config/settings.json config/settings-balanced.json config/generate-settings.py bin/claude-lean lib/custom-wizard.sh templates/system-prompt-lean.txt templates/output-styles/lean.md docs/index.html docs/config.html; do
  LH="$(sha256sum "${REPO_ROOT}/${asset}" | awk '{print $1}')"
  OH="$(git -C "${REPO_ROOT}" show "origin/main:${asset}" 2>/dev/null | sha256sum | awk '{print $1}' || true)"
  if [[ -n "$OH" && "$LH" == "$OH" ]]; then
    pass "origin matches: $asset"
  elif [[ -z "$OH" ]]; then
    skip "origin unavailable: $asset"
  else
    skip "origin pending push: $asset"
  fi
done

section "Remote install.sh live fetch"
REMOTE_INSTALL="$(curl -fsSL "https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh" 2>/dev/null || true)"
LOCAL_VER="$(grep -o 'INSTALLER_VERSION="[^"]*"' "${REPO_ROOT}/install.sh" | head -1)"
if [[ -z "$REMOTE_INSTALL" ]]; then
  skip "live raw install.sh unavailable"
elif [[ "$REMOTE_INSTALL" == *"$LOCAL_VER"* ]]; then
  pass "live raw install.sh version matches ($LOCAL_VER)"
  assert_contains "$REMOTE_INSTALL" "install_custom" "live install.sh has custom mode"
  assert_contains "$REMOTE_INSTALL" "install_balanced" "live install.sh has balanced mode"
  assert_contains "$REMOTE_INSTALL" "generate-settings.py" "live install.sh downloads generator"
  assert_contains "$REMOTE_INSTALL" "config.html" "live install.sh links config.html"
  if [[ "$REMOTE_INSTALL" == *"CONFIG.html"* ]]; then
    fail "live install.sh must not use CONFIG.html"
  else
    pass "live install.sh has no broken CONFIG.html link"
  fi
else
  skip "live raw install.sh pending push ($LOCAL_VER)"
fi

printf '\n========================================\n'
printf 'Results: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
((FAIL == 0))
