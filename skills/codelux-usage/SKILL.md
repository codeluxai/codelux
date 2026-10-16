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

## REST and CLI (when MCP is not enough, or the daemon was away)

Base: `http://127.0.0.1:8766/api/project/<projectid>/…` (`codelux projects` lists the ids); pass `agent=<codename>`.

| Need | Call |
|---|---|
| grep | `GET /grep?q=…` - `q` is a case-insensitive RE2 regex when it holds metacharacters, else literal; `re=1`/`re=0` force it. `a|b` is alternation (grep-style `a|b` and `a | b` are read the same). URL-encode q (`curl -G --data-urlencode "q=a|b"`). With `worktree=<name>` every hit's `file` is relative to the worktree folder, `project_file` is the project path |
| List topics | `GET /topics?prefix=Flow` (or `Flow.*`) - counts and last update; CLI `codelux topics <id> [prefix]` |
| List notes / codemaps | `GET /notes?kind=fact|decision|todo`, `GET /codemaps` (one row each; `full=1` = everything); CLI `codelux notes|codemaps <id>` |
| A topic and what is under it | `GET /get?topic=Flow` (dotted prefix; the answer lists the sub-topics in `topics`); `GET /get?query=<words>` answers `matches` |
| The topic journal past 40 rows | `GET /memory?topic=X&limit=200&offset=0` (`journal_next_offset` = next page) |
| Update a codemap | `POST /codemap {label, files, summary}` - an existing label is updated in place |
| Checkpoint | `POST /set {topic, type:"checkpoint", summary, payload:{status, next…}}` - top-level `summary` is the normal form |
| You split / moved / renamed code | Nothing to do for moves the index sees (same body in another file = moved: codemaps and certified points follow, facades are never cited). For a split already done, or to force it now: `POST /restructure {moves:[{from_file:"src/big.js", to_dir:"src/big/"}]}` (or `{from, to}`; no moves = every facade; `dry_run:true` to preview) - CLI `codelux restructure <id> [--from-file F --to-dir D] [--dry-run]`, or the key `"restructure"` in your memory_set `payload`. The answer says what was remapped |

**Daemon down?** Your closing memory is not lost: a failed MCP `memory_set` is queued by the plugin (you are told so), and `codelux tool <id> memory_set '{…}'` / `codelux set …` answer `{"queued":true}` and are sent by themselves when the daemon is back (`codelux outbox`). Do not repeat a queued call.

**Subagents** get the project memory at start (newest + relevant to the task you gave them): the brief you write for a subagent should still say what to read, but not repeat the memory.

Full reference from the daemon: `http://localhost:8766/help`; setup guide: `/first-installation`.

## Many agents in parallel (claims, current records, agent brief)

| Need | How |
|---|---|
| Say what you work on | At start: `POST /claim {paths:["src/parser/","docs/x.md"], ttl:"2h", note}` (CLI `codelux claim <id> <path>... [--ttl=2h]`). The answer lists the other live agents' overlapping claims (this machine + teammates) in `warning`. Advisory: nothing is blocked. The edit hook repeats the warning once if you edit a claimed file: coordinate (`agents_msg`) or pick other files. Release at the end or after the merge: `POST /claim/release {}` (`codelux claim <id> --release`). |
| A record replaces another | Put `"supersedes":["<id>"]` in the memory_set `payload`, or on a `decisions[]` item (`{title, content, supersedes:["n_…"]}`), or in a `POST /set` payload. Normal reads (resume, query, brief, hooks, `/get`) then show only the CURRENT record; the old one says "SUPERSEDED by <id>" when read by id or with history (`memory_get{kind:"history"}`, `?history=1`, `codelux get --history`). |
| A record is wrong | Retract it with a reason (no delete): `memory_set{op:"retract", id:"<id>", payload:{reason:"…"}}`. Hidden from normal reads, shown with history as "RETRACTED by <agent> at <time>: <reason>". |
| A codemap points at nothing | Codelux judges them at every indexing: moved code is followed, never "gone". **Some** targets gone = they are dropped (trace in `remaps[]`). **All** files and symbols gone = marked «DA RIVEDERE» with the date (resume, brief); a target that comes back clears it; still empty after `codemap_retract_days` (`.codelux/settings.json`, default 3, `0` = never) it is retracted by itself (record kept, author `codelux`, reason `auto: all targets gone since <date>`, Timeline event, resume block «CODE MAPS RETIRED»). Still valid? `memory_set{op:"update", id:"cm_…", payload:{files?, symbols?}}` (also restores a retired one; same for a `codemaps[]` item or `POST /codemap` with the same label). History: `GET /codemap?history=1`, `memory_get{id:"cm_…"}`. |
| Brief for a topic / files | `memory_get{kind:"brief", topic:"Flow.X", query:"src/a.go src/b/ <task words>"}` or `GET /brief?topic=Flow.X&files=src/a.go,src/b/&q=<task>` (`format=text`): the task and its claims, the topic's doc sections, decisions in force, traps, rules, facts — each with who wrote it and when (`— w375, 14/10`) and `[da rivedere]` / `[in contrasto]` when they apply —, a FILE INDEX line per file the task cites or claims (`file: symbol@a-b, …`: read only the range you need), the bodies of the symbols the task names while they fit (`CERTIFIED #hash` = the lines on disk now: do not re-read them), one line per symbol not included with its exact `code_context` call, and a closing `HOW TO GO ON` block. One call. A sub-agent gets it at start (SubagentStart hook, within 3 s) for the task you gave it: name in that task the files and the functions it must touch. If its brief says `(Codelux: still being prepared …)`, ask `memory_get{id:"late_…"}` (the id it gives) once for the whole brief with the code. |
| Work from the brief's code | Edit from the CERTIFIED lines (they carry file and line range); for a symbol not there use `code_context{name, file}`, for lines `code_context{name:"<file>:<from>-<to>"}`, to find code `code_query`, for text `GET /grep?q=&worktree=`. A Read of a range the brief already gave you gets a one-line reminder, and `/procedure` counts it (`delivered_reads`). A task in a git worktree gets the worktree's lines (the brief says which checkout). |
| Hooks not arriving | A session start line `⚠ Codelux: this session runs the OLD account plugin "Codelux" 3.5.1` or `⚠ Codelux plugin: …`, a `hooks_warning` in a claim answer, or "Hooks active: no" on the Usage page: the edit/claim/trace hooks of this session do not run. Tell the user the fix the line gives (turn off the Directory plugin "Codelux" in the Claude app, keep `codelux@codelux`, new session); until then check `GET /api/project/<id>/claims` before editing. |
| Topic doc and facts that check themselves | A topic can hold ONE doc made of sections (`memory_set{payload:{doc:{topic, sections:{summary, rules, traps, …}}}}`, only the sections you send change); `memory_get{topic}` opens with it, the brief carries the sections your task's words hit. Facts anchored to code are re-checked at every indexing: moved = anchors follow, changed = «DA RIVEDERE» (confirm with `notes_set{op:"update", id, anchors}`). |
| Decisions of a topic | `GET /get?topic=X&brief=1` and `memory_get{topic, brief:true}` now carry the decisions in force. |
