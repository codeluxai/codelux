---
name: memory
description: Recall what was recently done in this project from Codelux memory - memories, notes, edits, events - for a period or a topic.
argument-hint: "[since: 30m|1h|2h|3h|today] [topic or search words]"
disable-model-invocation: true
---

# /codelux:memory

Recall the recent work on this project from Codelux, so the user does not have to re-explain it.

Arguments: `$ARGUMENTS` (optional). A time window among `30m`, `1h`, `2h`, `3h`, `today` (default
`today`); anything else is a topic (dotted) or search words.

`root` is the absolute path of the current project folder (see the `codelux-usage` skill). If the
codelux MCP tools are not available, or a tool says the folder is not indexed, use the `codelux-setup`
skill instead.

1. `memory_get` with `root`, `since` = the window, plus `topic` or `query` if given - the matching
   memories in full and the files changed since each one.
2. `memory_get` with `events: true` and the same `since` - the timeline (memories, notes, edits,
   commits, locks, team events) in order.
3. `notes_get` with `root` - open todos and forms waiting for an answer.

Then answer with:

- a short table of what was done (when | what | files), newest first;
- the open items and the `next` step of the latest relevant memory;
- any file changed after that memory (the delta), flagged as "to re-check".

Do not paste the raw JSON. Do not start new work unless the user asks.
