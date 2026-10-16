#!/usr/bin/env bash
# Codelux plugin - AGENT BRIEF for a sub-agent that starts (SCH-idee C).
#
#   agent-brief.sh [--topic=T] [--files=a,b] [--text] [--agent=claude-code] [--port=N]
#
# Meant for the SubagentStart hook (wired by the hooks owner in hooks.json):
# reads the hook JSON from stdin (session_id, agent_id, agent_type), asks the
# daemon memory_get{kind:"brief", topic, query:<files>} with the hook's session
# fields, and prints the brief as the sub-agent's additional context:
#
#   default  {"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"…"}}
#   --text   the brief as plain text (Codex / any host that adds stdout as context)
#
# With no --topic / --files the daemon fills them in from the session: the
# live FILE CLAIMS of the sub-agent and of its parent (POST /claim, claims.go)
# and the topic of the last current memory. Current records only (superseded
# and retracted ones are left out). Budget ~5000 chars.
#
# Also sourceable: `. agent-brief.sh --lib` defines cx_agent_brief TOPIC FILES
# INPUT and returns without running (prints the brief text on stdout).
#
# Contract: see _lib.sh. No daemon, no curl, nothing relevant: exit 0 silently.

cx_brief_topic="" cx_brief_files="" cx_brief_text="" cx_brief_lib=""
cx_agent_type="claude-code"
for cx_a in "$@"; do
  case "$cx_a" in
    --topic=*) cx_brief_topic="${cx_a#--topic=}" ;;
    --files=*) cx_brief_files="${cx_a#--files=}" ;;
    --text) cx_brief_text=1 ;;
    --lib) cx_brief_lib=1 ;;
    --agent=*) cx_agent_type="${cx_a#--agent=}" ;;
  esac
done
case "$cx_agent_type" in ''|*[!a-z0-9._-]*) cx_agent_type="other" ;; esac
. "$(dirname "${BASH_SOURCE[0]:-$0}")/_lib.sh"

# cx_agent_brief TOPIC FILES INPUT [MAXCHARS] -> the brief text (empty + return 1
# when none). 35.1: the brief carries the CODE of the task (certified bodies,
# then pointers and the how-to block); MAXCHARS (memory_get limit) makes the
# daemon fit the whole text, code included, under the host's 10,000 chars.
cx_agent_brief() {
  local args resp text
  args=',"kind":"brief"'
  [ -n "$1" ] && args="$args"',"topic":"'"$(cx_json_escape "$1")"'"'
  [ -n "$2" ] && args="$args"',"query":"'"$(cx_json_escape "$2")"'"'
  case "${4:-}" in ''|*[!0-9]*) ;; *) args="$args"',"limit":'"$4" ;; esac
  args="$args$(cx_session_fields "$3" "$cx_agent_type")"
  # MemV2-delivery (SPEC-MEMORIA-V2 §5): SubagentStart waits at most 3 s. The
  # daemon answers within cx_budget_ms (2.2 s) with what is ready — a short
  # "=== AGENT BRIEF (Codelux: still being prepared…" with the claims, the
  # files and a memory_get{id:"late_…"} ticket for the whole brief — and
  # finishes it in the background (hook_budget.go).
  args="$args"',"cx_budget_ms":2200'
  resp="$(cx_call memory_get "$args" 2.6)" || return 1
  text="$(cx_text "$resp")" || return 1
  case "$text" in *"is not indexed"*|"") return 1 ;; esac
  # A daemon older than SCH-idee C answers kind:"brief" with the whole resume: not a brief.
  case "$text" in "=== AGENT BRIEF"*) ;; *) return 1 ;; esac
  cx_is_refusal "$text" && return 1
  printf '%s' "$text"
}

[ -n "$cx_brief_lib" ] && return 0 2>/dev/null

input="$(cat 2>/dev/null)"
text="$(cx_agent_brief "$cx_brief_topic" "$cx_brief_files" "$input" 9000)" || exit 0
case "$text" in *[![:space:]]*) ;; *) exit 0 ;; esac
if [ -n "$cx_brief_text" ]; then
  printf '%s\n' "$text"
else
  OUTPUT_FORMAT=json cx_emit SubagentStart "$text"
fi
exit 0
