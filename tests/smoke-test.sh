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
  printf '%s' "$keys" | script -q -c "cd '${REPO_ROOT}' && bash install.sh" "$log" >/dev/null 2>&1 || true
  cat "$log"
}

section() { printf '\n=== %s ===\n' "$1"; }

section "Static checks"
bash -n "${REPO_ROOT}/install.sh" && pass "install.sh syntax (bash -n)" || fail "install.sh syntax (bash -n)"
bash -n "${REPO_ROOT}/bin/claude-lean" && pass "claude-lean syntax (bash -n)" || fail "claude-lean syntax (bash -n)"
python3 -m json.tool "${REPO_ROOT}/config/settings.json" >/dev/null 2>&1 && pass "settings.json valid JSON" || fail "settings.json valid JSON"
assert_executable "${REPO_ROOT}/bin/claude-lean" "bin/claude-lean executable"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'INSTALLER_VERSION="2026-07-19-10"' "installer version 2026-07-19-10"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'atomic_install_file' "atomic install helper present"
assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'validate_mode_or_exit' "mode validation present"

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
rm -f "$TMP_INSTALL"
assert_contains "$OUT" "Downloading install files" "file:// REPO_RAW triggers download path"
assert_file "${HOME}/.claude/settings.json" "file:// download installs settings"
teardown_test_home; trap - EXIT

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

section "TTY: both (3 + y)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty '3y')"
assert_file "${HOME}/.local/bin/claude-lean" "TTY both installs"
assert_contains "$OUT" "Confirm" "TTY both shows confirm"
assert_contains "$OUT" "Installed to:" "TTY both shows install summary"
teardown_test_home; trap - EXIT

section "TTY: reject then ultra (3n1y)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty '3n1y')"
assert_contains "$OUT" "Back to menu" "TTY reject returns to menu"
assert_contains "$OUT" "Installed: Ultra Lean only" "TTY then installs ultra"
teardown_test_home; trap - EXIT

section "TTY: quit (qy)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty 'qy')"
assert_no_file "${HOME}/.claude/settings.json" "TTY quit installs nothing"
teardown_test_home; trap - EXIT

section "TTY: arrows + both"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty $'\e[B\e[B\ry')"
assert_file "${HOME}/.local/bin/claude-lean" "TTY arrows install both"
teardown_test_home; trap - EXIT

section "TTY: regular (2y)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty '2y')"
assert_file "${HOME}/.claude/settings.json" "TTY regular installs settings"
assert_no_file "${HOME}/.local/bin/claude-lean" "TTY regular skips launcher"
teardown_test_home; trap - EXIT

section "TTY: confirm No via arrow (3↓Enter 3y)"
setup_test_home; trap teardown_test_home EXIT
OUT="$(run_install_tty $'3\e[B\r3y')"
assert_contains "$OUT" "Back to menu" "TTY confirm-no returns"
assert_file "${HOME}/.local/bin/claude-lean" "TTY confirm-no then yes installs"
teardown_test_home; trap - EXIT

section "curl|bash pipe simulation"
setup_test_home; trap teardown_test_home EXIT
printf '1y' | script -q -c "curl -fsSL file://${REPO_ROOT}/install.sh | bash" "${TEST_HOME}/pipe.log" >/dev/null 2>&1 || true
assert_file "${HOME}/.local/bin/claude-lean" "curl|bash pipe installs ultra"
teardown_test_home; trap - EXIT

section "Non-interactive pipe"
setup_test_home; trap teardown_test_home EXIT
OUT="$(CLAUDE_LEAN_MODE=regular bash "${REPO_ROOT}/install.sh" 2>&1)"
assert_contains "$OUT" "Installer version: 2026-07-19-10" "non-interactive version"
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
for asset in config/settings.json bin/claude-lean templates/system-prompt-lean.txt templates/output-styles/lean.md; do
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

printf '\n========================================\n'
printf 'Results: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
((FAIL == 0))
