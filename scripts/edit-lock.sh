#!/usr/bin/env bash
# Codelux plugin - file lock around the agent's own Edit/Write.
#
#   edit-lock.sh acquire   (PreToolUse:  Edit|Write|MultiEdit|NotebookEdit)
#   edit-lock.sh release   (PostToolUse: same matcher)
#
# The agent edits with its native tools, so the lock (local per-file mutex
# between agents on this machine + the Team lock over NATS in a Team project)
# is taken here, unconditionally, instead of relying on the model to pick the
# right tool. The daemon's hidden `code_lock` tool does the work and answers
# one line: "ok ..." or "refused: ...".
#
# Contract: see _lib.sh. No daemon, no curl, no file path, a slow answer:
# exit 0 and the edit proceeds. The only thing that blocks an edit is an
# explicit "refused:" from the daemon on acquire (another agent or a teammate
# holds the file): exit 2, and the host shows our stderr to the model.

op="${1:-acquire}"
case "$op" in acquire|release|release-failed) ;; *) exit 0 ;; esac
# --agent=codex|gemini (default claude-code): whose session id the input carries.
cx_agent_type="claude-code"
for cx_a in "$@"; do
  case "$cx_a" in --agent=*) cx_agent_type="${cx_a#--agent=}" ;; esac
done
case "$cx_agent_type" in ''|*[!a-z0-9._-]*) cx_agent_type="other" ;; esac
# release-failed (PostToolUseFailure): free the file WITHOUT recording an edit.
failed=""
if [ "$op" = "release-failed" ]; then op="release"; failed=',"failed":true'; fi
. "$(dirname "$0")/_lib.sh"

input="$(cat 2>/dev/null)"
# tool_input.file_path (Edit, Write, MultiEdit, Gemini write_file/replace) or
# notebook_path (NotebookEdit), kept JSON-escaped: it goes straight back into JSON.
path="$(printf '%s' "$input" | grep -oE '"(file_path|notebook_path|path)"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -1 | sed -E 's/^"[a-z_]+"[[:space:]]*:[[:space:]]*"//; s/"$//')"
[ -n "$path" ] || exit 0

# Who is editing: every hook input carries the session id (Claude Code,
# Codex and the Claude-format hosts). Without it the daemon falls back to one
# shared "native-editor" name, and two sessions on this machine would NOT
# block each other: the semaphore between agents needs a distinct name per
# session. Acquire and release come from the same session, so they match.
sid="$(printf '%s' "$input" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"\]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
# 07/10/2026: the daemon turns cx_session into the session's Codelux code (the
# same name memory_set and code_edit record: agent_sessions.go). The legacy
# "agent" stays for a daemon older than that, which ignores cx_session.
agent=""
[ -n "$sid" ] && agent=',"agent":"session-'"${sid:0:12}"'","cx_session":"'"$sid"'","cx_agent":"'"$cx_agent_type"'"'
# 368: inside a Claude Code subagent the input carries the PARENT's session_id
# plus agent_id/agent_type (hooks docs, "common input fields"; captured stdin
# 13/10/2026: "agent_id":"a44d7691918bb18fd","agent_type":"worker-opus-medium").
# The daemon gives the subagent its own session code, child of the parent's.
[ -n "$agent" ] && agent="$agent$(cx_subagent_fields "$input")"

# MemV2-delivery (SPEC-MEMORIA-V2 §5): Pre/Post hooks wait at most 1.5 s. The
# daemon answers within cx_budget_ms (1.2 s) with what it has — "ok: lock
# pending" + a notice when the Team link is slow — and finishes the lock in
# the background (hook_budget.go: acquire and release of a file stay in order).
resp="$(cx_call code_lock ',"op":"'"$op"'","path":"'"$path"'","cx_budget_ms":1200'"$agent$failed" 1.5)"
rc=$?
if [ "$rc" -ne 0 ]; then
  # RT-fix B3 (giornata d2, 15/10/2026): a daemon that is THERE but does not answer
  # in 8 s (curl 28 = timeout; a team link dead in silence made the lock request
  # wait) used to let the edit through with no word: an edit without a lock that
  # looked like one with. The edit still proceeds (a hook must never wedge the
  # agent on a slow daemon), but the model is told, plainly, that no lock covers it.
  # No daemon at all (curl 7) stays silent, EXCEPT in a folder Codelux shares with a
  # team (its .codelux/settings.json carries share_mode): there an edit while the
  # daemon is down or restarting is an edit no team lock covers (bench f1: the only
  # overlap of the day, mem06 editing during its daemon's restart).
  if [ "$op" = "acquire" ]; then
    why=""
    # curl says 28 also when the CONNECT timed out (Windows retries a refused SYN):
    # only a daemon that accepts a connection and then does not answer is "slow".
    if [ "$rc" -eq 28 ] && ! curl -s -o /dev/null --connect-timeout 0.3 -m 0.4 "http://127.0.0.1:${cx_port}/api/auth/status" 2>/dev/null; then
      rc=7
    fi
    if [ "$rc" -eq 28 ]; then
      why="Codelux did not answer the lock request within 1.5 s (in a Team project the realtime link may be down)"
    elif grep -qs '"share_mode"' "$cx_root/.codelux/settings.json"; then
      why="Codelux is not running, and this folder is shared with a team"
    fi
    if [ -n "$why" ]; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' \
        "$(cx_json_escape "Codelux lock: NO LOCK was taken on this file - $why. A teammate may be editing it: check before overwriting, and prefer to retry the edit in a moment.")"
    fi
  fi
  exit 0
fi

[ "$op" = "acquire" ] || exit 0
text="$(cx_text "$resp")" || exit 0
case "$text" in
  "refused:"*)
    msg="${text#refused: }"
    msg="${msg#refused:}"
    printf 'Codelux lock: %s\n' "${msg%%$'\n'*}" >&2
    exit 2
    ;;
  *$'\n'"notice: "*)
    # MemV2-delivery: the lock was not taken in time (hook_budget.go); the
    # edit goes on and the model is told plainly
    note="${text#*$'\n'notice: }"
    note="${note%%$'\n'*}"
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' \
      "$(cx_json_escape "Codelux lock: $note")"
    ;;
  *$'\n'"claim: "*)
    # SCH-idee B: the file lies in another live agent's CLAIM (advisory). The
    # daemon adds the line once per (agent, claim) every 15 min; the edit goes
    # on (exit 0) and the model reads the warning as context.
    claim="${text#*$'\n'claim: }"
    claim="${claim%%$'\n'*}"
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' \
      "$(cx_json_escape "Codelux claim: $claim")"
    ;;
esac
exit 0
