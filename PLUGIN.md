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
from the app's Projects view (+ Add project); it is listed in [codelux.ai/console](https://codelux.ai/console) -> Account -> Your projects.

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
| SessionStart hook | Puts the newest project memory in context and refreshes the Codelux block in `AGENTS.md` (and `CLAUDE.md` if present); silent when Codelux is not running (needs `bash` and `curl`; on Windows, Git Bash); one line when the plugin is doubled (an older "Codelux" from the Claude Directory next to this one) or its local install is broken |
| SubagentStart hook | The agent brief of the task the main session gave the subagent: plan and claims, decisions and traps of the topics it names (with who wrote them and when), the compressed index of each file it cites (`file: symbol@a-b, …`), code bodies while they fit; at most 9,000 chars, within 3 s (past it: a short brief and `memory_get{id:"late_…"}` for the whole one) |
| UserPromptSubmit hook | Adds the codemaps, facts and decisions relevant to the prompt (local search, verified against the code); adds nothing when nothing is found |
| Edit/Write hooks | Take and release the file lock around each of Claude Code's own edits: local between agents on the machine, plus the Team lock on the Team plan; an edit is refused only when someone else holds the file |
| Session tracker (`session-track.sh`, silent) | On SessionStart, UserPromptSubmit, PreToolUse (Read and Codelux tools), Stop, SubagentStop and SessionEnd: gives the conversation ONE Codelux session code (the same name on locks, memories, notes and messages), records the files read (path, hash, line range, never the text), reads the token numbers of each turn from the transcript and writes an end-of-work usage report (tools `tasks_get`, `tasks_report`; Timeline). Prints nothing, so it adds nothing to the context |

## Two "codelux" plugins

If you installed Codelux both from the Claude plugin Directory (your account) and from this marketplace, the Claude desktop app may load the Directory copy only. When that copy is older, Codelux says so at session start (`⚠ Codelux: this session runs the OLD account plugin …`) and the app's Usage page shows "Hooks active: no". Fix: in the Claude app open Plugins (Manage plugins), turn off or remove the Directory "Codelux", keep `codelux@codelux`, start a new session. A local install whose folder is gone: `claude plugin install codelux@codelux`, then `/reload-plugins`.

## AGENTS.md block

At session start Codelux makes sure the block between `<!-- codelux:start -->` and
`<!-- codelux:end -->` is present in `<project>/AGENTS.md` (created if missing) and, when the file
exists, in `<project>/CLAUDE.md`. The block is STABLE: a few fixed lines (which tools to use, the pointer
"the memory reaches you at session start and with your requests, or ask `memory_get`"), identical in every
session until Codelux itself changes the text. It carries no date, status, next step or counter: those
change at every `memory_set` and would invalidate the provider's prompt cache for every new session, since
these files are the first context an agent reads. What varies reaches the agent as a message instead
(the SessionStart memory and the per-prompt brief). Text outside the markers is never touched.
`scripts/agents-md.sh` refreshes it by hand.

## Other agents: Codex, Gemini CLI

The same scripts work from any agent that runs command hooks; `hooks/` ships ready-made configurations
(replace `CODELUX_PLUGIN` with the absolute path of this plugin folder):

| Agent | File | Where to copy it |
|---|---|---|
| Codex | `hooks/codex.hooks.json` | `<repo>/.codex/hooks.json` (or `~/.codex/hooks.json`): SessionStart, UserPromptSubmit, PreToolUse/PostToolUse on edits, Stop |
| Gemini CLI | `hooks/gemini.settings.json` | merge its `hooks` object into `<repo>/.gemini/settings.json`: SessionStart, BeforeAgent (memory as `additionalContext`), BeforeTool/AfterTool for the lock, AfterAgent for the turn-finished signal of the tracker; scripts run with `--json` |

The MCP server is the same URL for every agent: `http://localhost:<port>/mcp`. What the hooks do not
carry, the `AGENTS.md` block does (Gemini reads `GEMINI.md`: point its `contextFileName` at `AGENTS.md`
or copy the block). Fields we could not verify against the official docs are listed in
`hooks/OTHER-AGENTS.md`.

## Port

The default port is **8766**. If Codelux runs on another port (field `port` in `codelux.cfg`, printed by
`codelux start`), set the plugin option `port`: `/plugin` -> Codelux -> configure, or
`claude plugin install codelux@codelux --config port=<port>`. Then restart Claude Code.

## Privacy

The plugin collects nothing and talks only to `localhost`. The session tracker hands the local daemon
the hook input (session id, transcript path, the path and range of a file read); the daemon keeps ids,
times, counters, paths and hashes and reads only the token numbers from the transcript, never its text. Codelux itself runs locally: code, index and
history stay on your machine. See [codelux.ai/legal#privacy](https://codelux.ai/legal#privacy).

## Support

[codelux.ai/docs](https://codelux.ai/docs) - hello@codelux.ai
