#!/usr/bin/env bash
# Codelux plugin - memory writes are not lost while the daemon is down (SCH, 15/10/2026).
#
#   outbox.sh queue   PostToolUseFailure on the codelux memory_set / notes_set
#                     MCP tools: when the call failed because the daemon does
#                     not answer, the hook input (tool name + the agent's own
#                     arguments) is saved in <project>/.codelux/outbox/ and the
#                     agent is told it is queued — not to repeat it, not to
#                     lose it. The daemon sends it by itself when it is back
#                     (outbox.go: 5 s after start, then every minute).
#   outbox.sh flush   SessionStart: asks a running daemon to send the queue now.
#
# A failure while the daemon DOES answer (bad arguments, a refusal) is the
# agent's to read: nothing is queued. Contract: see _lib.sh (exit 0 always,
# 127.0.0.1 only). The CLI queues its own writes the same way (`codelux outbox`).
# Usage: outbox.sh queue|flush [--port=N]

cx_mode="${1:-}"
OUTPUT_FORMAT=json
. "$(dirname "$0")/_lib.sh"
command -v curl >/dev/null 2>&1 || exit 0

cx_daemon_up() {
  curl -s --connect-timeout 1 -m 3 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${cx_port}/mcp" 2>/dev/null | grep -q '^[24]'
}

case "$cx_mode" in
  flush)
    cat >/dev/null 2>&1
    dir="$cx_root/.codelux/outbox"
    ls "$dir"/*.json >/dev/null 2>&1 || exit 0
    curl -s --connect-timeout 1 -m 8 -X POST -G "http://127.0.0.1:${cx_port}/api/outbox/flush" \
      --data-urlencode "root=$cx_root" >/dev/null 2>&1
    exit 0
    ;;
  queue) ;;
  *) exit 0 ;;
esac

input="$(cat 2>/dev/null)"
case "$input" in *'"tool_name"'*memory_set*|*'"tool_name"'*notes_set*) ;; *) exit 0 ;; esac
# the daemon answered: a real error, the agent reads it
cx_daemon_up && exit 0
[ -d "$cx_root/.codelux" ] || exit 0
dir="$cx_root/.codelux/outbox"
mkdir -p "$dir" 2>/dev/null || exit 0
name="$(date +%s%N 2>/dev/null || date +%s)-$$"
printf '%s' "$input" >"$dir/$name.hook.json.tmp" 2>/dev/null && mv -f "$dir/$name.hook.json.tmp" "$dir/$name.hook.json" 2>/dev/null || exit 0
cx_emit PostToolUseFailure "Codelux: the daemon is not reachable on 127.0.0.1:${cx_port}, so this write was QUEUED in .codelux/outbox/$name.hook.json — it is not lost and is sent by itself when the daemon is back. Do not repeat it; carry on (the CLI also queues: codelux outbox)."
exit 0
