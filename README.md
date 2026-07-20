# Claude Code Lean

**Website:** https://0p9b.github.io/claude-code-lean/  
**Config breakdown:** https://0p9b.github.io/claude-code-lean/config.html

Cut Claude Code CLI startup context. Start lean, step up only as far as you need.

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | bash
```

You’ll get an interactive menu → confirm step → install (backs up existing files).

Look for **`Installer version: 2026-07-19-15`**. If GitHub raw looks stale:

```bash
git clone --depth 1 https://github.com/0p9b/claude-code-lean.git /tmp/claude-code-lean && bash /tmp/claude-code-lean/install.sh
```

## Four profiles (+ Both)

| # | Profile | Tools | System prompt | Thinking | Run |
|---|---------|-------|---------------|----------|-----|
| **1** | **Ultra** | 6 core | Custom minimal | Off | `claude-lean` |
| **2** | **Regular** | 6 core | Claude Code default | Off | `claude` |
| **3** | **Balanced** ★ | 6 + Glob/Grep/TodoWrite | Claude Code default | **On** | `claude` |
| **4** | **Both** | 6 core | Ultra *or* Regular | Off | either command |
| **5** | **Custom** | You choose | Wizard | Optional | your picks |

- **1–3 & 5** = the four profiles (stripped → practical → fully custom).  
- **4 Both** = convenience: installs Ultra + Regular launchers with the lean 6-tool settings.

Non-interactive:

```bash
curl -fsSL https://raw.githubusercontent.com/0p9b/claude-code-lean/main/install.sh | CLAUDE_LEAN_MODE=balanced bash
# ultra | regular | balanced | both
# custom requires the interactive menu (option 5)
```

## After install

1. Restart any open Claude Code sessions  
2. Run `claude` or `claude-lean` (depending on what you picked)  
3. Type `/context` to verify  

If `claude-lean` isn’t found:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Files you can edit later

The installer prints these paths. Defaults:

| File | What to change |
|------|----------------|
| `~/.claude/settings.json` | Tools deny list, effort, thinking, memory, feature disables |
| `~/.claude/output-styles/lean.md` | Short output style (“Be brief.”) |
| `~/.local/bin/claude-lean` | Ultra launcher script |
| `~/.claude/system-prompt-lean.txt` | Ultra system prompt text |
| `~/.claude/claude-lean.conf` | Custom tool list for `claude-lean` (Custom mode only) |

Or just re-run the installer anytime — it backs up existing files first.

Full reference: [docs/CONFIG.md](docs/CONFIG.md) · [config.html](https://0p9b.github.io/claude-code-lean/config.html)

## What you get

**Lean base (Ultra / Regular / Both):**  
`Bash` · `Read` · `Write` · `Edit` · `WebSearch` · `WebFetch`

**Balanced adds:** `Glob` · `Grep` · `TodoWrite` · thinking on

**Still off in Balanced:** MCP, Agent, skills, Task*, LSP, memory, hooks, CLAUDE.md, git instructions, …

**Defaults:** effort `medium` · OAuth login kept (no `--bare`)

## Requirements

- [Claude Code CLI](https://code.claude.com/docs/en/overview) on your `PATH`
- `curl`
- `python3` (Custom mode only)

## License

MIT
