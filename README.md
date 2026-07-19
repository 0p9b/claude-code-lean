# Claude Code Lean

Cut Claude Code CLI startup context. Keep six tools. Pick your system prompt.

## Install (one command)

```bash
curl -fsSL "https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh?$(date +%s)" | bash
```

(The `?$(date +%s)` avoids GitHub’s raw CDN serving a stale script.)

You’ll see a menu explaining both options, then:

| Choice | What you get | After install, run | Typical `/context` |
|---|---|---|---|
| **1 — Ultra Lean** | Tiny custom system prompt | `claude-lean` | ~4.5–5k |
| **2 — Regular Lean** | Claude Code’s default lean system prompt | `claude` | ~6.5k |

Same six tools either way. Same settings. Only the system prompt differs (~1.8k).

Skip the menu (optional):

```bash
curl -fsSL "https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh?$(date +%s)" | CLAUDE_LEAN_MODE=ultra bash
# or
curl -fsSL "https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh?$(date +%s)" | CLAUDE_LEAN_MODE=regular bash
```

## What you get

**Enabled tools**

- `Bash` · `Read` · `Write` · `Edit` · `WebSearch` · `WebFetch`

**Disabled**

- MCP / Claude.ai connectors
- Skills, workflows, agents, plan mode, cron, tasks, LSP, and the rest
- Auto memory / CLAUDE.md injection

**Defaults**

- Effort: `medium`
- OAuth login still works (no `--bare`)

## After install

```bash
claude-lean   # if you picked Ultra Lean
claude        # if you picked Regular Lean
```

Then run `/context` inside the session.

If `claude-lean` is “command not found”, add this to your shell config:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Requirements

- [Claude Code CLI](https://code.claude.com/docs/en/overview) installed
- `curl`

## Customize later

| Goal | Edit |
|---|---|
| Ultra prompt text | `~/.claude/system-prompt-lean.txt` |
| Tool allow/deny | `~/.claude/settings.json` + `~/.local/bin/claude-lean` |
| Effort | `effortLevel` in settings + `--effort` in `claude-lean` |

Existing files are backed up as `*.bak.<timestamp>` before overwrite.

## Uninstall

```bash
rm -f ~/.local/bin/claude-lean
# Optionally restore: ls ~/.claude/settings.json.bak.*
```

## License

MIT — no keys or account data in this repo.
