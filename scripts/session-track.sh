#!/usr/bin/env bash
# Codelux plugin - session tracker (07/10/2026, plan steps 2 and 3).
#
#   session-track.sh EVENT [--agent=claude-code|codex|gemini] [--port=N]
#
#   EVENT  start          SessionStart (every source: startup, resume, clear, compact)
#          prompt         UserPromptSubmit / BeforeAgent
#          pre            PreToolUse / BeforeTool on EVERY tool (377): the start
#                         of the call for the procedure trace; on Read the file
#                         read (path + hash + range, never the text); on
#                         mcp__*codelux* the announcement that binds the MCP
#                         connection to this session; on the shell tools the
#                         agent name a Codelux command carries (375)
#          post           PostToolUse / AfterTool on EVERY tool (377): the row of
#                         the trace (essential arguments, response SIZE, duration)
#          post-fail      PostToolUseFailure (377): the same, outcome error
#          stop           Stop / AfterAgent (read the new usage from the transcript)
#          subagent-stop  SubagentStop
#          end            SessionEnd (closes the task, writes the usage report)
#
# It forwards the host's hook input (stdin, one JSON object) to the daemon:
# pre/post/post-fail on POST /hook (raw body, curl reads the stdin itself),
# the others to the hidden `session_hook` tool on /mcp. The daemon keeps ids,
# times, counters, paths, hashes and sizes; never a file's text, an output or
# an edit's content; it reads token NUMBERS from the transcript.
#
# Prints nothing, except ONE rare sober hint (377, at most 2 a turn, off in
# the project's settings): on pre as the host's additionalContext JSON, on
# prompt as plain context. The rest of the conversation is untouched, so the
# prompt cache is too (plan 07/10 §4). Contract of _lib.sh: no daemon, no curl,
# an unregistered folder, a slow answer -> exit 0.

ev="${1:-}"

# SessionEnd: detach FIRST, before any other work.
#
# Claude Code gives ALL SessionEnd hooks together 1.5 s
# (CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS; the "timeout" of hooks.json does
# not extend it) and with `claude -p` the process exits right after. The old
# order - source _lib.sh (cygpath and command substitutions), read stdin with
# cat, then fork the call into the background - cost ~0.9 s on an idle
# Windows machine (Git Bash: every fork is tens to hundreds of ms), so on a
# loaded one the hook was killed before the fork ("Hook cancelled", bench
# 07/10/2026 P4 B day 1, commit 3197eea notwithstanding) and the end never
# reached the daemon. Now: read the input with the read builtin (no fork),
# start ONE background bash that does everything else, return. ~0.1 s on top
# of bash's own start. The daemon also closes a session whose end never came
# (agentTrackSweep, after 2 h of silence), so this is the fast path, not the
# only one.
if [ "$ev" = "end" ] && [ "${CX_TRACK_DETACHED:-}" != "1" ]; then
  cx_in=""
  IFS= read -r -d '' cx_in 2>/dev/null
  # the hook input of SessionEnd is a few hundred bytes; an environment
  # variable is the cheapest way to hand it over (Windows caps one at 32 KiB)
  if [ "${#cx_in}" -le 16384 ]; then
    CX_TRACK_DETACHED=1 CX_TRACK_INPUT="$cx_in" bash "$0" "$@" </dev/null >/dev/null 2>&1 &
  fi
  exit 0
fi

[ $# -gt 0 ] && shift
agent="claude-code"
for cx_a in "$@"; do
  case "$cx_a" in
    --agent=*) agent="${cx_a#--agent=}" ;;
    --json) OUTPUT_FORMAT=json ;;
  esac
done
case "$ev" in start|prompt|pre|post|post-fail|stop|subagent-stop|end) ;; *) exit 0 ;; esac
case "$agent" in ''|*[!a-z0-9._-]*) agent="other" ;; esac
# 377: ${0%/*}, not $(dirname): one process less on every tool call
# the folder of this script, with / or a backslash (C:\x\scripts\s.sh from a
# hand-made config); bash 5.3 does not match an escaped backslash in a
# pattern, hence the variable
cx_bs='\'
cx_dir="${0%/*}"
cx_d2="${0%"$cx_bs"*}"
[ "$cx_dir" = "$0" ] && cx_dir="$cx_d2"
[ "$cx_d2" != "$0" ] && [ "${#cx_d2}" -gt "${#cx_dir}" ] && cx_dir="$cx_d2"
[ "$cx_dir" = "$0" ] && cx_dir="."
. "$cx_dir/_lib.sh"

# 377: PostToolUse / PostToolUseFailure / AfterTool on EVERY tool. The input
# carries the whole tool_response (a Read's file, a command's output): this
# shell does not read it. ONE curl in the background takes the host's stdin as
# the body (fd 3: a background job's stdin would otherwise be /dev/null) and
# the script returns at once. The daemon measures the response (bytes, lines)
# and keeps none of it. No daemon, or one older than 377: curl fails, nothing
# happens.
if [ "$ev" = "post" ] || [ "$ev" = "post-fail" ]; then
  command -v curl >/dev/null 2>&1 || exit 0
  exec 3<&0
  "${cx_hook_curl[@]}" -m 10 -H "X-Codelux-Event: $ev" -H "X-Codelux-Agent-Type: $agent" <&3 >/dev/null 2>&1 &
  exit 0
fi

# 377: PreToolUse / BeforeTool on EVERY tool goes to POST /hook: the daemon
# notes the start (the duration is Pre→Post), does what pre always did (the MCP
# announcement, 368; the agent's name in a shell command, 375; the file read)
# and, rarely, answers one hint for the agent ("you already read X at 10:59",
# "X is an indexed symbol: code_context X"). curl reads the host's stdin
# itself: no `cat`, no `read` (one process less, and a Write of a big file
# costs nothing here). Foreground on purpose: the announcement must reach the
# daemon before the MCP call and the hint before the tool runs; bounded at
# 1.5 s, the daemon answers in milliseconds. A daemon older than 377 has no
# /hook (404): nothing happens, as with no daemon.
if [ "$ev" = "pre" ]; then
  command -v curl >/dev/null 2>&1 || exit 0
  resp="$("${cx_hook_curl[@]}" -m 1.5 -H "X-Codelux-Event: pre" -H "X-Codelux-Agent-Type: $agent")"
  code="${resp##*$'\n'}"
  body="${resp%$'\n'*}"
  [ "$code" = "200" ] || exit 0
  case "$body" in
    *$'\n'"hint: "*)
      hint="${body#*$'\n'hint: }"
      hint="${hint%%$'\n'*}"
      # Codex: PreToolUse output fields not verified (OTHER-AGENTS.md): no hint there.
      case "$agent" in
        claude-code) OUTPUT_FORMAT=json cx_emit PreToolUse "$hint" ;;
        gemini) OUTPUT_FORMAT=json cx_emit BeforeTool "$hint" ;;
      esac
      ;;
  esac
  exit 0
fi

if [ "${CX_TRACK_DETACHED:-}" = "1" ]; then
  input="${CX_TRACK_INPUT:-}"          # the detached SessionEnd (see the top)
else
  input="$(cat 2>/dev/null)"
fi
# trim surrounding whitespace; it must be one JSON object
input="${input#"${input%%[![:space:]]*}"}"
input="${input%"${input##*[![:space:]]}"}"
case "$input" in '{'*'}') ;; *) exit 0 ;; esac
# a huge tool_input (a whole file in a Write) is not worth the trip
[ "${#input}" -le 262144 ] || exit 0

t=2
# end: already detached at the top, nobody waits for this process any more,
# so give the daemon time to ingest the transcript and write the report.
[ "$ev" = "end" ] && t=8
resp="$(cx_call session_hook ',"event":"'"$ev"'","agent_type":"'"$agent"'","hook":'"$input" "$t" 2>/dev/null)"
# 377: UserPromptSubmit / BeforeAgent may carry ONE hint about the turn that
# just ended (big files read whole). Printed as context; nothing otherwise.
if [ "$ev" = "prompt" ]; then
  text="$(cx_text "$resp")" || exit 0
  case "$text" in
    *$'\n'"hint: "*)
      hint="${text#*$'\n'hint: }"
      hint="${hint%%$'\n'*}"
      if [ "$agent" = "gemini" ]; then cx_emit BeforeAgent "$hint"; else cx_emit UserPromptSubmit "$hint"; fi
      ;;
  esac
fi
exit 0
