#!/usr/bin/env bash
# Codelux plugin - Stop hook.
#
# Reminds the agent, once per stop, to leave its work in Codelux memory with
# memory_set if the task changed anything worth remembering. It never blocks
# (exit 0, no "decision") and does nothing when `stop_hook_active` is true,
# i.e. when the host is already running the agent because of a Stop hook, so
# the reminder cannot loop. Needs no daemon.
# Usage: session-stop.sh [--json]   (--json = Gemini CLI output format)

case "$1" in --json) OUTPUT_FORMAT=json ;; esac
input="$(cat 2>/dev/null)"
case "$input" in
  *'"stop_hook_active"'*[[:space:]]*true*|*'"stop_hook_active":true'*) exit 0 ;;
esac

msg="Codelux: if this task changed anything worth remembering, close it with memory_set (summary, next, traps, decisions, facts, codemaps) before stopping."
if [ "${OUTPUT_FORMAT:-text}" = "json" ]; then
  printf '{"systemMessage":"%s"}\n' "$msg"
else
  printf '%s\n' "$msg"
fi
exit 0
