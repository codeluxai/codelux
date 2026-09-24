---
name: codelux-usage
description: How to work on a Codelux-indexed project with the codelux MCP tools - recover memory before exploring, search by symbol instead of reading whole files, read files compressed, write through file_edit, record decisions and leave a checkpoint at the end. Use whenever the codelux MCP tools are available and you start, continue or close a coding task in this project.
---

# Working with Codelux

Codelux has already indexed this project and remembers what earlier sessions (and other agents or
teammates) did. Use it instead of re-exploring from scratch: it costs fewer tokens and the user does
not have to re-explain.

## The one parameter that matters: `root`

Every project tool takes `root` = the **absolute path of the project folder** (e.g. `E:\work\app` or
`/home/me/app`). Never the project id, never its name. If you do not know it, `GET
http://localhost:8766/api/projects` lists the registered projects: take the `path` field. If a tool
answers that the folder "is not indexed", use the `codelux-setup` skill.

## Order of work

| Moment | Tool | Key parameters |
|---|---|---|
| Opening a task | `code_map` | `root` - one call: journal topics, codemaps, open todos, facts, recent notes |
| What happened recently | `code_memory` | `root`, `since` = `30m`/`1h`/`2h`/`3h`/`today`, optional `query`, `kind` = `all`/`edits`/`tools`/`notes`, `detail` = `full` for patches |
| Picking up a topic | `code_get` | `root`, `topic` (dotted, e.g. `Auth.Login`; prefix match) - last checkpoint + files changed since |
| What is already known | `code_brief` | `root`, `query` = the task in plain words - facts (FRESH/STALE), symbols, recent edits, open todos |
| Finding code | `code_query` | `root`, `query` - symbols by keyword/intent; `&` AND, `\|` OR, `!` NOT |
| Exact text / regex | `code_grep` | `root`, `pattern`, optional `glob` |
| Callers and callees | `code_tree` | `root`, `name`, `up`, `down` |
| Map of one file | `code_outline` | `root`, `file` |
| One symbol + deps | `code_context` | `root`, `name` |
| Reading files | `file_read` | `root`, `file` (relative) or `files:[...]` (max 12); `from_line`/`to_line` for exact raw text |
| Changing files | `file_edit` | `root`, `agent` (required), `file`, `edits:[{old,new,expect?}]` or `symbol`+`content` or `content`+`base_hash` |
| Recording a decision | `code_note` | `root`, `kind` = `decision`/`todo`/`intent`/`summary`/`fact`, `title`, `content`; `fact` needs `anchors:[{file,line}]` |
| Closing the task | `code_set` | `root`, `topic`, `type` = `checkpoint`, `payload` = `{status, done:[...], open:[...], traps:[...], next}` |

## Rules

1. **Memory first.** At the start of a task call `code_map`, then `code_memory` or `code_brief` with the
   task. Resume from the last checkpoint's `next` instead of re-planning.
2. **Query, don't crawl.** Find code with `code_query` / `code_grep` / `code_tree` before opening files.
   Do not list directories and read whole files blind.
3. **Read compressed.** `file_read` returns a lossless compressed view with original `[line]` numbers,
   50-70 % fewer tokens than a raw read. Its first line is `hash: <h>`: keep it.
4. **One write path.** On an indexed project prefer `file_edit` to your own Edit/Write: it backs the file up
   first, reindexes immediately and refuses a stale write. Pass the `hash` you read as `base_hash`.
   `agent` is required: pick a short codename (e.g. `claude_4821`) and reuse it all session. A refusal
   means nothing was written: `file_read` again and retry. Read the answer: a changed signature comes
   back with the call sites to fix.
5. **Record the why.** When you make a non-obvious choice, `code_note kind="decision"` with the reason.
   What you learned about the code goes in `code_note kind="fact"` with anchors, so it is re-verified
   when the code changes.
6. **Close with a checkpoint.** Before you stop, `code_set type="checkpoint"` on a topic, so the next
   session (or another agent) starts where you stopped. `/codelux:checkpoint` does it for you.
7. **Other agents.** Several agents may work the same project. `code_msg` leaves them a short message;
   long background work can go to TaskAI (`taskAI_models`, then `taskAI_new`).

`git_status`, `git_commit`, `git_branch` (read-only) and `git_push` (off until the user authorises it)
are available too. `git_push` must never be used unless the user asked for it.

If you are unsure about a tool, the daemon serves the full, version-matched reference at
`http://localhost:8766/help` and the setup guide at `http://localhost:8766/first-installation`.
