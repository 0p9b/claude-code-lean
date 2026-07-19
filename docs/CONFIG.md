# Configuration breakdown

How Claude Code Lean strips context, what stays enabled, and how profiles compare.

## Profile overview

| Profile | System prompt | Tools | Thinking | Startup context | Launcher |
|--------|----------------|-------|----------|-----------------|----------|
| **Ultra Lean** | Custom minimal (`.`) | 6 core | Off | ~4.5–5k | `claude-lean` |
| **Regular Lean** | Claude Code default lean | 6 core | Off | ~6.5k | `claude` |
| **Balanced** | Claude Code default lean | 6 + Glob/Grep/TodoWrite | **On** | ~7–9k | `claude` |
| **Both** | Pick Ultra or Regular | 6 core | Off | Either | both commands |
| **Custom** | You choose | Wizard packs | Optional | Varies | Wizard-driven |

**Ultra is the most stripped-down at launch.** Regular keeps the same lean deny list — the ~1.8k gap is mostly the product system prompt. **Balanced** sits between Regular and Custom: still major savings, but code search + todos + thinking.

---

## Enabled by default

### Lean base tools (Ultra / Regular / Both)

| Tool | Purpose |
|------|---------|
| `Bash` | Run shell commands |
| `Read` | Read files |
| `Write` | Create files |
| `Edit` | Edit files |
| `WebSearch` | Search the web |
| `WebFetch` | Fetch URLs |

### Balanced extras

| Tool / feature | Purpose |
|----------------|---------|
| `Glob` | Find files by pattern |
| `Grep` | Search file contents |
| `TodoWrite` | Simple checklist |
| Thinking | Extended thinking UI on |

### Settings defaults

| Setting | Value |
|---------|-------|
| `effortLevel` | `medium` |
| `outputStyle` | `lean` (“Be brief.”) |
| `permissions.defaultMode` | `auto` |
| OAuth | **Kept** — no `--bare`, no API key required |

---

## Disabled by default (lean base)

### Environment flags (`env`)

All set to `"1"` (= off) in lean defaults:

| Flag | What it disables |
|------|------------------|
| `CLAUDE_CODE_SIMPLE_SYSTEM_PROMPT` | Shorter built-in system prompt components |
| `CLAUDE_CODE_DISABLE_CLAUDE_MDS` | `CLAUDE.md` / project markdown injection |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY` | Auto memory |
| `CLAUDE_CODE_DISABLE_ORG_MEMORY` | Org memory |
| `CLAUDE_CODE_DISABLE_POLICY_SKILLS` | Policy skills |
| `CLAUDE_CODE_DISABLE_CLAUDE_CODE_SKILL` | Claude Code bundled skill |
| `CLAUDE_CODE_DISABLE_CLAUDE_API_SKILL` | Claude API skill |
| `CLAUDE_CODE_DISABLE_ADVISOR_TOOL` | Advisor tool |
| `CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS` | Explore / plan subagents |
| `CLAUDE_CODE_DISABLE_ATTACHMENTS` | Attachments |
| `CLAUDE_CODE_DISABLE_GIT_INSTRUCTIONS` | Git instruction injection |
| `CLAUDE_CODE_DISABLE_CRON` | Cron scheduling |
| `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` | Background tasks |
| `CLAUDE_CODE_DISABLE_THINKING` | Extended thinking |

*(Balanced clears `CLAUDE_CODE_DISABLE_THINKING` and turns thinking UI on.)*

### Feature toggles

| Setting | Lean default |
|---------|--------------|
| `disableAllHooks` | `true` |
| `disableBundledSkills` | `true` |
| `disableWorkflows` | `true` |
| `disableRemoteControl` | `true` |
| `disableClaudeAiConnectors` | `true` |
| `disableArtifact` | `true` |
| `disableAgentView` | `true` |
| `autoMemoryEnabled` | `false` |
| `alwaysThinkingEnabled` | `false` (Balanced: `true`) |
| `showThinkingSummaries` | `false` (Balanced: `true`) |
| `includeGitInstructions` | `false` |
| `includeCoAuthoredBy` | `false` |
| `skillListingBudgetFraction` | `0.001` |
| `feedbackSurveyRate` | `0` |
| `spinnerTipsEnabled` | `false` |

### Denied tools (`permissions.deny`)

Everything except the six core tools (lean base):

| Category | Tools blocked |
|----------|---------------|
| **Search** | `Glob`, `Grep` *(enabled in Balanced)* |
| **Tasks** | `TodoWrite` *(enabled in Balanced)*, `TaskCreate`, `TaskGet`, `TaskList`, `TaskOutput`, `TaskStop`, `TaskUpdate` |
| **Agents / plan** | `Agent`, `EnterPlanMode`, `ExitPlanMode`, `EnterWorktree`, `ExitWorktree` |
| **Skills** | `Skill`, `ToolSearch` |
| **MCP** | `mcp__*`, `ListMcpResourcesTool`, `ReadMcpResourceTool`, `WaitForMcpServers` |
| **Comms** | `AskUserQuestion`, `SendMessage`, `SendUserMessage`, `SendUserFile`, `PushNotification` |
| **Other** | `Artifact`, `Brief`, `CronCreate`, `CronDelete`, `CronList`, `DesignSync`, `EndConversation`, `LSP`, `Monitor`, `NotebookEdit`, `PowerShell`, `RemoteTrigger`, `ReportFindings`, `ScheduleWakeup`, `ShareOnboardingGuide`, `Workflow` |

---

## Custom mode — optional packs

The installer wizard lets you add optimized packs on top of the lean base:

| Pack | Enables | Best for |
|------|---------|----------|
| **search** | `Glob`, `Grep` | Codebase navigation |
| **todos** | `TodoWrite` | Simple checklists |
| **tasks** | `TodoWrite`, `Task*` | Full task suite |
| **agents** | `Agent`, plan/worktree modes | Subagents & plan mode |
| **skills** | `Skill`, bundled skills | Skill workflows |
| **mcp** | MCP servers & tools | Connectors / MCP |
| **memory** | Auto + org memory | Long-running context |
| **claude_md** | `CLAUDE.md` injection | Project-specific rules |
| **thinking** | Extended thinking UI | Deeper reasoning |
| **git** | Git instructions | Commit/PR workflows |
| **hooks** | User hooks | Custom automation |
| **cron** | Cron + background tasks | Scheduled jobs |
| **comms** | AskUserQuestion, messaging | Interactive flows |
| **extra** | LSP, NotebookEdit, workflows, etc. | Power-user tooling |

Generated files (Custom with ultra/both launcher):

- `~/.claude/settings.json` — permissions + env
- `~/.claude/claude-lean.conf` — tool list for `claude-lean` (if ultra/both launcher selected)
