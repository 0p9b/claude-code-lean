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

Full disabled-state breakdown: [docs/CONFIG.md](docs/CONFIG.md) · [config.html](https://0p9b.github.io/claude-code-lean/config.html)

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | bash
```

1. Interactive menu (↑↓ or `1`–`4` / `q`)
2. Confirm screen (Yes / No)
3. Installs and backs up any existing `~/.claude/settings.json`

| Choice | What it does |
|--------|----------------|
| **1 — Ultra** | settings + `claude-lean` (most stripped) |
| **2 — Regular** | settings only → run `claude` |
| **3 — Both** | settings + `claude-lean` (recommended) |
| **4 — Custom** | wizard: launcher, effort, optional tool packs |

Skip the menu:

```bash
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | CLAUDE_LEAN_MODE=both bash
# ultra | regular   (custom requires interactive option 4)
```

Look for `Installer version: 2026-07-19-12`. If it’s old/missing:

```bash
git clone --depth 1 https://github.com/0p9b/claude-code-lean.git /tmp/claude-code-lean && bash /tmp/claude-code-lean/install.sh
```

## After install

```bash
claude-lean   # Ultra (or Custom with ultra/both)
claude        # Regular Lean
```

Then `/context` to verify. If `claude-lean` isn’t found:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

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
