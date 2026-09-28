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
if command -v cygpath >/dev/null 2>&1; then
  cx_root="$(cygpath -m "$cx_root" 2>/dev/null || printf '%s' "$cx_root")"
else
  cx_root="${cx_root//\\//}"
fi

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
cx_root_esc="$(cx_json_escape "$cx_root")"

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
  # Minimal JSON unescape: \\ -> \, \" -> ", \n -> newline, \t -> tab, \r dropped.
  text="${text//\\\\/$'\x01'}"
  text="${text//\\\"/\"}"
  text="${text//\\n/$'\n'}"
  text="${text//\\t/$'\t'}"
  text="${text//\\r/}"
  text="${text//\\\//\/}"
  text="${text//$'\x01'/\\}"
  printf '%s' "$text"
}

# cx_emit EVENT TEXT -> prints TEXT as context, in the format the host wants.
cx_emit() {
  if [ "${OUTPUT_FORMAT:-text}" = "json" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$1" "$(cx_json_escape "$2")"
  else
    printf '%s\n' "$2"
  fi
}
