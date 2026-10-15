#!/usr/bin/env bash
# Codelux plugin - the `codelux` MCP server as a stdio process (363, 13/10/2026).
#
# WHY. The plugin used to declare the server as `"type":"http"` on
# http://localhost:<port>/mcp. Claude Code connects an http MCP server ONCE, at
# session start: when the daemon is not running at that moment (machine just
# booted, daemon restarting, licence being renewed), the server is marked
# failed with ECONNREFUSED and stays failed for the whole session — even after
# the daemon is back and the REST API answers (schematicPRO, 12-13/10/2026: a
# whole day without the MCP tools).
#
# WHAT. This script is the MCP server Claude Code starts (stdio: one JSON-RPC
# message per line). It forwards every message to the daemon's POST /mcp on
# 127.0.0.1 (never `localhost`: on Windows it resolves to ::1 first) and prints
# the answer. It never dies because the daemon is away:
#   - initialize while the daemon is down: answered here (tools.listChanged),
#     and the original initialize is replayed to the daemon when it returns;
#   - tools/list while down: an empty list; tools/call while down: a tool
#     error that says how to start the daemon;
#   - every 10 s of silence while down, and before each message, the daemon is
#     probed; when it answers again the proxy re-initializes and sends
#     notifications/tools/list_changed so the client fetches the tools again.
#
# Port: --port=N (the plugin's "port" option), then CLAUDE_PLUGIN_OPTION_PORT,
# CODELUX_PORT, default 8766 — the same chain as the hooks (_lib.sh).
# Needs only bash and curl (both ship with Git for Windows).
#
# NOT THE DEFAULT ANY MORE (15/10/2026). plugin/.mcp.json is back to "type":"http":
# a stdio server is spawned with a bare `bash`, and on Windows with WSL installed
# that is C:\Windows\System32\bash.exe (WSL), which cannot open the E:\... path:
# the server closed at once (CONNECTION_CLOSED) from 13/10 to 15/10. Keep this
# script for macOS/Linux or for an explicit Git Bash path in a user .mcp.json.

cx_port_arg=""
for cx_a in "$@"; do
  case "$cx_a" in --port=*) cx_port_arg="${cx_a#--port=}" ;; esac
done
cx_port="${cx_port_arg:-${CLAUDE_PLUGIN_OPTION_PORT:-${CODELUX_PORT:-8766}}}"
case "$cx_port" in ''|*[!0-9]*) cx_port=8766 ;; esac
cx_url="http://127.0.0.1:${cx_port}/mcp"

cx_tmp="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/codelux-mcp-$$")"
mkdir -p "$cx_tmp" 2>/dev/null
trap 'rm -rf "$cx_tmp"' EXIT

cx_sid=""         # Mcp-Session-Id the daemon handed out
cx_init=""        # the client's initialize message (replayed after an outage)
cx_down=0         # 1 = the daemon did not answer the last attempt
cx_local_init=0   # 1 = initialize was answered here, the daemon has not seen it

cx_log() { printf 'codelux-mcp: %s\n' "$*" >&2; }

# cx_post MESSAGE -> sets cx_code (HTTP status, 000 = no connection) and
# cx_body (response body, newline-free). Returns curl's exit code.
cx_post() {
  local hdr="$cx_tmp/h" out="$cx_tmp/b" rc
  : >"$hdr"; : >"$out"
  if [ -n "$cx_sid" ]; then
    printf '%s' "$1" | curl -sS --connect-timeout 2 -m 600 -X POST "$cx_url" \
      -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
      -H "Mcp-Session-Id: $cx_sid" -D "$hdr" -o "$out" -w '%{http_code}' --data-binary @- >"$cx_tmp/c" 2>/dev/null
  else
    printf '%s' "$1" | curl -sS --connect-timeout 2 -m 600 -X POST "$cx_url" \
      -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
      -D "$hdr" -o "$out" -w '%{http_code}' --data-binary @- >"$cx_tmp/c" 2>/dev/null
  fi
  rc=$?
  cx_code="$(cat "$cx_tmp/c" 2>/dev/null)"
  [ -n "$cx_code" ] || cx_code=000
  cx_body="$(tr -d '\r\n' <"$out" 2>/dev/null)"
  local s
  s="$(grep -i '^mcp-session-id:' "$hdr" 2>/dev/null | head -1 | sed -E 's/^[^:]*:[[:space:]]*//' | tr -d '\r\n')"
  [ -n "$s" ] && cx_sid="$s"
  return $rc
}

# cx_alive: does the daemon answer GET /mcp?
cx_alive() {
  curl -s --connect-timeout 1 -m 3 -o /dev/null -w '%{http_code}' "$cx_url" 2>/dev/null | grep -q '^2'
}

# cx_id MESSAGE -> the JSON-RPC id (raw JSON: number or "string"), "" for a
# notification. The SDK serializes {method, params, jsonrpc, id}: the id is
# the LAST key; other shapes are handled too.
cx_id() {
  local m="$1" re1='"id"[[:space:]]*:[[:space:]]*(-?[0-9]+|"[^"]*")[[:space:]]*\}[[:space:]]*$'
  local re2='^\{[[:space:]]*"jsonrpc"[[:space:]]*:[[:space:]]*"2\.0"[[:space:]]*,[[:space:]]*"id"[[:space:]]*:[[:space:]]*(-?[0-9]+|"[^"]*")'
  local re3='^\{[[:space:]]*"id"[[:space:]]*:[[:space:]]*(-?[0-9]+|"[^"]*")'
  if [[ "$m" =~ $re1 ]] || [[ "$m" =~ $re2 ]] || [[ "$m" =~ $re3 ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

cx_method() {
  local re='"method"[[:space:]]*:[[:space:]]*"([^"]+)"'
  [[ "$1" =~ $re ]] && printf '%s' "${BASH_REMATCH[1]}"
}

cx_protocol() {
  local re='"protocolVersion"[[:space:]]*:[[:space:]]*"([^"]+)"'
  if [[ "$1" =~ $re ]]; then printf '%s' "${BASH_REMATCH[1]}"; else printf '2025-03-26'; fi
}

cx_say() { printf '%s\n' "$1"; }

cx_down_text="Codelux daemon not reachable on 127.0.0.1:${cx_port}. Start it (codelux start, or open the Codelux app); the tools come back by themselves when it answers."

# cx_answer_down ID METHOD MESSAGE: what the client gets while the daemon is away.
cx_answer_down() {
  local id="$1" method="$2"
  [ -n "$id" ] || return 0 # notification: nothing to answer
  case "$method" in
    initialize)
      cx_say '{"jsonrpc":"2.0","id":'"$id"',"result":{"protocolVersion":"'"$(cx_protocol "$3")"'","capabilities":{"tools":{"listChanged":true}},"serverInfo":{"name":"codelux","version":"proxy"},"instructions":"'"$cx_down_text"'"}}' ;;
    tools/list)
      cx_say '{"jsonrpc":"2.0","id":'"$id"',"result":{"tools":[]}}' ;;
    tools/call)
      cx_say '{"jsonrpc":"2.0","id":'"$id"',"result":{"content":[{"type":"text","text":"'"$cx_down_text"'"}],"isError":true}}' ;;
    ping)
      cx_say '{"jsonrpc":"2.0","id":'"$id"',"result":{}}' ;;
    resources/list)
      cx_say '{"jsonrpc":"2.0","id":'"$id"',"result":{"resources":[]}}' ;;
    prompts/list)
      cx_say '{"jsonrpc":"2.0","id":'"$id"',"result":{"prompts":[]}}' ;;
    *)
      cx_say '{"jsonrpc":"2.0","id":'"$id"',"error":{"code":-32000,"message":"'"$cx_down_text"'"}}' ;;
  esac
}

# cx_reattach: the daemon is back — replay initialize, then tell the client the
# tool list changed. Returns 1 when the daemon is still away.
cx_reattach() {
  [ -n "$cx_init" ] || { cx_down=0; return 0; }
  cx_sid=""
  cx_post "$cx_init" || return 1
  case "$cx_code" in 2*) ;; *) return 1 ;; esac
  cx_post '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null 2>&1
  cx_down=0
  if [ "$cx_local_init" = 1 ] || [ "${cx_was_listed:-0}" = 1 ]; then
    cx_say '{"jsonrpc":"2.0","method":"notifications/tools/list_changed"}'
  fi
  cx_local_init=0
  cx_log "daemon back on 127.0.0.1:${cx_port}: re-attached"
  return 0
}

cx_partial=""
while :; do
  cx_line=""
  IFS= read -r -t 10 cx_line
  rc=$?
  if [ $rc -gt 128 ]; then
    # read timed out: idle (a partial line is kept for the next read) — probe
    # the daemon when it was away
    cx_partial="$cx_partial$cx_line"
    if [ "$cx_down" = 1 ] && cx_alive; then
      cx_reattach
    fi
    continue
  fi
  cx_line="$cx_partial$cx_line"
  cx_partial=""
  if [ $rc -ne 0 ] && [ -z "$cx_line" ]; then
    exit 0 # stdin closed: the client is gone
  fi
  cx_line="${cx_line%$'\r'}"
  [ -n "$cx_line" ] || continue
  cx_m="$(cx_method "$cx_line")"
  cx_i="$(cx_id "$cx_line")"

  if [ "$cx_m" = "initialize" ]; then
    cx_init="$cx_line"
  elif [ "$cx_down" = 1 ] && cx_alive; then
    cx_reattach
  fi
  [ "$cx_m" = "tools/list" ] && cx_was_listed=1

  if cx_post "$cx_line" && [ "$cx_code" != 000 ]; then
    cx_down=0
    case "$cx_code" in
      202|204) continue ;; # a notification: no message back
    esac
    if [ -n "$cx_body" ] && [ "${cx_body#\{}" != "$cx_body" ]; then
      if [ "$cx_m" = "initialize" ]; then
        # the proxy announces list changes (after an outage), so it says so
        cx_body="${cx_body/\"tools\":\{\}/\"tools\":\{\"listChanged\":true\}}"
      fi
      cx_say "$cx_body"
    elif [ -n "$cx_i" ]; then
      # not a JSON-RPC answer (HTTP error text): turn it into one
      msg="$(printf '%s' "${cx_body:-HTTP $cx_code}" | tr -d '"\\' | cut -c1-300)"
      cx_say '{"jsonrpc":"2.0","id":'"$cx_i"',"error":{"code":-32603,"message":"codelux daemon answered HTTP '"$cx_code"': '"$msg"'"}}'
    fi
    continue
  fi

  # no connection
  [ "$cx_down" = 1 ] || cx_log "daemon not reachable on 127.0.0.1:${cx_port} — answering locally until it is back"
  cx_down=1
  [ "$cx_m" = "initialize" ] && cx_local_init=1
  cx_answer_down "$cx_i" "$cx_m" "$cx_line"
done
