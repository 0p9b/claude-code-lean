# Claude Code Lean

Cut Claude Code CLI startup context. Keep six tools. Pick your system prompt.

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | bash
```

You’ll get an interactive prompt:

| Choice | Command | System prompt | Typical `/context` |
|---|---|---|---|
| **1) Ultra Lean** | `claude-lean` | Minimal custom prompt | ~4.5–5k |
| **2) Regular Lean** | `claude` | Claude Code default lean prompt | ~6.5k |

Same tools either way. Same settings. Only the system prompt differs (~1.8k).

Non-interactive (optional):

```bash
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | CLAUDE_LEAN_MODE=ultra bash
# or
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | CLAUDE_LEAN_MODE=regular bash
```

## What you get

**Enabled tools**

- `Bash` · `Read` · `Write` · `Edit` · `WebSearch` · `WebFetch`

**Disabled**

- MCP / Claude.ai connectors
- Skills, workflows, agents, plan mode, cron, tasks, LSP, and the rest (via deny list)
- Auto memory / CLAUDE.md injection

**Defaults**

- Effort: `medium`
- OAuth login still works (no `--bare`)

## After install

```bash
# Ultra Lean
claude-lean

# Regular Lean
claude
```

Then run `/context` inside the session.

Make sure `~/.local/bin` is on your `PATH` if you chose Ultra Lean:

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
| Tool allow/deny | `~/.claude/settings.json` (`permissions.deny`) + `~/.local/bin/claude-lean` (`--tools`) |
| Effort | `effortLevel` in settings + `--effort` in `claude-lean` |

Existing files are backed up as `*.bak.<timestamp>` before overwrite.

## Uninstall

```bash
rm -f ~/.local/bin/claude-lean
# Optionally restore: ls ~/.claude/settings.json.bak.*
```

## License

MIT — no keys or account data in this repo.
