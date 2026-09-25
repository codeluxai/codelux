# Codelux plugin for Claude Code

**The AI Development Space: local index, persistent memory and team sharing for your coding agents.**

The plugin connects Claude Code to [Codelux](https://codelux.ai), a daemon that runs on your machine:
a symbol index of your project, compressed file reads, memory that survives across sessions (notes,
facts, a continuation journal) and, on the Team plan, memory shared with your team.

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
| MCP server `codelux` | The Codelux tools (`code_map`, `code_memory`, `code_query`, `file_read`, `file_edit`, `code_note`, `code_set`, ...) at `http://localhost:<port>/mcp` |
| Skill `codelux-setup` | Guides Claude through checking the daemon, installing it, registering the project and verifying the tools |
| Skill `codelux-usage` | When and how to use the tools: memory first, query instead of reading whole files, checkpoint at the end |
| `/codelux:status` | Daemon, plan and project status |
| `/codelux:memory [since] [topic]` | Recalls the recent work on the project |
| `/codelux:checkpoint [topic]` | Saves decisions, facts and a checkpoint for the next session |
| SessionStart hook | Puts today's project memory in context; silent when Codelux is not running (needs `bash` and `curl`; on Windows, Git Bash) |

## Port

The default port is **8766**. If Codelux runs on another port (field `port` in `codelux.cfg`, printed by
`codelux start`), set the plugin option `port`: `/plugin` -> Codelux -> configure, or
`claude plugin install codelux@codelux --config port=<port>`. Then restart Claude Code.

## Privacy

The plugin collects nothing and talks only to `localhost`. Codelux itself runs locally: code, index and
history stay on your machine. See [codelux.ai/legal#privacy](https://codelux.ai/legal#privacy).

## Support

[codelux.ai/docs](https://codelux.ai/docs) - hello@codelux.ai
