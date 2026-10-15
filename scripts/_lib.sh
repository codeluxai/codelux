#!/usr/bin/env bash
# Codelux plugin - shared helpers for the hook scripts (sourced, not run).
#
# Contract of every hook script that sources this file: it must NEVER get in
# the way. No daemon, no curl, a folder that is not a registered project, a
# slow answer: exit 0 silently (the only exception is an explicit "refused:"
# from code_lock on acquire, handled in edit-lock.sh). It only talks to
# 127.0.0.1 and sends nothing but the project path and, for prompt-memory.sh,
# the prompt text.
#
# Port: CLAUDE_PLUGIN_OPTION_PORT (the plugin's "port" option), then
# CODELUX_PORT, then the default 8766.
#
# Output format: OUTPUT_FORMAT=text (default: plain stdout, what Claude Code and
# Codex add as context) or OUTPUT_FORMAT=json (Gemini CLI: one JSON object with
# hookSpecificOutput.additionalContext). Scripts accept "--json" as first arg.

# The hooks pass the plugin's configured port as an argument (--port=N, exec
# form in hooks.json with ${user_config.port}): Claude Code does not export
# CLAUDE_PLUGIN_OPTION_PORT when the option is left at its default, and a
# hook that silently fell back to 8766 would talk to another Codelux
# (found 28/09/2026 loading the plugin with --plugin-dir).
cx_port_arg=""
for cx_a in "$@"; do
  case "$cx_a" in --port=*) cx_port_arg="${cx_a#--port=}" ;; esac
done
cx_port="${cx_port_arg:-${CLAUDE_PLUGIN_OPTION_PORT:-${CODELUX_PORT:-8766}}}"
case "$cx_port" in ''|*[!0-9]*) cx_port=8766 ;; esac

# Project root as the daemon wants it: absolute, forward slashes.
# Git Bash on Windows: /e/proj -> E:/proj.
cx_root="${CLAUDE_PROJECT_DIR:-${CODEX_PROJECT_DIR:-${GEMINI_PROJECT_DIR:-$PWD}}}"
# 377: no cygpath for the common forms: the hooks now run on EVERY tool call
# and a fork costs tens to hundreds of ms on Git Bash. E:\x and E:/x need only
# the slashes, /e/x (Git Bash) becomes E:/x; anything else (/tmp, /c/Users
# mounts…) still goes through cygpath when there is one.
cx_root="${cx_root//\\//}"
case "$cx_root" in
  [A-Za-z]:/*|[A-Za-z]:) ;;
  /[A-Za-z]/*|/[A-Za-z])
    if [ -n "${MSYSTEM:-}" ] || [ "${OSTYPE:-}" = "msys" ] || [ "${OSTYPE:-}" = "cygwin" ]; then
      cx_d="${cx_root:1:1}"
      cx_root="${cx_d^^}:${cx_root:2}"
      [ "${#cx_root}" -eq 2 ] && cx_root="$cx_root/"
    fi ;;
  /*)
    if command -v cygpath >/dev/null 2>&1; then
      cx_root="$(cygpath -m "$cx_root" 2>/dev/null || printf '%s' "$cx_root")"
    fi ;;
esac

# JSON-escape a string (backslashes, quotes, newlines, tabs, control chars).
cx_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}
# 377: no $(...) subshell (a process on Git Bash) on every hook
# (cx_root has no backslash left: they became slashes above; a quote is escaped)
cx_root_esc="${cx_root//\"/\\\"}"

# cx_call NAME ARGS_JSON_FRAGMENT TIMEOUT -> raw JSON-RPC response on stdout.
# ARGS_JSON_FRAGMENT is appended after "root":"..." (start it with a comma).
# Returns 1 when curl is missing or the daemon does not answer.
cx_call() {
  command -v curl >/dev/null 2>&1 || return 1
  local body='{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"'"$1"'","arguments":{"root":"'"$cx_root_esc"'"'"$2"'}}}'
  curl -s --connect-timeout 1 -m "${3:-5}" -X POST "http://127.0.0.1:${cx_port}/mcp" \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -d "$body" 2>/dev/null
}

# cx_hook_curl: POST /hook (377) as a plain command line, so "${cx_hook_curl[@]}"
# costs ONE process (a function in $(...) or & would add a subshell). The hook
# input is the body, read by curl from its own stdin (the caller decides what
# that is: the host's stdin, or a here-string): this shell reads nothing.
# The caller adds -m, X-Codelux-Event, X-Codelux-Agent-Type; -w prints a last
# line with the HTTP code (000 = no daemon, 404 = a daemon older than 377).
cx_hook_curl=(curl -s --connect-timeout 0.5 -X POST "http://127.0.0.1:${cx_port}/hook"
  -H 'Content-Type: application/json' -H "X-Codelux-Root: ${cx_root}" -H "X-Codelux-TS: ${EPOCHREALTIME:-}"
  --data-binary @- -w '\n%{http_code}')

# cx_session_fields INPUT [AGENT_TYPE] -> ',"cx_session":"<id>","cx_agent":"<type>"'
# (empty when the hook input carries no session_id). The daemon turns it into
# the session's Codelux code (agent_sessions.go): memory_get then records which
# code points this session received, and delivers to it the targeted notices
# "code point X was changed by cc-..." (memory_proof_live.go).
cx_session_fields() {
  local sid
  sid="$(printf '%s' "$1" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"\]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
  [ -n "$sid" ] || return 0
  printf ',"cx_session":"%s","cx_agent":"%s"' "$sid" "${2:-claude-code}"
  cx_subagent_fields "$1"
}

# cx_subagent_fields INPUT -> ',"cx_subagent":"<agent_id>","cx_subagent_type":"<agent_type>"'
# (368) — empty unless the hook fires inside a subagent: Claude Code then sends
# the PARENT's session_id plus agent_id and agent_type. agent_type alone (a
# session started with --agent) is not a subagent and adds nothing.
cx_subagent_fields() {
  local id typ
  id="$(printf '%s' "$1" | grep -oE '"agent_id"[[:space:]]*:[[:space:]]*"[^"\]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
  case "$id" in ''|*[!A-Za-z0-9._-]*) return 0 ;; esac
  typ="$(printf '%s' "$1" | grep -oE '"agent_type"[[:space:]]*:[[:space:]]*"[^"\]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
  case "$typ" in *[!A-Za-z0-9._:-]*) typ="" ;; esac
  printf ',"cx_subagent":"%s","cx_subagent_type":"%s"' "$id" "$typ"
}

# cx_text RESP -> the tool's text, unescaped, on stdout. Empty (and return 1)
# when the response is not a successful result with a text block.
cx_text() {
  local resp="$1" text
  case "$resp" in *'"result"'*) ;; *) return 1 ;; esac
  case "$resp" in *'"isError":true'*|*'"isError": true'*) return 1 ;; esac
  resp="${resp//\"text\": \"/\"text\":\"}"
  case "$resp" in *'"text":"'*) ;; *) return 1 ;; esac
  text="${resp#*\"text\":\"}"
  text="${text%\",\"type\"*}"
  text="${text%\"\}*}"
  # Minimal JSON unescape: \\ -> \, \" -> ", \n -> newline, \t -> tab, \r dropped,
  # and the HTML escapes Go's encoder writes (< > &): the
  # memory carries code now (CODE POINTS), and `Option<PathBuf>` is
  # not what the file says.
  text="${text//\\\\/$'\x01'}"
  text="${text//\\u003c/<}"
  text="${text//\\u003e/>}"
  text="${text//\\u0026/\&}" # \& : bash 5.2 patsub_replacement reads a bare & as "the match"
  text="${text//\\\"/\"}"
  text="${text//\\n/$'\n'}"
  text="${text//\\t/$'\t'}"
  text="${text//\\r/}"
  text="${text//\\\//\/}"
  text="${text//$'\x01'/\\}"
  # 370: a build replaced by a newer download is not an expired licence. A daemon older than 370
  # words it "license inactive — credentials_stale. Renew at …": say what it really is, and what to do.
  case "$text" in
    *"license inactive — credentials_stale"*|*"license inactive — binary_mismatch"*)
      text="⛔ Codelux: This build has been replaced by a newer one: close this one and start the latest you downloaded." ;;
  esac
  printf '%s' "$text"
}

# cx_is_refusal TEXT -> 0 when the daemon refused the call (licence, terms, offline): the text is a
# notice for the user, not project memory, and must not be presented as such.
cx_is_refusal() {
  case "$1" in "⛔"*) return 0 ;; esac
  return 1
}

# cx_emit EVENT TEXT -> prints TEXT as context, in the format the host wants.
cx_emit() {
  if [ "${OUTPUT_FORMAT:-text}" = "json" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$1" "$(cx_json_escape "$2")"
  else
    printf '%s\n' "$2"
  fi
}
