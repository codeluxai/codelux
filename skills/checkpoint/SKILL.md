---
name: checkpoint
description: Close the session by writing one Codelux memory (memory_set) - summary, status, next step, open items, traps, decisions, facts, codemaps - so the next session or another agent starts where this one stops.
argument-hint: "[topic, e.g. Auth.Login]"
disable-model-invocation: true
---

# /codelux:checkpoint

Leave the work of this session in Codelux memory with ONE `memory_set` call.

Topic: `$ARGUMENTS` if given (dotted, e.g. `Billing.Invoices`). Otherwise reuse the topic of the
session-start memory if it fits, else name the area worked on in 1-3 dotted words.

`root` is the absolute path of the current project folder. If the codelux MCP tools are not available,
use the `codelux-setup` skill instead.

1. Review this session: files changed, decisions taken, what is finished, what is not, what surprised
   you. If useful, `memory_get` with `since` = the session length to see what Codelux recorded.
2. `memory_set` with `root`, `topic` and:
   - `summary` (required, 1-3 lines), `status`, `next` (the first thing to do next time);
   - `open[]`, `traps[]` (what bit you and would bite again);
   - `decisions[{what, why}]` for each non-obvious choice not yet recorded;
   - `facts[{text, file, line}]` for durable things learned about the code (re-verified on change);
   - `codemaps[{label, files, symbols}]` for the area touched, when it is not already mapped;
   - `todos[]` for what a human must do.
   Name the relevant file paths in the text: Codelux freezes their hash, so the next `memory_get`
   shows what changed after this memory.

Answer with a short table (item | content): topic, status, next, and the counts of decisions, facts,
codemaps written. Keep it short.
