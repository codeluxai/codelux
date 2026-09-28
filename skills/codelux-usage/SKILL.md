---
name: codelux-usage
description: How to work on a Codelux-indexed project with the 8 codelux MCP tools - the project memory arrives by itself, check the live index before answering, edit with your own tools, close with one memory_set. Use whenever the codelux MCP tools are available and you start, continue or close a coding task in this project.
---

# Working with Codelux

Codelux is the project's memory: what earlier sessions, other agents and teammates did, decided and
learned, verified against the current code. You do not have to ask for it: the plugin puts the newest
memory in context at session start and, with each prompt, the codemaps/facts/decisions relevant to it
(nothing when nothing is relevant). Your job is to CHECK before answering and to LEAVE a memory at the end.

## The one parameter that matters: `root`

Every tool takes `root` = the **absolute path of the project folder** (e.g. `E:\work\app` or
`/home/me/app`). Never the project id, never its name. The session-start message tells you the value.
If a tool answers that the folder "is not indexed", use the `codelux-setup` skill.

## The 8 tools

| Moment | Tool | Key parameters |
|---|---|---|
| Resume / recall | `memory_get` | no args = newest memory + files changed since; `topic`, `query`, `since`, `id`; `events: true` = timeline |
| Close the task | `memory_set` | `summary` (required), `topic`, `status`, `next`, `open[]`, `traps[]`, `decisions[{what,why}]`, `facts[{text,file,line}]`, `todos[]`, `codemaps[{label,files,symbols}]`; `op: update|close` with `id` |
| Notes for humans | `notes_set` | `op` create/update/close/delete; `kind` note/todo/form; `title`, `content` |
| Read notes, todos, forms | `notes_get` | open todos, forms waiting for answers, notes by `query` |
| Does X exist? Where? | `code_query` | `query` - symbols and codemaps, one line per hit with file:line; `&` AND, `\|` OR, `!` NOT |
| One symbol + what it calls | `code_context` | `name` |
| Controlled write | `code_edit` | `path`, `old`/`new` or `content`, `base_hash` - lock + backup + reindex; use it when running many agents at once |
| Other agents on this project | `agents_msg` | `op` post/list, `text`, optional `to` - short message (1h), delivered with their next call |

grep, reading files and git are yours (Grep, Read, Bash): Codelux does not duplicate them.

## Rules

1. **Memory arrives by itself.** Read the session-start memory and each prompt's memory block before
   exploring; resume from `next` and the WHERE lines. Call `memory_get` only for more (a topic, a
   period, the timeline).
2. **Check, don't recall.** Before a categorical answer (X exists / is at / supports), especially in a
   table or a yes/no, run `code_query` or `code_context` against the live index. If you did not check,
   say so.
3. **Edit with your own tools.** Native Edit/Write: the plugin takes and releases the file lock around
   each edit (local between agents, Team over the network). If an edit is refused with "Codelux lock",
   someone else is editing that file: wait or work elsewhere, do not work around it. With many agents
   in parallel, `code_edit` does the same with `base_hash` protection.
4. **One memory_set at the end.** Before you stop, a single `memory_set` with `summary`, `next`, the
   `traps` met, `decisions` (what + why), `facts` anchored to file:line, `codemaps` of the area
   touched. It writes the journal, notes and codemaps in one go and refreshes the AGENTS.md block.
   `/codelux:checkpoint` does it for you. The Stop hook reminds you if you forget.
5. **notes_set for humans.** Todos, forms to fill, notes meant for the developer or the team go in
   `notes_set`, not in the memory.

Full reference from the daemon: `http://localhost:8766/help`; setup guide: `/first-installation`.
