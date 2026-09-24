---
name: memory
description: Recall what was recently done in this project from Codelux memory - notes, edits, tool calls and the last checkpoints.
argument-hint: "[since: 30m|1h|2h|3h|today] [topic]"
disable-model-invocation: true
---

# /codelux:memory

Recall the recent work on this project from Codelux, so the user does not have to re-explain it.

Arguments: `$ARGUMENTS` (optional). A time window among `30m`, `1h`, `2h`, `3h`, `today` (default
`today`); anything else is a topic or search term.

`root` is the absolute path of the current project folder (see the `codelux-usage` skill). If the
codelux MCP tools are not available, or a tool says the folder is not indexed, use the `codelux-setup`
skill instead.

1. `code_map` with `root` - journal topics with their last checkpoint, open todos, recent notes.
2. `code_memory` with `root`, `since` = the window, and `query` = the topic if one was given.
3. If a topic was given, or one journal topic clearly matches the current work, `code_get` with that
   `topic` - last checkpoint plus the files changed since it was written.

Then answer with:

- a short table of what was done (when | what | files), newest first;
- the open items and the `next` step of the latest relevant checkpoint;
- any file changed after that checkpoint (the delta), flagged as "to re-check".

Do not paste the raw JSON. Do not start new work unless the user asks.
