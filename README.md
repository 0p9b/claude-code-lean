# Claude Code Lean

A minimal [Claude Code](https://code.claude.com/docs) CLI setup that cuts startup context while keeping a usable coding toolset.

Typical results after install (Sonnet, empty session, run `/context`):

| Launcher | Approx. startup context | Difference |
|---|---|---|
| `claude-lean` | ~4.5–5k tokens | Minimal custom system prompt |
| `claude` | ~6.5k tokens | Same tools + Claude Code’s lean product system prompt (~+1.8k) |

Numbers vary by model/version. The point is the delta: **same six tools**, different system prompt.

## What you get

### Enabled tools (both `claude` and `claude-lean`)

1. `Bash`
2. `Read`
3. `Write`
4. `Edit`
5. `WebSearch`
6. `WebFetch`

Everything else is denied (including all MCP tools via `mcp__*`). Default effort is **medium** for both launchers.

### `claude` (regular)

- Uses `~/.claude/settings.json` from this repo
- Keeps Claude Code’s **default lean system prompt** (`CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT=1`)
- Same six tools

### `claude-lean`

Same settings as regular `claude`, plus:

```bash
claude \
  --system-prompt-file ~/.claude/system-prompt-lean.txt \
  --tools "Bash,Edit,Read,Write,WebFetch,WebSearch" \
  --disallowedTools "mcp__*" \
  --effort medium
```

The prompt file is a single `.` by default (replace if you want a short custom identity). **OAuth / Claude.ai login still works** — this does **not** use `--bare` (bare mode requires an API key and skips OAuth).

## Requirements

- [Claude Code CLI](https://code.claude.com/docs/en/overview) installed (`claude` on your `PATH`)
- Logged in as usual (`claude` OAuth / subscription login is fine)

## Install

```bash
git clone https://github.com/0p9b/claude-code-lean.git
cd claude-code-lean
chmod +x install.sh bin/claude-lean
./install.sh
```

The installer:

1. Backs up any existing `~/.claude/settings.json`, `system-prompt-lean.txt`, and `output-styles/lean.md`
2. Copies config + templates into `~/.claude/`
3. Installs `claude-lean` to `~/.local/bin/claude-lean`

Ensure `~/.local/bin` is on your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Restart Claude Code sessions after installing.

## Verify

```bash
claude-lean
# then:
/context
```

You should see a small **System tools** budget for the six tools, and a tiny system prompt under `claude-lean`. Compare with plain `claude` + `/context` — expect ~1.5–2k more on the system prompt line.

## Customize

| Want… | Do this |
|---|---|
| Different lean prompt text | Edit `~/.claude/system-prompt-lean.txt` (or set `CLAUDE_LEAN_PROMPT_FILE`) |
| Add a tool | Remove it from `permissions.deny` in `~/.claude/settings.json` **and** add it to `--tools` in `~/.local/bin/claude-lean` |
| Remove a tool | Add it to `permissions.deny` and remove it from the `claude-lean` `--tools` list |
| Change effort | Set `effortLevel` in settings **and** `--effort` in `claude-lean` |
| Drop the “Be brief.” style | Remove `"outputStyle": "lean"` from settings, or edit `~/.claude/output-styles/lean.md` |

## What’s stripped (high level)

Settings intentionally disable or deny:

- Bundled skills / workflows / artifacts / remote control / agent view
- Auto memory + CLAUDE.md injection (`CLAUDE_CODE_DISABLE_CLAUDE_MDS`)
- Claude.ai connectors + all MCP tools (`mcp__*`)
- Plan mode, cron, tasks, worktrees, LSP, Monitor, Agent, Skill, etc.
- Extra product surface (`EndConversation`, `Brief`, …) via deny list

**Important:** bare-name deny rules remove tool schemas from context. Scoped rules like `Bash(rm *)` do **not** save tokens.

Watch for new tools in Claude Code releases (e.g. `EndConversation` in v2.1.214+) — if `/context` jumps, check release notes and add unknown tools to `deny`.

## Layout

```text
.
├── README.md
├── LICENSE
├── install.sh
├── bin/claude-lean
├── config/settings.json
└── templates/
    ├── system-prompt-lean.txt
    └── output-styles/lean.md
```

## Security / privacy

This repo contains **no API keys, tokens, or account data**. Do not commit your real `~/.claude` directory, OAuth cache, or `.env` files.

`permissions.defaultMode: "auto"` matches a hands-off local workflow. Change it to `"default"` or `"acceptEdits"` if you want more prompts.

## Uninstall

```bash
rm -f ~/.local/bin/claude-lean
# Restore a backup if the installer created one:
#   ls ~/.claude/settings.json.bak.*
# Or delete ~/.claude/settings.json and reconfigure via Claude Code.
```

## References

- [Claude Code settings](https://code.claude.com/docs/en/settings)
- [Tools reference](https://code.claude.com/docs/en/tools-reference)
- [Environment variables](https://code.claude.com/docs/en/env-vars)
- [CLI reference](https://code.claude.com/docs/en/cli-reference) (`--system-prompt-file`, `--tools`)

## License

MIT
