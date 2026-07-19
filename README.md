# Claude Code Lean

Cut Claude Code CLI startup context. Keep six tools. Pick your system prompt.

## Install (one command)

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/0p9b/claude-code-lean@main/install.sh | bash
```

You should see a full menu like this (not just `1 / 2 / q`):

```text
========================================
  Claude Code Lean installer
========================================

  1) Ultra Lean   → run claude-lean   (~4.5–5k context)
  2) Regular Lean → run claude        (~6.5k context)
  q) Quit
```

| Choice | What you get | After install, run |
|---|---|---|
| **1 — Ultra Lean** | Tiny custom system prompt | `claude-lean` |
| **2 — Regular Lean** | Claude Code’s default lean system prompt | `claude` |

Same six tools either way. Only the system prompt differs (~1.8k).

Skip the menu (optional):

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/0p9b/claude-code-lean@main/install.sh | CLAUDE_LEAN_MODE=ultra bash
# or
curl -fsSL https://cdn.jsdelivr.net/gh/0p9b/claude-code-lean@main/install.sh | CLAUDE_LEAN_MODE=regular bash
```

If the menu looks wrong/outdated, force a fresh copy:

```bash
curl -fsSL "https://cdn.jsdelivr.net/gh/0p9b/claude-code-lean@main/install.sh" | bash
# or clone (always latest):
git clone --depth 1 https://github.com/0p9b/claude-code-lean.git /tmp/claude-code-lean && bash /tmp/claude-code-lean/install.sh
```

## What you get

**Enabled tools:** `Bash` · `Read` · `Write` · `Edit` · `WebSearch` · `WebFetch`

**Disabled:** MCP, skills, workflows, agents, plan mode, cron, tasks, LSP, auto memory, etc.

**Defaults:** effort `medium`, OAuth login still works (no `--bare`)

## After install

```bash
claude-lean   # Ultra Lean
claude        # Regular Lean
```

Then `/context`. If `claude-lean` is missing from PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Requirements

- [Claude Code CLI](https://code.claude.com/docs/en/overview)
- `curl`

## License

MIT
