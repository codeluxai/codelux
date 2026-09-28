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
