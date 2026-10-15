#!/usr/bin/env bash
# Codelux plugin - UserPromptSubmit hook.
#
# Reads the hook JSON from stdin, takes the user's `prompt` and asks the daemon
# memory_get {query: prompt, brief: true}: a local search over codemaps, facts
# and decisions, verified against the current code. If something relevant comes
# back it is printed on stdout (the host adds it as context); if nothing comes
# back NOTHING is printed, so a miss costs zero tokens.
#
# Contract: see _lib.sh. Never blocks; 3 s total (curl -m 2); exit 0 always.
# Usage: prompt-memory.sh [--json]   (--json = Gemini CLI output format)

cx_agent_type="claude-code"
for cx_a in "$@"; do
  case "$cx_a" in
    --json) OUTPUT_FORMAT=json ;;
    --agent=*) cx_agent_type="${cx_a#--agent=}" ;;
  esac
done
case "$cx_agent_type" in ''|*[!a-z0-9._-]*) cx_agent_type="other" ;; esac
. "$(dirname "$0")/_lib.sh"

input="$(cat 2>/dev/null)"
# `prompt`, kept JSON-escaped as the host sent it: it goes straight back into JSON.
prompt="$(printf '%s' "$input" | grep -oE '"prompt"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -1 | sed -E 's/^"prompt"[[:space:]]*:[[:space:]]*"//; s/"$//')"
[ -n "$prompt" ] || exit 0

# Cap the query; if the cut lands inside an escape sequence, drop the fragment.
max=4000
if [ "${#prompt}" -gt "$max" ]; then
  prompt="${prompt:0:$max}"
  prompt="$(printf '%s' "$prompt" | sed -E 's/\\u[0-9a-fA-F]{0,3}$//; s/(^|[^\\])(\\\\)*\\$/\1\2/')"
fi

# With the session id the answer also carries this session's pending notices
# (a code point it received was changed by another agent through Codelux).
resp="$(cx_call memory_get ',"query":"'"$prompt"'","brief":true'"$(cx_session_fields "$input" "$cx_agent_type")" 2)" || exit 0
text="$(cx_text "$resp")" || exit 0
case "$text" in *"is not indexed"*) exit 0 ;; esac
# Whitespace-only counts as empty.
case "$text" in *[![:space:]]*) ;; *) exit 0 ;; esac
# 370: a refusal (e.g. this build was replaced by a newer one) is a notice, not "relevant memory".
if cx_is_refusal "$text"; then
  cx_emit UserPromptSubmit "$text"
  exit 0
fi

cx_emit UserPromptSubmit "Codelux: relevant project memory for this request (verified against the current code):
$text"
exit 0
