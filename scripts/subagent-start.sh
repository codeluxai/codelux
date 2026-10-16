#!/usr/bin/env bash
# Codelux plugin - the project memory for SUBAGENTS (SCH, 15/10/2026).
#
# SessionStart and UserPromptSubmit fire in the main conversation only: a
# subagent started with the Agent/Task tool began with no Codelux memory at
# all (schematicPRO, 15/10/2026: 8 agents in a day re-read what the memory
# already held). Claude Code fires SubagentStart when a subagent starts; its
# input carries session_id (the parent's), agent_id and agent_type, and its
# hookSpecificOutput.additionalContext is added to the SUBAGENT's context.
# The task text is not in that input, so:
#
#   subagent-start.sh remember   PreToolUse on Agent|Task (the parent): the
#                                tool_input's prompt and subagent_type are
#                                queued for this session (one line each, in a
#                                temp file; nothing reaches the daemon)
#   subagent-start.sh start      SubagentStart: takes the oldest queued task of
#                                the same agent_type (else the oldest) and
#                                prints, as additionalContext, the AGENT BRIEF
#                                for that task (agent-brief.sh,
#                                memory_get{kind:"brief", query: task}); with a
#                                daemon older than the brief: the newest memory
#                                + the memory relevant to the task. Always as
#                                the subagent's own session (agent_id).
#
# Contract: see _lib.sh. Never blocks, exit 0 always, 127.0.0.1 only. Codex
# and Gemini CLI have no subagent-start event (hooks/OTHER-AGENTS.md).
# Usage: subagent-start.sh remember|start [--port=N]

cx_mode="${1:-}"
OUTPUT_FORMAT=json
. "$(dirname "$0")/_lib.sh"

input="$(cat 2>/dev/null)"
cx_t0="${EPOCHREALTIME:-0}"; cx_t0="${cx_t0/./}"; cx_t0="${cx_t0/,/}" # microseconds (bash 5), 0 = unknown
cx_field() { # the string value of "NAME":"..." (no escaped quotes inside)
  printf '%s' "$input" | grep -oE '"'"$1"'"[[:space:]]*:[[:space:]]*"[^"\]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/'
}
sid="$(cx_field session_id)"
case "$sid" in ''|*[!A-Za-z0-9._-]*) exit 0 ;; esac
cx_q="${TMPDIR:-${TEMP:-/tmp}}/codelux-subagent-${sid}.q"

case "$cx_mode" in
  remember)
    # the prompt, still JSON-escaped as the host sent it: it goes back into JSON
    task="$(printf '%s' "$input" | grep -oE '"prompt"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -1 | sed -E 's/^"prompt"[[:space:]]*:[[:space:]]*"//; s/"$//')"
    [ -n "$task" ] || exit 0
    # TL-fix 16/10: 4000, not 2000 - the topics a task names (Flow.Asm3D.*,
    # Codelux.Report.*) go into the brief, and they may sit past the first lines
    max=4000
    if [ "${#task}" -gt "$max" ]; then
      task="${task:0:$max}"
      task="$(printf '%s' "$task" | sed -E 's/\\u[0-9a-fA-F]{0,3}$//; s/(^|[^\\])(\\\\)*\\$/\1\2/')"
    fi
    typ="$(cx_field subagent_type)"
    case "$typ" in *[!A-Za-z0-9._:-]*) typ="" ;; esac
    printf '%s\t%s\n' "${typ:-general-purpose}" "$task" >>"$cx_q" 2>/dev/null
    exit 0
    ;;
  start) ;;
  *) exit 0 ;;
esac

# SubagentStart: the subagent's task (FIFO, same type first)
typ="$(cx_field agent_type)"
task=""
if [ -f "$cx_q" ]; then
  line="$(grep -m1 "^${typ}	" "$cx_q" 2>/dev/null)"
  [ -n "$line" ] || line="$(head -1 "$cx_q" 2>/dev/null)"
  if [ -n "$line" ]; then
    task="${line#*	}"
    # drop exactly that line (the first occurrence)
    awk -v l="$line" 'done || $0 != l { print; next } { done = 1 }' "$cx_q" >"$cx_q.tmp" 2>/dev/null && mv -f "$cx_q.tmp" "$cx_q" 2>/dev/null
    [ -s "$cx_q" ] || rm -f "$cx_q" 2>/dev/null
  fi
fi

# The AGENT BRIEF (SCH-idee C, agent-brief.sh: memory_get{kind:"brief"}) is
# the subagent's memory: flow, rules, decisions in force, traps, files, claims,
# current records only. The task text is its query. A daemon older than the
# brief answers nothing here, and the newest memory below is used instead.
cx_agent_type=claude-code
. "$(dirname "$0")/agent-brief.sh" --lib "--port=$cx_port"
# the queued task is still JSON-escaped; cx_agent_brief escapes it again
task_plain="${task//\\n/ }"
task_plain="${task_plain//\\t/ }"
task_plain="${task_plain//\\\"/\"}"
task_plain="${task_plain//\\\\/\\}"
if brief="$(cx_agent_brief "" "$task_plain" "$input" 9000)" && [ -n "$brief" ]; then
  # TL-fix 16/10: the brief carries the topics the task names; 35.1: and the
  # CODE of the task (certified bodies + pointers + how-to), fitted by the
  # daemon to limit=9000 chars (the host files away hook output > 10,000)
  max=9300
  if [ "${#brief}" -gt "$max" ]; then
    note="
[truncated - memory_get{kind:\"brief\"} for the whole brief]"
    brief="${brief:0:$((max - ${#note}))}$note"
  fi
  cx_emit SubagentStart "$brief"
  exit 0
fi

# A daemon older than the brief (no "=== AGENT BRIEF"): the newest memory +
# the memory relevant to the task, inside what is left of the 3 s budget
# (MemV2-delivery: the brief call took up to 2.6 s; no daemon = nothing to wait for).
cx_now="${EPOCHREALTIME:-0}"; cx_now="${cx_now/./}"; cx_now="${cx_now/,/}"
if [ -n "${cx_t0:-}" ] && [ "$cx_t0" != "0" ] && [ "$cx_now" != "0" ] && [ $(( (cx_now - cx_t0) / 1000 )) -gt 1200 ]; then
  exit 0
fi
fields="$(cx_session_fields "$input" claude-code)"
resp="$(cx_call memory_get "$fields" 0.8)" || exit 0
text="$(cx_text "$resp")" || exit 0
case "$text" in *"is not indexed"*) exit 0 ;; esac
if cx_is_refusal "$text"; then
  cx_emit SubagentStart "$text"
  exit 0
fi
[ -n "$text" ] || exit 0

rel=""
if [ -n "$task" ]; then
  r2="$(cx_call memory_get ',"query":"'"$task"'","brief":true'"$fields" 0.7)" && rel="$(cx_text "$r2")"
  case "$rel" in *[![:space:]]*) ;; *) rel="" ;; esac
  cx_is_refusal "$rel" && rel=""
fi

# a subagent's budget is smaller than the main session's: 6,000 chars in all
max=6000
out="Codelux memory for $cx_root (you are a subagent: this is the project memory the main session received; MCP server codelux, tools take root=\"$cx_root\"). CODE POINTS marked CERTIFIED are the current code verified by hash: do not re-read them. Close your work with ONE memory_set (summary required)."
if [ -n "$rel" ]; then
  out="$out

Relevant to your task:
$rel"
fi
out="$out

$text"
if [ "${#out}" -gt "$max" ]; then
  note="
[truncated - call memory_get with the topic for the whole memory]"
  out="${out:0:$((max - ${#note}))}$note"
fi
cx_emit SubagentStart "$out"
exit 0
