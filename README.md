# Claude Code Lean

Cut Claude Code CLI startup context. Keep six tools. Pick your system prompt.

## Install (one command)

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/0p9b/claude-code-lean@main/install.sh | bash
```

You’ll see a menu:

| Choice | Installs | After install, run |
|---|---|---|
| **1 — Ultra Lean only** | settings + `claude-lean` | `claude-lean` (~4.5–5k) |
| **2 — Regular Lean only** | settings only | `claude` (~6.5k) |
| **3 — Both** (recommended) | settings + `claude-lean` | either command below |

### Option 3 — Both (matches a full local setup)

Same lean settings either way. You choose when you launch:

```bash
claude-lean   # Ultra: custom minimal system prompt (~4.5–5k)
claude        # Regular: default Claude Code system prompt (~6.5k)
```

Only the system prompt differs (~1.8k). Tools are identical.

Skip the menu (optional):

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/0p9b/claude-code-lean@main/install.sh | CLAUDE_LEAN_MODE=both bash
# or: ultra | regular
```

Look for `Installer version: 2026-07-19-4` at the start. If it’s missing/old:

```bash
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
