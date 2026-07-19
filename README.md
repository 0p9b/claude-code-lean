# Claude Code Lean

**Website:** https://0p9b.github.io/claude-code-lean/  
**Config breakdown:** https://0p9b.github.io/claude-code-lean/config.html

Cut Claude Code CLI startup context. Start lean, then step up only as far as you need.

## Profiles

| Profile | Tools | System prompt | Thinking | Run |
|---------|-------|---------------|----------|-----|
| **Ultra** | 6 core | Custom minimal | Off | `claude-lean` |
| **Regular** | 6 core | Claude Code default | Off | `claude` |
| **Balanced** | 6 + Glob/Grep/TodoWrite | Claude Code default | **On** | `claude` |
| **Both** | 6 core | Ultra *or* Regular | Off | either command |
| **Custom** | You choose | Wizard | Optional | your picks |

Full disabled-state breakdown: [docs/CONFIG.md](docs/CONFIG.md) · [config.html](https://0p9b.github.io/claude-code-lean/config.html)

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | bash
```

1. Interactive menu (↑↓ or `1`–`5` / `q`)
2. Confirm screen (Yes / No)
3. Installs and backs up any existing `~/.claude/settings.json`

| Choice | What it does |
|--------|----------------|
| **1 — Ultra** | settings + `claude-lean` (most stripped) |
| **2 — Regular** | settings only → run `claude` |
| **3 — Balanced** | practical tools + thinking → run `claude` |
| **4 — Both** | Ultra + Regular launchers (lean 6 tools) |
| **5 — Custom** | wizard: launcher, effort, optional packs |

Skip the menu:

```bash
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | CLAUDE_LEAN_MODE=balanced bash
# ultra | regular | balanced | both   (custom requires interactive option 5)
```

Look for `Installer version: 2026-07-19-13`. If it’s old/missing:

```bash
git clone --depth 1 https://github.com/0p9b/claude-code-lean.git /tmp/claude-code-lean && bash /tmp/claude-code-lean/install.sh
```

## After install

```bash
claude-lean   # Ultra (or Custom with ultra/both)
claude        # Regular or Balanced
```

Then `/context` to verify. If `claude-lean` isn’t found:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## What you get

**Lean base (Ultra / Regular / Both):**  
`Bash` · `Read` · `Write` · `Edit` · `WebSearch` · `WebFetch`

**Balanced adds:** `Glob` · `Grep` · `TodoWrite` · thinking on

**Still disabled in Balanced:** MCP, Agent, skills, Task*, LSP, memory, hooks, CLAUDE.md, git instructions, etc.

**Defaults:** effort `medium`, OAuth login still works (no `--bare`)

## Requirements

- [Claude Code CLI](https://code.claude.com/docs/en/overview)
- `curl`
- `python3` (Custom mode only)

## License

MIT
