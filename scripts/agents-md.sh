#!/usr/bin/env bash
# Codelux plugin - keeps the Codelux block in AGENTS.md (and CLAUDE.md).
#
# Asks the daemon memory_get {brief_block: true}: since 07/10/2026 (cache-first
# decision D3) a STABLE block of fixed instructions - no date, no time, no
# status, no counter, nothing that changes with the project memory - and writes
# it between
#   <!-- codelux:start -->  and  <!-- codelux:end -->
# in <root>/AGENTS.md, creating the file with only the block when absent, and
# in <root>/CLAUDE.md when that file already exists (never created). Text
# outside the markers is never touched.
#
# Why stable: AGENTS.md / CLAUDE.md are the first context an agent host reads,
# inside the prompt prefix the provider caches; a byte that changes there
# invalidates the cache of every new session. The variable state (last update,
# status, next step, traps, changed files) reaches the agent as a MESSAGE
# instead: session-start.sh (SessionStart additionalContext) and
# prompt-memory.sh (UserPromptSubmit). The file is rewritten only when the
# block text itself changes (a new Codelux release): cmp -s below leaves an
# identical file untouched, so the usual run changes nothing on disk.
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
# An older daemon still answers the old, VARIABLE block (date, status, next):
# writing it would put changing text in the cached prefix. Leave the files.
case "$block" in *"Last update "*) exit 0 ;; esac
# The daemon may or may not include the markers itself: normalise to bare text.
block="${block#*<!-- codelux:start -->}"
block="${block%<!-- codelux:end -->*}"
block="$(printf '%s' "$block" | sed -e '1{/^[[:space:]]*$/d;}' -e '${/^[[:space:]]*$/d;}')"

# Local filesystem path (Git Bash wants /e/... for reading and writing).
fsroot="$cx_root"
if command -v cygpath >/dev/null 2>&1; then
  fsroot="$(cygpath -u "$cx_root" 2>/dev/null || printf '%s' "$cx_root")"
fi

# Everything below is bash builtins plus one awk, no grep/cat/tail/cmp, and every
# write goes through a temp file + mv. Why: Claude Code cancels a SessionStart
# hook that runs too long by killing the processes it spawned. A killed grep
# returns non-zero, which read as "no @AGENTS.md import here" and appended the
# Codelux block to a CLAUDE.md that only contains `@AGENTS.md`, changing the
# cached prefix of every later session (bench 07/10/2026). With builtins there
# is no child to be killed on its own, and a kill at any point leaves the old
# file intact (the worst case is an orphan *.codelux.tmp.* file).

# read_file FILE -> sets $cx_content to the exact bytes of FILE (trailing
# newlines included; $(<f) would strip them). Returns 1 when unreadable.
read_file() {
  cx_content=""
  [ -r "$1" ] || return 1
  IFS= read -r -d '' cx_content < "$1" || :
  return 0
}

# put_file TMP DEST -> atomic replace of DEST by TMP; TMP removed on failure.
put_file() {
  mv -f "$1" "$2" 2>/dev/null || rm -f "$1" 2>/dev/null
  return 0
}

# write_block FILE CREATE(0|1)
write_block() {
  local f="$1" create="$2" tmp old new
  tmp="$f.codelux.tmp.$$"
  if [ ! -f "$f" ]; then
    [ "$create" = "1" ] || return 0
    printf '<!-- codelux:start -->\n%s\n<!-- codelux:end -->\n' "$block" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }
    put_file "$tmp" "$f"
    return 0
  fi
  read_file "$f" || return 0
  old="$cx_content"
  if [[ "$old" == *'<!-- codelux:start -->'* && "$old" == *'<!-- codelux:end -->'* ]]; then
    # Replace what lies between the markers (first start .. first end after it).
    CX_BLOCK="$block" awk '
      BEGIN { inblk = 0; done = 0; blk = ENVIRON["CX_BLOCK"] }
      !done && !inblk && index($0, "<!-- codelux:start -->") { print; print blk; inblk = 1; next }
      inblk && index($0, "<!-- codelux:end -->") { inblk = 0; done = 1; print; next }
      inblk { next }
      { print }
    ' "$f" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }
    read_file "$tmp" || { rm -f "$tmp"; return 0; }
    new="$cx_content"
  else
    # No block yet: append one at the end, after a blank line.
    new="$old"
    if [ -n "$new" ] && [ "${new: -1}" != $'\n' ]; then new+=$'\n'; fi
    new+=$'\n<!-- codelux:start -->\n'"$block"$'\n<!-- codelux:end -->\n'
    printf '%s' "$new" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }
  fi
  if [ "$new" = "$old" ]; then rm -f "$tmp"; else put_file "$tmp" "$f"; fi
  return 0
}

write_block "$fsroot/AGENTS.md" 1
# Claude Code reads CLAUDE.md, not AGENTS.md (bench 07/10/2026: in a repo with
# only AGENTS.md the agent never saw the block). With no CLAUDE.md, create one
# that only imports AGENTS.md - the form the Claude Code docs suggest for repos
# that already use AGENTS.md - so the block is not duplicated. An existing
# CLAUDE.md gets the block appended as before, unless it already imports
# AGENTS.md (the block would then be read twice): such a file is never touched.
claude_md="$fsroot/CLAUDE.md"
if [ ! -f "$claude_md" ]; then
  tmp="$claude_md.codelux.tmp.$$"
  if printf '@AGENTS.md\n' > "$tmp" 2>/dev/null; then put_file "$tmp" "$claude_md"; else rm -f "$tmp"; fi
elif read_file "$claude_md"; then
  has_import=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    if [[ "$line" =~ ^[[:space:]]*@(\./)?AGENTS\.md[[:space:]]*$ ]]; then has_import=1; break; fi
  done <<< "$cx_content"
  [ "$has_import" = "1" ] || write_block "$claude_md" 0
fi
exit 0
