#!/usr/bin/env bash
# Codelux plugin - SessionStart hook.
#
# Asks the local Codelux daemon for the project MEMORY (memory_get with no
# arguments over the MCP HTTP endpoint: newest memory in full, files changed
# since, and the current source of the places it names) and prints it on
# stdout, which the host adds to the session context. Then refreshes the
# Codelux block in AGENTS.md / CLAUDE.md (agents-md.sh).
#
# Contract: see _lib.sh. Never blocks, exit 0 always, 127.0.0.1 only.
# Usage: session-start.sh [--json]   (--json = Gemini CLI output format)

case "$1" in --json) OUTPUT_FORMAT=json ;; esac
. "$(dirname "$0")/_lib.sh"

resp="$(cx_call memory_get '' 5)" || exit 0
text="$(cx_text "$resp")" || exit 0

case "$text" in
  *"is not indexed"*)
    cx_emit SessionStart "Codelux is running on port $cx_port, but this folder ($cx_root) is not a registered Codelux project. If the user wants Codelux here, use the codelux-setup skill to register it."
    exit 0
    ;;
esac
[ -n "$text" ] || exit 0

max=12000
if [ "${#text}" -gt "$max" ]; then
  text="${text:0:$max}
[truncated - call memory_get with the topic for the whole memory]"
fi

cx_emit SessionStart "Codelux memory for $cx_root (newest memory; MCP server codelux, tools take root=\"$cx_root\"). WHERE lines point at the places to resume from.
$text"

# Keep the AGENTS.md / CLAUDE.md block current (silent, never fails the hook).
bash "$(dirname "$0")/agents-md.sh" "--port=$cx_port" </dev/null >/dev/null 2>&1 || true
exit 0
