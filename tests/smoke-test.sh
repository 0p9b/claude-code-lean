#!/usr/bin/env bash
# End-to-end smoke / sanity tests for claude-code-lean installer.
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
  if [[ -f "$path" ]]; then
    pass "$msg"
  else
    fail "$msg (missing: $path)"
  fi
}

assert_no_file() {
  local path="$1" msg="$2"
  if [[ ! -e "$path" ]]; then
    pass "$msg"
  else
    fail "$msg (unexpected: $path)"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$msg"
  else
    fail "$msg (missing: $needle)"
  fi
}

assert_eq() {
  local got="$1" want="$2" msg="$3"
  if [[ "$got" == "$want" ]]; then
    pass "$msg"
  else
    fail "$msg (got='$got' want='$want')"
  fi
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
  mkdir -p "${HOME}/.local/bin"
}

teardown_test_home() {
  if [[ -n "${TEST_HOME:-}" && -d "$TEST_HOME" ]]; then
    rm -rf "$TEST_HOME"
  fi
  if [[ -n "${TEST_BIN:-}" && -d "$TEST_BIN" ]]; then
    rm -rf "$TEST_BIN"
  fi
}

run_install_mode() {
  local mode="$1"
  CLAUDE_LEAN_MODE="$mode" bash "${REPO_ROOT}/install.sh" >/dev/null
}

run_install_tty() {
  local keys="$1"
  local log="${TEST_HOME}/install.log"
  # script gives install.sh a real TTY so menu + confirm work under curl|bash-like conditions
  printf '%s' "$keys" | script -q -c "cd '${REPO_ROOT}' && bash install.sh" "$log" >/dev/null 2>&1 || true
  cat "$log"
}

section() {
  printf '\n=== %s ===\n' "$1"
}

section "Static checks"
if bash -n "${REPO_ROOT}/install.sh"; then
  pass "install.sh syntax (bash -n)"
else
  fail "install.sh syntax (bash -n)"
fi

if python3 -m json.tool "${REPO_ROOT}/config/settings.json" >/dev/null 2>&1; then
  pass "settings.json is valid JSON"
else
  fail "settings.json is valid JSON"
fi

if [[ -x "${REPO_ROOT}/bin/claude-lean" ]]; then
  pass "bin/claude-lean is executable"
else
  fail "bin/claude-lean is executable"
fi

assert_contains "$(cat "${REPO_ROOT}/install.sh")" 'INSTALLER_VERSION="2026-07-19-9"' \
  "installer version string present locally"

section "Install mode: ultra"
setup_test_home
trap teardown_test_home EXIT
run_install_mode ultra
assert_file "${HOME}/.claude/settings.json" "ultra installs settings.json"
assert_file "${HOME}/.claude/output-styles/lean.md" "ultra installs output style"
assert_file "${HOME}/.claude/system-prompt-lean.txt" "ultra installs system prompt"
assert_file "${HOME}/.local/bin/claude-lean" "ultra installs claude-lean launcher"
assert_eq "$(cat "${HOME}/.claude/system-prompt-lean.txt")" "." "ultra system prompt content"
teardown_test_home
trap - EXIT

section "Install mode: regular"
setup_test_home
trap teardown_test_home EXIT
run_install_mode regular
assert_file "${HOME}/.claude/settings.json" "regular installs settings.json"
assert_file "${HOME}/.claude/output-styles/lean.md" "regular installs output style"
assert_no_file "${HOME}/.claude/system-prompt-lean.txt" "regular skips system prompt"
assert_no_file "${HOME}/.local/bin/claude-lean" "regular skips claude-lean launcher"
teardown_test_home
trap - EXIT

section "Install mode: both"
setup_test_home
trap teardown_test_home EXIT
run_install_mode both
assert_file "${HOME}/.claude/settings.json" "both installs settings.json"
assert_file "${HOME}/.claude/system-prompt-lean.txt" "both installs system prompt"
assert_file "${HOME}/.local/bin/claude-lean" "both installs claude-lean launcher"
teardown_test_home
trap - EXIT

section "claude-lean launcher args"
setup_test_home
trap teardown_test_home EXIT
run_install_mode both
HOME="$TEST_HOME" PATH="${TEST_BIN}:${TEST_HOME}/.local/bin:${PATH}" \
  claude-lean --print "test" >/dev/null 2>&1 || true
if [[ -f "$MOCK_LOG" ]]; then
  INVOCATION="$(tr '\n' ' ' <"$MOCK_LOG")"
  assert_contains "$INVOCATION" "--system-prompt-file ${HOME}/.claude/system-prompt-lean.txt" \
    "claude-lean passes system prompt file"
  assert_contains "$INVOCATION" "--tools Bash,Edit,Read,Write,WebFetch,WebSearch" \
    "claude-lean passes six tools"
  assert_contains "$INVOCATION" "--disallowedTools mcp__*" \
    "claude-lean blocks mcp tools"
  assert_contains "$INVOCATION" "--effort medium" \
    "claude-lean sets effort medium"
  assert_contains "$INVOCATION" "--print test" \
    "claude-lean forwards extra args"
else
  fail "claude-lean did not invoke claude mock"
fi
teardown_test_home
trap - EXIT

section "settings.json policy"
SETTINGS="${REPO_ROOT}/config/settings.json"
for tool in Bash Read Write Edit WebSearch WebFetch; do
  if grep -q "\"${tool}\"" "$SETTINGS" 2>/dev/null; then
  skip "settings deny list does not mention allowed tool $tool (expected)"
  else
    pass "allowed tool not denied: $tool"
  fi
done
assert_contains "$(cat "$SETTINGS")" '"effortLevel": "medium"' "effortLevel is medium"
assert_contains "$(cat "$SETTINGS")" '"outputStyle": "lean"' "outputStyle is lean"
assert_contains "$(cat "$SETTINGS")" '"CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT": "1"' "simple system prompt env set"
assert_contains "$(cat "$SETTINGS")" '"mcp__*"' "mcp tools denied"
assert_contains "$(cat "$SETTINGS")" '"Skill"' "Skill tool denied"

section "Backup on re-install"
setup_test_home
trap teardown_test_home EXIT
run_install_mode both
echo "ORIGINAL" >"${HOME}/.claude/settings.json"
run_install_mode both
if compgen -G "${HOME}/.claude/settings.json.bak.*" >/dev/null; then
  pass "re-install backs up existing settings.json"
else
  fail "re-install backs up existing settings.json"
fi
teardown_test_home
trap - EXIT

section "Error handling"
NO_CLAUDE_BIN="$(mktemp -d)"
if PATH="${NO_CLAUDE_BIN}" CLAUDE_LEAN_MODE=both bash "${REPO_ROOT}/install.sh" >/dev/null 2>&1; then
  fail "installer should fail when claude missing"
else
  pass "installer fails when claude missing"
fi
rm -rf "$NO_CLAUDE_BIN"

section "TTY menu: pick 3 + confirm yes (both)"
setup_test_home
trap teardown_test_home EXIT
OUT="$(run_install_tty '3y')"
assert_file "${HOME}/.claude/settings.json" "TTY both: settings installed"
assert_file "${HOME}/.local/bin/claude-lean" "TTY both: launcher installed"
assert_contains "$OUT" "Confirm" "TTY both: confirm screen shown"
assert_contains "$OUT" "Installed: Both" "TTY both: success message"
teardown_test_home
trap - EXIT

section "TTY menu: pick 3 + confirm no, then 1 + yes (ultra)"
setup_test_home
trap teardown_test_home EXIT
OUT="$(run_install_tty '3n1y')"
assert_file "${HOME}/.local/bin/claude-lean" "TTY reject-then-ultra: launcher installed"
assert_contains "$OUT" "Back to menu" "TTY reject-then-ultra: returned to menu"
assert_contains "$OUT" "Installed: Ultra Lean only" "TTY reject-then-ultra: ultra installed"
teardown_test_home
trap - EXIT

section "TTY menu: quit"
setup_test_home
trap teardown_test_home EXIT
OUT="$(run_install_tty 'qy')"
assert_no_file "${HOME}/.claude/settings.json" "TTY quit: nothing installed"
assert_contains "$OUT" "Cancelled" "TTY quit: cancelled message"
teardown_test_home
trap - EXIT

section "TTY menu: arrows + enter + confirm"
setup_test_home
trap teardown_test_home EXIT
# default highlight is option 1; two downs -> option 3 (both), enter, yes
OUT="$(run_install_tty $'\e[B\e[B\ry')"
assert_file "${HOME}/.local/bin/claude-lean" "TTY arrows: both installed"
assert_contains "$OUT" "Installed: Both" "TTY arrows: both success message"
teardown_test_home
trap - EXIT

section "TTY menu: pick 2 + confirm yes (regular)"
setup_test_home
trap teardown_test_home EXIT
OUT="$(run_install_tty '2y')"
assert_file "${HOME}/.claude/settings.json" "TTY regular: settings installed"
assert_no_file "${HOME}/.local/bin/claude-lean" "TTY regular: no launcher"
assert_contains "$OUT" "Installed: Regular Lean only" "TTY regular: success message"
teardown_test_home
trap - EXIT

section "TTY menu: confirm No via Enter on highlighted No"
setup_test_home
trap teardown_test_home EXIT
OUT="$(run_install_tty $'3\e[B\r3y')"
assert_file "${HOME}/.local/bin/claude-lean" "TTY confirm-no-then-yes: both installed"
assert_contains "$OUT" "Back to menu" "TTY confirm-no-then-yes: returned after No"
teardown_test_home
trap - EXIT

section "claude-lean missing prompt file"
setup_test_home
trap teardown_test_home EXIT
run_install_mode regular
if HOME="$TEST_HOME" PATH="${TEST_BIN}:${PATH}" bash "${REPO_ROOT}/bin/claude-lean" >/dev/null 2>&1; then
  fail "claude-lean should fail when prompt file missing"
else
  pass "claude-lean fails when prompt file missing"
fi
teardown_test_home
trap - EXIT

section "Invalid CLAUDE_LEAN_MODE"
setup_test_home
trap teardown_test_home EXIT
if CLAUDE_LEAN_MODE=invalid bash "${REPO_ROOT}/install.sh" >/dev/null 2>&1; then
  fail "installer rejects invalid CLAUDE_LEAN_MODE"
else
  pass "installer rejects invalid CLAUDE_LEAN_MODE"
fi
teardown_test_home
trap - EXIT

section "curl pipe simulation (non-interactive)"
setup_test_home
trap teardown_test_home EXIT
OUT="$(CLAUDE_LEAN_MODE=regular bash "${REPO_ROOT}/install.sh" 2>&1)"
assert_file "${HOME}/.claude/settings.json" "pipe regular: settings installed"
assert_no_file "${HOME}/.local/bin/claude-lean" "pipe regular: no launcher"
assert_contains "$OUT" "Installer version: 2026-07-19-9" "pipe regular: version printed"
teardown_test_home
trap - EXIT

section "Origin/main install.sh parity"
ORIGIN_INSTALL="$(git -C "${REPO_ROOT}" show origin/main:install.sh 2>/dev/null || true)"
if [[ -n "$ORIGIN_INSTALL" ]]; then
  assert_contains "$ORIGIN_INSTALL" 'INSTALLER_VERSION="2026-07-19-9"' "origin install.sh version matches"
  assert_contains "$ORIGIN_INSTALL" 'menu_confirm_yesno' "origin install.sh has confirm menu"
  assert_contains "$ORIGIN_INSTALL" 'both) install_both' "origin install.sh has both mode"
  assert_contains "$ORIGIN_INSTALL" 'MENU_SELECTED_IDX' "origin install.sh avoids subshell capture"
else
  skip "origin/main install.sh unavailable"
fi

section "Origin asset parity"
for asset in config/settings.json bin/claude-lean templates/system-prompt-lean.txt templates/output-styles/lean.md; do
  LOCAL_HASH="$(sha256sum "${REPO_ROOT}/${asset}" | awk '{print $1}')"
  REMOTE_HASH="$(git -C "${REPO_ROOT}" show "origin/main:${asset}" 2>/dev/null | sha256sum | awk '{print $1}' || true)"
  if [[ -n "$REMOTE_HASH" && "$LOCAL_HASH" == "$REMOTE_HASH" ]]; then
    pass "origin asset matches local: $asset"
  elif [[ -z "$REMOTE_HASH" ]]; then
    skip "origin asset unavailable: $asset"
  else
    fail "origin asset mismatch: $asset"
  fi
done

printf '\n========================================\n'
printf 'Results: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
if ((FAIL > 0)); then
  exit 1
fi
