---
name: codelux-setup
description: Set up Codelux for this project - check that the local Codelux daemon is running, guide the user through download, first start and account creation if it is not, register the current folder as a Codelux project, and confirm the codelux MCP tools answer. Use when the codelux MCP server is missing or failing, when a Codelux tool says the folder "is not indexed", or when the user asks to install, connect or configure Codelux.
---

# Codelux setup

Codelux is a local daemon: the plugin only connects Claude Code to it. Everything runs on the user's
machine; the plugin itself stores and sends nothing. Walk through the steps in order, stop at the first
one that fails, and tell the user exactly what to do. Never ask the user for passwords or tokens, and
never sign in, sign out or change their account yourself.

Below, `PORT` is the Codelux port: `8766` unless the user changed it. A changed port is stored as the
plugin option `port`, in the user's `~/.claude/settings.json` under
`pluginConfigs["codelux@<marketplace>"].options.port`; the MCP server of this plugin connects to
`http://localhost:<that port>/mcp`.

## 1. Is the daemon running?

```bash
curl -s --connect-timeout 2 http://localhost:PORT/api/auth/status
```

- **JSON answer** (it contains `"server_url"` and `"token_present"`): the daemon is up. Go to step 3.
- **Connection refused / no answer**: go to step 2.
- If the user runs Codelux on another port, the startup line tells it
  (`Codelux running - dashboard: http://localhost:<port>`); see "Different port" below.

## 2. Install and start Codelux (only if step 1 failed)

Tell the user, in their language:

1. Download Codelux from **https://codelux.ai/download?utm=plugin&cdi=setup** (Windows, macOS, Linux; the
   Free plan needs no credit card).
2. Extract the ZIP into a folder of their choice.
3. Start it from a terminal in that folder: `codelux start` (Windows: `codelux.exe start`; Linux can also
   use `./codelux install-service` to run it as a systemd service).
   It prints `Codelux running - dashboard: http://localhost:8766`.
4. Open that dashboard URL in the browser and create the account (or sign in) **inside the app**.

Wait for the user to confirm, then repeat step 1. Do not try to download or run the binary yourself
unless the user explicitly asks you to.

## 3. Is this folder a registered project?

```bash
curl -s http://localhost:PORT/api/projects
```

It returns `[{"id":..., "name":..., "path":...}, ...]`. Compare each `path` with the current working
directory (case-insensitive on Windows; `\` and `/` are equivalent).

- **Found**: remember that `path`. Every Codelux tool takes it as `root` (the ABSOLUTE PATH of the project
  folder, never the id or the name). Go to step 4.
- **Not found**: the daemon cannot add projects on its own - projects are registered by the user:
  - **Multi / Team plan**: sign in at **https://codelux.ai/dashboard**, open **Projects**, paste the
    absolute path of this folder in **Add a project** and save. The daemon picks the list up by itself.
  - **Free plan**: one active project per machine. Add the folder the same way in
    https://codelux.ai/dashboard -> Projects, or switch the active project from the local dashboard
    (`http://localhost:PORT`). Free allows a few project changes per day.
  Give the user the exact absolute path to paste. Then repeat this step until the folder appears.
  Indexing starts automatically; a large project may take a little while.

## 4. Do the MCP tools answer?

Check that the `codelux` MCP server is connected (its tools appear as `mcp__plugin_codelux_codelux__*`,
e.g. `code_map`). Call `code_map` with `root` = the path from step 3. A map of the project (journal,
notes, index size) means the setup is complete.

Without MCP, the same check over HTTP:

```bash
curl -s -X POST http://localhost:PORT/mcp -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

A list of tools (`code_query`, `code_memory`, `file_read`, `file_edit`, ...) means the endpoint works.
If the daemon answers over HTTP but the MCP tools are not in this session, either the daemon was not
running when the session started (ask the user to run `/mcp` to reconnect, or to restart Claude Code), or
the plugin's `port` option does not match the port the daemon answers on (see "Different port").

## Different port

Codelux keeps its port in `codelux.cfg` (next to the binary, field `port`). If it is not 8766:

- set the plugin option: `/plugin` -> Codelux -> configure `port` (or `/config`), or reinstall with
  `claude plugin install codelux@codelux --config port=<port>`;
- restart Claude Code (or `/reload-plugins` then `/mcp`) so the MCP server reconnects on the new port.

## When everything works

Tell the user in one or two lines that Codelux is connected and which project is active, then follow the
`codelux-usage` skill: open work with `code_map` / `code_memory`, search with `code_query`, read with
`file_read`, and leave a checkpoint with `code_set` at the end. The full guide served by the daemon is at
`http://localhost:PORT/first-installation`.
