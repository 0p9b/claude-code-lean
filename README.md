# Claude Code Lean

**Website:** https://0p9b.github.io/claude-code-lean/  
**Config breakdown:** https://0p9b.github.io/claude-code-lean/config.html

Cut Claude Code CLI startup context. Keep six tools. Pick your system prompt — or use **Custom** to configure via wizard.

## Profiles

| Profile | Stripped? | System prompt | Run |
|---------|-----------|---------------|-----|
| **Ultra** | Most (~4.5–5k) | Custom minimal | `claude-lean` |
| **Regular** | Lean (~6.5k) | Claude Code default | `claude` |
| **Both** | Pick per session | Either | both commands |
| **Custom** | You choose | Wizard | your picks |

See [docs/CONFIG.md](docs/CONFIG.md) for the full disabled-state breakdown.

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | bash
```

Interactive menu → confirm screen → install. Option **4 — Custom** walks through launcher, effort, and optional tool packs.

| Choice | What it does |
|--------|----------------|
| **1 — Ultra** | settings + `claude-lean` |
| **2 — Regular** | settings only |
| **3 — Both** | settings + `claude-lean` (recommended) |
| **4 — Custom** | wizard: pick tools, effort, launcher |

Skip the menu:

```bash
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | CLAUDE_LEAN_MODE=both bash
# ultra | regular (custom requires interactive wizard)
```

Look for `Installer version: 2026-07-19-11`.

## What you get (lean defaults)

**Enabled:** `Bash` · `Read` · `Write` · `Edit` · `WebSearch` · `WebFetch`

**Disabled:** MCP, skills, workflows, agents, Glob, Grep, tasks, LSP, auto memory, hooks, etc.

**Defaults:** effort `medium`, OAuth login still works (no `--bare`)

## Requirements

- [Claude Code CLI](https://code.claude.com/docs/en/overview)
- `curl`
- `python3` (Custom mode only)

## License

MIT
