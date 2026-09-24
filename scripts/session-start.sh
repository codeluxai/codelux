#!/usr/bin/env bash
# Codelux plugin - SessionStart hook.
#
# Asks the local Codelux daemon for today's memory of the current project
# (code_memory over the MCP HTTP endpoint) and prints it on stdout, which
# Claude Code adds to the session context.
#
# Contract: this hook must NEVER get in the way. No daemon, no curl, a folder
# that is not a registered project, a slow answer: it prints at most one short
# line and always exits 0. It only talks to 127.0.0.1 and sends nothing but
# the project path.
#
# Port: CLAUDE_PLUGIN_OPTION_PORT (the plugin's "port" option), then
# CODELUX_PORT, then the default 8766.

port="${CLAUDE_PLUGIN_OPTION_PORT:-${CODELUX_PORT:-8766}}"
case "$port" in ''|*[!0-9]*) port=8766 ;; esac

command -v curl >/dev/null 2>&1 || exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
# Git Bash on Windows: /e/proj -> E:/proj. The daemon accepts forward slashes.
if command -v cygpath >/dev/null 2>&1; then
  root="$(cygpath -m "$root" 2>/dev/null || printf '%s' "$root")"
else
  root="${root//\\//}"
fi

# JSON-escape the path (backslashes, then quotes).
esc="${root//\\/\\\\}"
esc="${esc//\"/\\\"}"

body='{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"code_memory","arguments":{"root":"'"$esc"'","since":"today"}}}'

resp="$(curl -s --connect-timeout 1 -m 5 -X POST "http://127.0.0.1:${port}/mcp" \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d "$body" 2>/dev/null)" || exit 0

case "$resp" in
  *'"result"'*) ;;
  *) exit 0 ;;
esac
case "$resp" in
  *'"isError":true'*) exit 0 ;;
esac

# Pull the tool's text out of {"result":{"content":[{"text":"...","type":"text"}]}}
text="${resp#*\"text\":\"}"
text="${text%\",\"type\"*}"
# Minimal JSON unescape: \\ -> \, \" -> ", \n -> newline.
text="${text//\\\\/$'\x01'}"
text="${text//\\\"/\"}"
text="${text//\\n/$'\n'}"
text="${text//$'\x01'/\\}"

case "$text" in
  *"is not indexed"*)
    printf 'Codelux is running on port %s, but this folder (%s) is not a registered Codelux project. If the user wants Codelux here, use the codelux-setup skill to register it.\n' "$port" "$root"
    exit 0
    ;;
esac

max=6000
if [ "${#text}" -gt "$max" ]; then
  text="${text:0:$max}
[truncated - call code_memory for the full timeline]"
fi

printf 'Codelux project memory for %s (code_memory, since=today; MCP server "codelux", tools take root="%s"):\n%s\n' "$root" "$root" "$text"
exit 0
