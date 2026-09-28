# Codelux plugin for Claude Code

**The AI Development Space: local index, persistent memory and team sharing for your coding agents.**

The plugin connects Claude Code to [Codelux](https://codelux.ai), a daemon that runs on your machine:
the project's memory written by the AI itself (summary, next step, traps, decisions, facts anchored to
code, codemaps), notes between people and AI, a timeline of everything that happens, a live symbol index
to check facts against, a file lock between agents and, on the Team plan, all of it shared (encrypted)
with your team.

## Requirement

Codelux must be installed and running. Download it from
[codelux.ai/download](https://codelux.ai/download?utm=plugin&cdi=readme) (Free plan: no credit card),
extract it, run `codelux start` and create your account inside the app. Then add your project folder
from [codelux.ai/dashboard](https://codelux.ai/dashboard) -> Projects.

## Install

```bash
claude plugin marketplace add codeluxai/codelux
claude plugin install codelux@codelux
```

or, inside Claude Code: `/plugin marketplace add codeluxai/codelux`, then `/plugin install codelux@codelux`.

## What it adds

| Component | What it does |
|---|---|
| MCP server `codelux` | The 8 Codelux tools (`memory_set`, `memory_get`, `notes_set`, `notes_get`, `code_query`, `code_context`, `code_edit`, `agents_msg`) at `http://localhost:<port>/mcp` |
| Skill `codelux-setup` | Guides Claude through checking the daemon, installing it, registering the project and verifying the tools |
| Skill `codelux-usage` | When and how to use the tools: memory arrives by itself, check the index before answering, one `memory_set` at the end |
| `/codelux:status` | Daemon, plan, project and newest memory |
| `/codelux:memory [since] [topic]` | Recalls the recent work on the project (memories, timeline, open todos) |
| `/codelux:checkpoint [topic]` | Writes the memory of the session (`memory_set`) for the next one |
| SessionStart hook | Puts the newest project memory in context and refreshes the Codelux block in `AGENTS.md` (and `CLAUDE.md` if present); silent when Codelux is not running (needs `bash` and `curl`; on Windows, Git Bash) |
| UserPromptSubmit hook | Adds the codemaps, facts and decisions relevant to the prompt (local search, verified against the code); adds nothing when nothing is found |
| Edit/Write hooks | Take and release the file lock around each of Claude Code's own edits: local between agents on the machine, plus the Team lock on the Team plan; an edit is refused only when someone else holds the file |
| Stop hook | Reminds the model to close with `memory_set`; never blocks |

## AGENTS.md block

At every session start (and every `memory_set`) Codelux rewrites the block between
`<!-- codelux:start -->` and `<!-- codelux:end -->` in `<project>/AGENTS.md` (created if missing) and,
when the file exists, in `<project>/CLAUDE.md`: status, next step, traps and recent decisions in at most
60 lines. Text outside the markers is never touched. `scripts/agents-md.sh` refreshes it by hand.

## Other agents: Codex, Gemini CLI

The same scripts work from any agent that runs command hooks; `hooks/` ships ready-made configurations
(replace `CODELUX_PLUGIN` with the absolute path of this plugin folder):

| Agent | File | Where to copy it |
|---|---|---|
| Codex | `hooks/codex.hooks.json` | `<repo>/.codex/hooks.json` (or `~/.codex/hooks.json`): SessionStart, UserPromptSubmit, PreToolUse/PostToolUse on edits, Stop |
| Gemini CLI | `hooks/gemini.settings.json` | merge its `hooks` object into `<repo>/.gemini/settings.json`: SessionStart, BeforeAgent (memory as `additionalContext`), BeforeTool/AfterTool for the lock, AfterAgent reminder; scripts run with `--json` |

The MCP server is the same URL for every agent: `http://localhost:<port>/mcp`. What the hooks do not
carry, the `AGENTS.md` block does (Gemini reads `GEMINI.md`: point its `contextFileName` at `AGENTS.md`
or copy the block). Fields we could not verify against the official docs are listed in
`hooks/OTHER-AGENTS.md`.

## Port

The default port is **8766**. If Codelux runs on another port (field `port` in `codelux.cfg`, printed by
`codelux start`), set the plugin option `port`: `/plugin` -> Codelux -> configure, or
`claude plugin install codelux@codelux --config port=<port>`. Then restart Claude Code.

## Privacy

The plugin collects nothing and talks only to `localhost`. Codelux itself runs locally: code, index and
history stay on your machine. See [codelux.ai/legal#privacy](https://codelux.ai/legal#privacy).

## Support

[codelux.ai/docs](https://codelux.ai/docs) - hello@codelux.ai
