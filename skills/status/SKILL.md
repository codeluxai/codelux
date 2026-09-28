---
name: status
description: Show whether the local Codelux daemon is running, which account plan it has, and whether the current folder is an indexed Codelux project.
disable-model-invocation: true
allowed-tools: Bash(curl:*)
---

# /codelux:status

Report the Codelux status for the current folder in a short table (item | value). `PORT` is `8766`
unless the user set the plugin option `port` (stored in `~/.claude/settings.json` under
`pluginConfigs["codelux@<marketplace>"].options.port`).

1. Daemon: `curl -s --connect-timeout 2 http://localhost:PORT/api/auth/status`
   - No answer: say Codelux is not running on that port and point to the `codelux-setup` skill
     (download https://codelux.ai/download?utm=plugin&cdi=status, then `codelux start`). Stop here.
   - Answer: report running, the `pid`, whether a token is present / authenticated, and heartbeat `ok`.
2. Project: `curl -s http://localhost:PORT/api/projects` and look for the entry whose `path` equals the
   current working directory (case-insensitive on Windows, `\` = `/`).
   - Not found: say this folder is not a registered project and how to add it
     (https://codelux.ai/dashboard -> Projects -> Add a project, absolute path). Stop here.
   - Found: report its id, name, path and, if present, team name / role / share mode.
3. MCP: say whether the `codelux` MCP tools (`memory_get`, `memory_set`, `notes_get`, `notes_set`,
   `code_query`, `code_context`, `code_edit`, `agents_msg`) are available in this session. If they are
   not, say the MCP server is not connected and suggest `/mcp` to reconnect.
4. Memory: if the tools answer, `memory_get` with `root` and report the date and topic of the newest
   memory (or that there is none yet).

Keep it to the table plus at most one line of next step. Do not print tokens or account emails.
