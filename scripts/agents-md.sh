#!/usr/bin/env bash
# Codelux plugin - keeps the Codelux block in AGENTS.md (and CLAUDE.md) current.
#
# Asks the daemon memory_get {brief_block: true} (a block of at most 60 lines:
# status, next, traps, recent decisions) and writes it between
#   <!-- codelux:start -->  and  <!-- codelux:end -->
# in <root>/AGENTS.md, creating the file with only the block when absent, and
# in <root>/CLAUDE.md when that file already exists (never created). Text
# outside the markers is never touched.
#
# Called from session-start.sh after the memory; also usable standalone.
# Contract: see _lib.sh. No daemon, empty answer, folder not a registered
# project ("is not indexed"): files untouched, exit 0.

. "$(dirname "$0")/_lib.sh"

resp="$(cx_call memory_get ',"brief_block":true' 5)" || exit 0
block="$(cx_text "$resp")" || exit 0
case "$block" in *"is not indexed"*) exit 0 ;; esac
case "$block" in *[![:space:]]*) ;; *) exit 0 ;; esac
# Only a real memory block goes into AGENTS.md / CLAUDE.md. Anything else the
# daemon may answer (terms not accepted, licence offline, an error) is NOT
# project memory: files untouched (28/09/2026: a terms notice ended up in
# AGENTS.md during the plugin test).
case "$block" in *"## Codelux project memory"*) ;; *) exit 0 ;; esac
# The daemon may or may not include the markers itself: normalise to bare text.
block="${block#*<!-- codelux:start -->}"
block="${block%<!-- codelux:end -->*}"
block="$(printf '%s' "$block" | sed -e '1{/^[[:space:]]*$/d;}' -e '${/^[[:space:]]*$/d;}')"

# Local filesystem path (Git Bash wants /e/... for reading and writing).
fsroot="$cx_root"
if command -v cygpath >/dev/null 2>&1; then
  fsroot="$(cygpath -u "$cx_root" 2>/dev/null || printf '%s' "$cx_root")"
fi

# write_block FILE CREATE(0|1)
write_block() {
  local f="$1" create="$2" tmp
  if [ ! -f "$f" ]; then
    [ "$create" = "1" ] || return 0
    printf '<!-- codelux:start -->\n%s\n<!-- codelux:end -->\n' "$block" > "$f" 2>/dev/null
    return 0
  fi
  tmp="$f.codelux.tmp.$$"
  if grep -q '<!-- codelux:start -->' "$f" 2>/dev/null && grep -q '<!-- codelux:end -->' "$f" 2>/dev/null; then
    # Replace what lies between the markers (first start .. first end after it).
    CX_BLOCK="$block" awk '
      BEGIN { inblk = 0; done = 0; blk = ENVIRON["CX_BLOCK"] }
      !done && !inblk && index($0, "<!-- codelux:start -->") { print; print blk; inblk = 1; next }
      inblk && index($0, "<!-- codelux:end -->") { inblk = 0; done = 1; print; next }
      inblk { next }
      { print }
    ' "$f" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }
  else
    # No block yet: append one at the end, after a blank line.
    { cat "$f"; [ -n "$(tail -c1 "$f")" ] && printf '\n'; printf '\n<!-- codelux:start -->\n%s\n<!-- codelux:end -->\n' "$block"; } > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }
  fi
  if cmp -s "$tmp" "$f"; then rm -f "$tmp"; else mv -f "$tmp" "$f" 2>/dev/null || rm -f "$tmp"; fi
  return 0
}

write_block "$fsroot/AGENTS.md" 1
write_block "$fsroot/CLAUDE.md" 0
exit 0
