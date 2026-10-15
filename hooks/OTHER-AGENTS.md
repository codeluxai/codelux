# Codelux hooks for Codex and Gemini CLI - what is verified, what is not

Formats were taken on 28/09/2026 from https://learn.chatgpt.com/docs/hooks (Codex) and
https://geminicli.com/docs/hooks/reference/ (Gemini CLI). Anything listed under "uncertain"
was NOT confirmed by those pages: check it against the current docs before relying on it.

## Codex (`codex.hooks.json` -> `<repo>/.codex/hooks.json` or `~/.codex/hooks.json`)

Verified: envelope `{"description","hooks":{Event:[{matcher,hooks:[{type,command,timeout,additionalContextLimit}]}]}}`;
events SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop; stdin fields `prompt`,
`tool_input`, `stop_hook_active`, `cwd`; plain stdout added as context; exit 2 = block with stderr reason.

Uncertain:
- The tool names an edit matcher must match. The docs' own example is `"Edit|Write"` "(matches file
  edits via `apply_patch`)"; we match `Edit|Write|MultiEdit|apply_patch` to be safe.
- The field name of the edited path inside `tool_input` for `apply_patch`. `edit-lock.sh` looks for
  `file_path`, `notebook_path` or `path`; if Codex sends the patch text only, the lock is a silent
  no-op (exit 0), never a block.
- `timeout` unit: assumed seconds (same as Claude Code); `additionalContextLimit` is characters.
- Whether Codex exports a project-dir variable: the scripts use `$PWD` (hooks run in `cwd`)
  or `CODEX_PROJECT_DIR` if set.

## Gemini CLI (`gemini.settings.json` -> merge the `hooks` object into `.gemini/settings.json`)

Verified: events SessionStart, BeforeAgent, AfterAgent, BeforeTool, AfterTool; hook fields
`type`, `command`, `name`, `description`, `timeout` (milliseconds); `BeforeAgent` stdin has
`prompt` and its `hookSpecificOutput.additionalContext` is honoured; `AfterAgent` stdin has
`stop_hook_active`; exit 2 = block with stderr reason; stdout must be JSON only (hence `--json`).

Uncertain:
- `SessionStart` does not list `additionalContext` among its `hookSpecificOutput` fields in the
  reference; `session-start.sh --json` emits it anyway (`hookEventName: SessionStart`). If it is
  ignored, the AGENTS.md/GEMINI.md block still carries the state.
- Built-in edit tool names: assumed `write_file`, `replace` (and `edit`); the reference names
  `read_file` and `run_shell_command` as examples only.
- The path field inside `tool_input` for those tools: assumed `file_path`.
- Gemini reads `GEMINI.md`, not AGENTS.md: `agents-md.sh` writes AGENTS.md (and CLAUDE.md when it
  exists). To get the block into GEMINI.md, run `agents-md.sh` and copy the block, or set
  `contextFileName` to `AGENTS.md` in Gemini's settings.
- No `GEMINI_PROJECT_DIR` variable is documented; the scripts use `$PWD`.

## Session code and usage tracking (session-track.sh, 07/10/2026)

All three configs call `scripts/session-track.sh <event> --agent=<type>` (silent: it never prints,
so it adds nothing to the context). The daemon derives ONE Codelux session code from the agent's
own `session_id` on the hook's stdin and uses it for locks, memories, notes, messages and the task
registry (`tasks_get` / `tasks_report`).

| Host | `session_id` on stdin | transcript for the token numbers | if missing |
|---|---|---|---|
| Claude Code | verified (every hook) | `transcript_path` (+ `<session>/subagents/*.jsonl`) | — |
| Codex | NOT verified | `transcript_path` if sent, else the rollout file whose name contains the session id (`~/.codex/sessions/**`) | hook ignored ("skip: no session id"); MCP calls get one code per MCP connection |
| Gemini CLI | NOT verified | `transcript_path` if sent | same as Codex |

The end of a session is best effort. `session-track.sh end` reads its input with a shell builtin and hands everything else to one background process before doing any work (Claude Code gives all SessionEnd hooks together 1.5 s, then cancels them). When no end arrives at all, the daemon closes the session itself after 2 h with no hook, no MCP call and no transcript write (end reason `stale`, end-of-work report written). A later hook of the same conversation reopens it.

Uncertain: whether Codex/Gemini fire `PreToolUse`/`BeforeTool` for MCP tools with a `mcp__…`
name (the announcement that binds the MCP connection to the hook session). Without it the MCP
calls of that agent are recorded under a per-connection code, distinct from the hook code.

## One identity on every channel (375, 14/10/2026)

An agent is ONE identity: provider (`claude-code` | `codex` | `gemini` | `cursor` | `other`) + its
codename + the host's session id (when there is one) + the subagent id (when there is one). The
codename is mandatory on every channel (`agent=` / `--agent=` / `X-Codelux-Agent` / MCP `agent`);
a hook-only session with no name yet shows as "waiting for its name" and joins its name at the
first call that gives it.

| How the halves meet | What it needs | Hosts |
|---|---|---|
| shell PreToolUse (`session-track.sh pre` on Bash/PowerShell/`shell`/`run_shell_command`): the daemon reads the name in a command that calls Codelux (`agent=`, `--agent=`, `X-Codelux-Agent:`, `CODELUX_AGENT=`) and declares it on the hook's session or subagent BEFORE the command runs | nothing beyond the name | Claude Code verified; Codex (`shell`) and Gemini (`run_shell_command`) tool names NOT verified |
| explicit: REST `session=` / `subagent=` / `provider=` or headers `X-Codelux-Session` / `X-Codelux-Subagent` / `X-Codelux-Provider`; CLI `--session` / `--subagent` / `--provider` or env `CODELUX_SESSION` / `CODELUX_SUBAGENT` / `CODELUX_PROVIDER` | the host's session id | Claude Code: `session-start.sh` writes `CODELUX_SESSION` and `CODELUX_PROVIDER` into `CLAUDE_ENV_FILE`, so every Bash command (and the CLI) has them. Codex/Gemini: no such file is documented; pass them yourself |
| by name: a REST call with only `agent=` joins the most recent session that declared that name | the name | every host |

A Claude Code subagent's Bash runs with its PARENT's `CODELUX_SESSION`: the daemon gives the call to
the subagent that declared the name (shell hook above) and never renames the parent with a
subagent's name. A subagent resumed with SendMessage under a new `agent_id` that says the same name
is merged into its first self: one Timeline row, one session. An agent with no host session at all
(an external script over REST) is one identity per name, shown as "Other agent".

Why not a state file in `.claude/`: several conversations can be open on the same project, and one
file would hand each of them the other's session id.

## The procedure trace (377, 14/10/2026)

The providers' apps must have the Codelux hooks active: the main session and its subagents send
everything. Every config hooks EVERY tool (matcher `.*`): `session-track.sh pre` before,
`session-track.sh post` after (Claude Code also `post-fail` on PostToolUseFailure). The daemon
writes one row per call (sessions.db, bucket `trace`, local, 30 days, never sent to the server nor
put in a Team event): identity, provider, tool, essential arguments, response size, duration, outcome.

| | Claude Code | Codex | Gemini CLI |
|---|---|---|---|
| events | PreToolUse, PostToolUse, PostToolUseFailure | PreToolUse, PostToolUse | BeforeTool, AfterTool |
| `tool_use_id` (pairs Pre and Post) | verified | NOT verified (else: session + tool + hash of the input) | NOT verified (same) |
| `tool_response` shape | verified (Read: `file.numLines`/`totalLines`; Edit: `structuredPatch`) | NOT verified: measured as text | `llmContent` measured |
| subagents | `agent_id`/`agent_type` on the input: own row identity | — | — |
| hint before a Read/Grep | `hookSpecificOutput.additionalContext` on PreToolUse | none printed (output fields not verified) | `additionalContext` on BeforeTool (NOT verified) |
| hint with the prompt | plain stdout | plain stdout | `--json` additionalContext on BeforeAgent |

Speed: the script never reads the input itself (Git Bash reads a pipe one byte at a time, and a
`cat` is one more process): curl takes the hook's stdin as the body of `POST /hook`. `pre` is ONE
foreground curl bounded at 1.5 s (the MCP announcement and the name of a Codelux shell command must
arrive before the call; the daemon answers in milliseconds); `post` is ONE background curl (stdin
on fd 3) and the script returns at once. Measured on a loaded Windows machine: bash alone ~280 ms,
`post` +~55 ms, `pre` + one curl. A daemon older than 377 answers 404 on `/hook`: nothing happens
(the announcement, the name from a shell command and the file-read record then need the daemon
update, which the daemon does by itself).

Range reads: `GET /api/project/{id}/read?file=&from=&to=`, `codelux read <projectid> <file> <from> <to>`,
and on MCP `code_context` with `name="<file>:<from>-<to>"` (no new schema parameter: the tools/list
budget is full); `code_context name="<file>"` is the file's outline.
