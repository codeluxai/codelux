---
name: codelux-usage
description: How to work on a Codelux-indexed project with the 8 codelux MCP tools - the project memory arrives by itself, check the live index before answering, edit with your own tools, close with one memory_set. Use whenever the codelux MCP tools are available and you start, continue or close a coding task in this project.
---

# Working with Codelux

Codelux is the project's memory: what earlier sessions, other agents and teammates did, decided and
learned, verified against the current code. You do not have to ask for it: the plugin puts the newest
memory in context at session start and, with each prompt, the codemaps/facts/decisions relevant to it
(nothing when nothing is relevant). The first line injected at session start says the predicted prompt-cache
state (cold / warm-up / hot) and what follows: the full memory for a new session, only what changed when the same
conversation resumes while its cache is hot (your context already holds the rest: do not ask for it again), code
points and last conclusions after a long pause or a compaction. Your job is to CHECK before answering and to LEAVE a
memory at the end.

## The one parameter that matters: `root`

Every tool takes `root` = the **absolute path of the project folder** (e.g. `E:\work\app` or
`/home/me/app`). Never the project id, never its name. The session-start message tells you the value.
If a tool answers that the folder "is not indexed", use the `codelux-setup` skill.

## The 8 tools

| Moment | Tool | Key parameters |
|---|---|---|
| Resume / recall | `memory_get` | no args = newest memory + files changed since; `topic`, `query`, `since`, `id`; `events: true` = timeline |
| Close the task | `memory_set` | `summary` (required), `topic`, `status`, `next`, `open[]`, `traps[]`, `decisions[{what,why}]`, `facts[{text,file,line}]`, `todos[]`, `codemaps[{label,files,symbols}]`, `task` (team: the task key, e.g. `PAY-123`); `op: update|close` with `id` |
| Notes for humans | `notes_set` | `op` create/update/close/delete; `kind` note/todo/form; `title`, `content` |
| Read notes, todos, forms | `notes_get` | open todos, forms waiting for answers, notes by `query` |
| Does X exist? Where? | `code_query` | `query` - symbols and codemaps, one line per hit with file:line; `&` AND, `\|` OR, `!` NOT |
| One symbol + what it calls | `code_context` | `name` |
| Controlled write | `code_edit` | `path`, `old`/`new` or `content`, `base_hash` - lock + backup + reindex; use it when running many agents at once |
| Other agents on this project | `agents_msg` | `op` post/list, `text`, optional `to` - short message (1h), delivered with their next call |

grep, reading files and git are yours (Grep, Read, Bash): Codelux does not duplicate them.

## Rules

1. **Memory arrives by itself.** Read the session-start memory and each prompt's memory block before
   exploring; resume from `next`, the CODE POINTS and the WHERE lines. Call `memory_get` only for more
   (a topic, a period, the timeline).
2. **Trust what is certified, check the rest.** CERTIFIED code points are the current code verified by
   hash: use them without re-reading those lines; read only what is CHANGED/GONE or not covered. A point
   another agent changed through Codelux arrives CERTIFIED ("updated by cc-...") with its new lines, and a
   short notice reaches you if you already had it: do not re-read it. CHANGED means changed outside
   Codelux (git pull, an editor without the plugin). Before
   a categorical answer on anything not certified (X exists / is at / supports), run `code_query` or
   `code_context` against the live index. If you did not check, say so.
3. **Edit with your own tools.** Native Edit/Write: the plugin takes and releases the file lock around
   each edit (local between agents, Team over the network). If an edit is refused with "Codelux lock",
   someone else is editing that file: wait or work elsewhere, do not work around it. With many agents
   in parallel, `code_edit` does the same with `base_hash` protection.
4. **One memory_set at the end.** Before you stop, a single `memory_set` with `summary`, `next`, the
   `traps` met, `decisions` (what + why), `facts` anchored to file:line, `codemaps` of the area
   touched. It writes the journal, notes and codemaps in one go; the next session gets it as a message
   (the AGENTS.md block never changes). `/codelux:checkpoint` does it for you.
5. **Team tasks.** On a team project the session-start memory lists your open tasks with their key
   (`T-12`, `PAY-123`). Put the key of the task you worked on in `memory_set` (`task`, or `tasks[]`) and
   in the `topic`: the daily standup links your work to it.
6. **notes_set for humans.** Todos, forms to fill, notes meant for the developer or the team go in
   `notes_set`, not in the memory.

Full reference from the daemon: `http://localhost:8766/help`; setup guide: `/first-installation`.
