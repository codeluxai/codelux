#!/usr/bin/env bash
# Codelux plugin - SessionStart hook.
#
# Asks the local Codelux daemon for the project MEMORY (memory_get with no
# arguments over the MCP HTTP endpoint: newest memory in full, files changed
# since; Memoria v2 saves no code location, the index answers where code is)
# and prints it on stdout, which the host adds to the session context. Then
# refreshes the Codelux block in AGENTS.md / CLAUDE.md (agents-md.sh). Says in
# one line when the plugin is doubled or stale (the account copy from the
# Claude Directory, a local install whose folder is gone).
#
# Contract: see _lib.sh. Never blocks, exit 0 always, 127.0.0.1 only.
# Usage: session-start.sh [--json]   (--json = Gemini CLI output format)

cx_agent_type="claude-code"
for cx_a in "$@"; do
  case "$cx_a" in
    --json) OUTPUT_FORMAT=json ;;
    --agent=*) cx_agent_type="${cx_a#--agent=}" ;;
  esac
done
case "$cx_agent_type" in ''|*[!a-z0-9._-]*) cx_agent_type="other" ;; esac
. "$(dirname "$0")/_lib.sh"

# The session id (hook input) tells the daemon WHO receives these code points:
# when another agent changes one through Codelux, this session alone is told.
input="$(cat 2>/dev/null)"

# How the session starts (plan step 191, daemon session_start.go): Claude
# Code's SessionStart input carries `source` (startup | resume | clear |
# compact | fork), `model`, and on resume/fork `seconds_since_last_response`
# and `prompt_cache_likely_expired`. The daemon predicts the prompt-cache state
# from them and answers accordingly: the full memory for a new session, only
# what changed for a conversation resumed while its cache is hot, code points
# + last conclusions after a long pause or a compaction.
cx_field() { # cx_field NAME -> the string value of "NAME":"..." in the input
  printf '%s' "$input" | grep -oE '"'"$1"'"[[:space:]]*:[[:space:]]*"[^"\]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/'
}
cx_raw() { # cx_raw NAME -> a bare number/boolean value of "NAME":...
  printf '%s' "$input" | grep -oE '"'"$1"'"[[:space:]]*:[[:space:]]*[-0-9.eE+a-z]+' | head -1 | sed -E 's/.*:[[:space:]]*//'
}
# 375: the agent's identity on REST and the CLI. A hook cannot set variables in
# the host's process, but Claude Code gives SessionStart a file
# (CLAUDE_ENV_FILE) whose exports it applies to every Bash command of the
# conversation: the codelux CLI then sends CODELUX_SESSION / CODELUX_PROVIDER
# as X-Codelux-Session / X-Codelux-Provider by itself, and a curl can pass
# them (session=$CODELUX_SESSION). A state file in the project would be shared
# by every conversation open on it, so it is not used. Inside a subagent the
# variables are still the parent's: the daemon tells the subagent apart by the
# name its Bash hook declared (agent_unify.go).
cx_env_sid="$(cx_field session_id)"
if [ -n "${CLAUDE_ENV_FILE:-}" ] && [ -n "$cx_env_sid" ]; then
  case "$cx_env_sid" in
    *[!A-Za-z0-9._-]*) ;;
    *) printf 'export CODELUX_SESSION=%s\nexport CODELUX_PROVIDER=%s\n' "$cx_env_sid" "$cx_agent_type" >>"$CLAUDE_ENV_FILE" 2>/dev/null || true ;;
  esac
fi

start=""
src="$(cx_field source)"
case "$src" in ''|*[!a-z_-]*) src="" ;; esac
if [ -n "$src" ]; then
  start=',"start_source":"'"$src"'"'
  mdl="$(cx_field model)"
  case "$mdl" in ''|*[!][A-Za-z0-9._:/@-]*) ;; *) start="$start"',"start_model":"'"$mdl"'"' ;; esac
  secs="$(cx_raw seconds_since_last_response)"
  case "$secs" in ''|*[!0-9.]*) ;; *) start="$start"',"start_seconds_since":'"$secs" ;; esac
  case "$(cx_raw prompt_cache_likely_expired)" in
    true) start="$start"',"start_cache_expired":true' ;;
    false) start="$start"',"start_cache_expired":false' ;;
  esac
  # API key / cloud provider instead of a subscription: 5-minute cache entries
  if [ -n "${ANTHROPIC_API_KEY:-}" ] || [ -n "${CLAUDE_CODE_USE_BEDROCK:-}" ] || [ -n "${CLAUDE_CODE_USE_VERTEX:-}" ]; then
    start="$start"',"start_api":true'
  fi
fi

# MemV2-delivery (SPEC-MEMORIA-V2 §5): SessionStart waits at most 10 s (the
# hook's timeout). The daemon answers within cx_budget_ms (8 s) with what it
# has and finishes in the background (hook_budget.go: memory_get{id:"late_…"}
# then returns the whole text). cx_plugin = this plugin's version: a plugin
# older than the daemon gets one line saying so (hooks_status.go).
cx_plugin_ver=""
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
  cx_plugin_ver="$(grep -m1 -oE '"version"[[:space:]]*:[[:space:]]*"[0-9][0-9A-Za-z.+-]*"' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | sed -E 's/.*"([^"]*)"$/\1/')"
fi
plug=',"cx_budget_ms":8000'
[ -n "$cx_plugin_ver" ] && plug="$plug"',"cx_plugin":"'"$cx_plugin_ver"'"'

# The duplicate (15/10/2026): the desktop app loads the account's "codelux"
# plugin from the Claude Directory in place of the local one when both exist,
# and the account copy 3.5.1 has a SessionStart hook only. Seen from here
# (this copy runs, so it is the one to keep):
#   - an account copy of the plugin in the desktop app's folder, of another
#     version: in desktop sessions it wins and these hooks do not run;
#   - a local install whose folder is gone (installed_plugins.json points at
#     nothing) when its marketplace is not a folder read in place (a
#     directory marketplace is read where it is, the cache does not matter).
# One line, with the fix. Claude Code only.
cx_dup=""
cx_bs='\'
if [ "$cx_agent_type" = "claude-code" ]; then
  case "${CLAUDE_PLUGIN_ROOT:-}" in
    *"/rpm/plugin_"*|*"${cx_bs}rpm${cx_bs}plugin_"*|*"/plugins/synced/"*|*"${cx_bs}plugins${cx_bs}synced${cx_bs}"*) ;;
    *)
      for cx_f in "${APPDATA:-/nonexistent}"/Claude/local-agent-mode-sessions/*/*/rpm/plugin_*/.claude-plugin/plugin.json; do
        [ -f "$cx_f" ] || continue
        grep -q '"name"[[:space:]]*:[[:space:]]*"codelux"' "$cx_f" 2>/dev/null || continue
        cx_av="$(grep -m1 -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$cx_f" | sed -E 's/.*"([^"]*)"$/\1/')"
        if [ -n "$cx_plugin_ver" ] && [ "$cx_av" != "$cx_plugin_ver" ]; then
          cx_dup="the Claude desktop app also has the account plugin \"Codelux\" $cx_av from the Directory: in desktop sessions it replaces this one ($cx_plugin_ver) and its hooks do not run. Turn it off in the desktop app (Plugins) or update it to $cx_plugin_ver."
        fi
        break
      done ;;
  esac
  cx_inst="${HOME:-}/.claude/plugins/installed_plugins.json"
  cx_mk="${HOME:-}/.claude/plugins/known_marketplaces.json"
  if [ -z "$cx_dup" ] && [ -f "$cx_inst" ]; then
    cx_ip="$(grep -A3 '"codelux@codelux"' "$cx_inst" 2>/dev/null | grep -m1 -oE '"installPath"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]*)"$/\1/')"
    cx_ip="${cx_ip//"$cx_bs$cx_bs"//}"
    cx_ml="$(grep -A8 '"codelux"[[:space:]]*:' "$cx_mk" 2>/dev/null | grep -m1 -oE '"installLocation"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]*)"$/\1/')"
    cx_ml="${cx_ml//"$cx_bs$cx_bs"//}"
    if [ -n "$cx_ip" ] && [ ! -d "$cx_ip" ] && { [ -z "$cx_ml" ] || [ ! -d "$cx_ml" ] || ! grep -A8 '"codelux"[[:space:]]*:' "$cx_mk" 2>/dev/null | grep -q '"source"[[:space:]]*:[[:space:]]*"directory"'; }; then
      cx_dup="the local plugin codelux@codelux is installed but its folder is gone ($cx_ip): run \`claude plugin install codelux@codelux\`, then /reload-plugins."
    fi
  fi
fi
cx_head=""
[ -n "$cx_dup" ] && cx_head="⚠ Codelux plugin: $cx_dup
"

resp="$(cx_call memory_get "$(cx_session_fields "$input" "$cx_agent_type")$start$plug" 9)" || {
  [ -n "$cx_head" ] && cx_emit SessionStart "${cx_head%$'\n'}"
  exit 0
}
text="$(cx_text "$resp")" || exit 0

case "$text" in
  *"is not indexed"*)
    cx_emit SessionStart "${cx_head}Codelux is running on port $cx_port, but this folder ($cx_root) is not a registered Codelux project. If the user wants Codelux here, use the codelux-setup skill to register it."
    exit 0
    ;;
esac
[ -n "$text" ] || exit 0
# 370: a refusal (licence, terms, a build replaced by a newer one) is a notice for the user, not memory.
if cx_is_refusal "$text"; then
  cx_emit SessionStart "$text"
  exit 0
fi

# Claude Code puts hook output longer than 10,000 characters in a file and
# shows the agent only a preview, so the agent spends a turn reading it (bench
# 07/10/2026: 10,299 chars -> one extra Read). Stay under that with the header
# and the truncation note included (and the plugin line, when there is one).
max=$((9300 - ${#cx_head}))
if [ "${#text}" -gt "$max" ]; then
  # the note counts inside the cap (live test 08/10/2026: 9,300 + the note was 9,357)
  note="
[truncated - call memory_get with the topic for the whole memory]"
  text="${text:0:$((max - ${#note}))}$note"
fi

# A daemon that knows the start (step 191) writes its own first lines: the
# predicted cache state, then the instructions (a plugin older than the daemon:
# a "⚠ Codelux:" line first, hooks_status.go). An older daemon does not.
case "$text" in
  "Codelux: "*|"⚠ Codelux"*)
    cx_emit SessionStart "$cx_head$text"
    bash "$(dirname "$0")/agents-md.sh" "--port=$cx_port" </dev/null >/dev/null 2>&1 || true
    exit 0
    ;;
esac
cx_emit SessionStart "${cx_head}Codelux memory for $cx_root (newest memory; MCP server codelux, tools take root=\"$cx_root\"). Resume from next; where the code is NOW comes from the index (code_query, code_context), never from a saved path.
$text"

# Keep the AGENTS.md / CLAUDE.md block current (silent, never fails the hook).
bash "$(dirname "$0")/agents-md.sh" "--port=$cx_port" </dev/null >/dev/null 2>&1 || true
exit 0
