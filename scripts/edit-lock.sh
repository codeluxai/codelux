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
agent=""
[ -n "$sid" ] && agent=',"agent":"session-'"${sid:0:12}"'"'

resp="$(cx_call code_lock ',"op":"'"$op"'","path":"'"$path"'"'"$agent$failed" 8)" || exit 0

[ "$op" = "acquire" ] || exit 0
text="$(cx_text "$resp")" || exit 0
case "$text" in
  "refused:"*)
    msg="${text#refused: }"
    msg="${msg#refused:}"
    printf 'Codelux lock: %s\n' "${msg%%$'\n'*}" >&2
    exit 2
    ;;
esac
exit 0
