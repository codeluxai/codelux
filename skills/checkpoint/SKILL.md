---
name: checkpoint
description: Close the session by writing a Codelux checkpoint (what was done, what is open, traps, next step) to the project's continuation journal, plus facts and decisions worth keeping.
argument-hint: "[topic, e.g. Auth.Login]"
disable-model-invocation: true
---

# /codelux:checkpoint

Leave the work of this session in Codelux so the next session - or another agent or teammate -
starts exactly where this one stops.

Topic: `$ARGUMENTS` if given (dotted, e.g. `Billing.Invoices`). Otherwise pick one: reuse the closest
existing topic from `code_map` if it fits, else name the area worked on in 1-3 dotted words.

`root` is the absolute path of the current project folder. If the codelux MCP tools are not available,
use the `codelux-setup` skill instead.

1. Review this session: files changed, decisions taken, what is finished, what is not, what surprised you.
   If useful, `code_memory` with `root` and `since` = the session length to see the edits Codelux recorded.
2. For each non-obvious decision not yet recorded: `code_note` with `root`, `kind` = `decision`,
   `title`, `content` = the choice and the reason.
3. For each durable thing learned about the code: `code_note` with `kind` = `fact`, `title`, `content`
   and `anchors` = `[{file, line}]` pointing at the code it describes.
4. Write the checkpoint: `code_set` with `root`, `topic`, `type` = `checkpoint` and
   `payload` = `{"status": "...", "done": [...], "open": [...], "traps": [...], "next": "..."}`.
   Mention the relevant file paths in the payload text: Codelux freezes their hash, so the next
   `code_get` shows what changed after this checkpoint.

Answer with a short table (item | content) of what you saved: topic, status, next step, and the
number of notes/facts written. Keep it short.
