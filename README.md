<div align="center">

# Codelux

### The AI Development Space

One environment where your coding agents **index** your projects, **remember**
them across sessions and **share** them with your team. Works with Claude Code,
Cursor, Codex, VS Code and any MCP client. Index and memory stay on your machine.

<br>

## ⬇️ [Download Free — free account, no credit card](https://codelux.ai/download)

**[codelux.ai](https://codelux.ai)** · **[Docs](https://codelux.ai/docs)** · **[Pricing](https://codelux.ai/pricing)** · **[FAQ](https://codelux.ai/faq)** · **[X @codeluxai](https://x.com/codeluxai)**

<br>

<img src="readme-dashboard.png" alt="Codelux dashboard — index stats, query graph, indexed paths and the command console" width="900">

</div>

---

## Your AI forgets your project every session

If you use a coding agent every day, you already pay for it:

- **It starts from zero.** Every new session re-reads the same files and asks you to re-explain the same architecture.
- **It burns tokens.** Whole files go into the context to find three functions.
- **It forgets decisions.** What you tried, what you abandoned and why lives in a chat that is gone tomorrow.
- **Your team doesn't share it.** Each person, and each agent, rebuilds the same understanding on its own.

**Codelux is the environment your agents work in:**

| | |
|---|---|
| **Index** | A local symbol index of every project: search by intent, call trees, compressed reads (50–90% fewer tokens). |
| **Memory** | Notes, decisions and a continuation journal that the next session picks up in one call. |
| **Share** | Team plan: one project, one memory, end-to-end encrypted between machines, Git clones or a shared folder. |
| **Local & private** | Code, index and history never leave your machine. AI calls go only to the provider you choose. |

---

## Get started

1. **[Download](https://codelux.ai/download)** the Free build for your platform — Windows, Linux (x86_64 / ARM64) or macOS (Apple Silicon / Intel, unsigned: right-click → Open the first time).
2. **Run it** — it prints the address of its local dashboard (`http://localhost:<port>`) and indexes your project.
3. **Create your free account inside the app**, in seconds.

Free forever, one active project per machine, every feature unlocked, no time
limit, no card. Need more than one project at once? [Multi and Team](https://codelux.ai/pricing)
add unlimited projects and team collaboration.

Every download comes straight from [codelux.ai](https://codelux.ai/download):
the site builds and signs each binary, and the app checks its own integrity on
every start. The only thing this repository installs is the Claude Code plugin below.

### Claude Code plugin

This repository is also a Claude Code plugin marketplace. With Codelux running:

```bash
claude plugin marketplace add codeluxai/codelux
claude plugin install codelux@codelux
```

It connects the Codelux MCP tools (`http://localhost:8766/mcp`), adds the `codelux-setup` and
`codelux-usage` skills, the `/codelux:status`, `/codelux:memory` and `/codelux:checkpoint` commands,
and a session-start hook that puts today's project memory in context. Different port?
`claude plugin install codelux@codelux --config port=<port>`. Details in [PLUGIN.md](PLUGIN.md).

---

## Teams — shared memory your server never reads

Multi and Team plans share notes, chat, journal and CodeMaps across a team,
**end-to-end encrypted**: the team key is generated in the owner's app and
handed to members over an authenticated channel; the server only stores
ciphertext and can neither read nor re-attribute a message. Projects sync as
Git clones or over a shared/network (SMB) folder, with live "who is editing
what" locks so two people never overwrite each other.

<div align="center">
<img src="readme-team-space.png" alt="Four developers at one desk, each laptop running Codelux, syncing through an encrypted link to a shared folder or a Git repository" width="620">
</div>

<img src="readme-team-chat.png" alt="Codelux dashboard — Team tab: end-to-end encrypted team chat, members and who is editing what" width="900">

## What Codelux gives your AI

### Code Context
- **Smart Query** — boolean search with AND (`&`), OR (`|`) and NOT (`!`); fuzzy matching on name, intent, docs and semantic domains.
- **Compact File Reading** — read any file in CCI Compact format: 50–70% fewer tokens, lossless, with original line references so the AI can edit the real file.
- **Flow Analysis** — trace call flows from any entry point; recursive call trees with cycle detection and external-call markers.
- **Knowledge Graph** — a semantic graph builds itself with every query: keywords, files and symbols linked by real usage frequency.
- **CodeMap** — write a plain-language label like "backend / cache" and the on-board AI resolves it to exact files and symbols.
- **Raw Grep & Outline** — regex search across raw sources plus a structural outline of any file (functions, classes, methods, line numbers).
- **20 supported languages** — 16 with a real tree-sitter grammar (Python, JavaScript, TypeScript, Go, HTML, CSS, C/C++, C#, Rust, Java, PHP, SQL, Pascal/Delphi, Markdown), the rest with dedicated extractors (Vue, Svelte, Blazor Razor, JSON, YAML). Every other file type stays searchable with raw grep.

### Tokens
- **CCI Compression** — the Context Compression Index cuts symbol data by up to 90% while keeping every relevant detail.
- **Token Analytics** — every query logs raw vs. compressed tokens, visible on the dashboard.

### TaskAI
- **Background Requests** — hand work to a TaskAI and keep going; it runs in the background, stays queryable, and its whole history survives the process. Everything stays on your machine — no log of request sessions is kept.
- **History & Context Control** — a readable transcript of every request, its answer and its cost; each new request picks how much history to carry (whole task, last N, a time window, or none).
- **Your Providers, Your Models** — register a provider once, list its models, switch each on or off. Keys are sealed to this machine and never returned by the API.
- **Cost per Request** — model used and cost are recorded on the request itself and add up as it works.
- **Human in the Loop** — a request can pause and ask you a question mid-run; it resumes the moment you answer.
- **No Collisions** — TaskAI requests go through the same guarded write path as everyone else: serialized per file, anchored edits refuse the call when the expected text isn't there.

### Knowledge Base
- **Brief** — ask Codelux what it already knows about a task and get facts, symbols and recent edits back in one call.
- **Facts** — everything Codelux has learned about your project, each entry flagged fresh or "to recheck" when the underlying code changes.
- **Journal & Handoffs** — close a session with a checkpoint (done, open, gotchas, next step); the next session picks it up in one call.
- **Delta Detection** — every checkpoint freezes the state of the files it touched, so a handoff is never trusted blindly.
- **Topic Timelines** — checkpoints group under dotted topics like `Editor.Move`; ask for `Editor` and everything underneath surfaces, newest first.
- **Self-maintaining CodeMaps** — closing a checkpoint keeps its CodeMap in sync on its own.

### Memory & Notes
- **Cross-Session Memory** — `code_memory` returns a compact timeline of recent notes, edits and searches at the start of a session.
- **Smart Notes & Intent Tracking** — typed notes (intent, decision, todo, summary, schema, chat, research, snippet) that survive across sessions, retrievable via `code_memory` or `code_note`. Supports Mermaid diagrams and interactive forms.

### Watch Files
- **Live Reindex** — the file watcher reindexes changed files in seconds.
- **File Edit History** — every save tracked: files changed, symbols/lines added or removed, plus an AI-written summary of each edit.

### Git
- **Branches Viewer** — see branches and HEAD right from the dashboard (read-only: the AI never moves your working tree).
- **Commit, Push & Pull** — stage and commit from the dashboard, pull, and push once you approve the remote (the approval is bound to the remote URL); conflicts are shown, never committed.

### Files & Writes
- **Files Explorer** — browse the project tree with a built-in Monaco editor.
- **One Write Path** — every change goes through a single tool (anchored edits, a whole symbol, or a whole file), serialized per file, applied atomically, snapshotted first so it can be reverted whole. A blind whole-file overwrite is refused.
- **Multi-agent Coordination** — run several agents, sub-agents or git worktrees against the same project on one machine; a write is refused, not silently clobbered, if the file moved since it was read. Works on every plan, no server connection required.
- **Writes on MCP, HTTP and CLI** — `file_edit`, `file_delete`, `file_move`, `file_copy` and the `git_*` tools are available on all three protocols.

### Setup & Privacy
- **AI Self-Install** — your own AI configures itself from `GET /first-installation` or the CLI: MCP config, CLAUDE.md, hook suggestions. One request, zero manual JSON.
- **Local First** — your code index and session history live on your machine. No telemetry, no analytics. Account identity and device token are sealed to this machine. The AI features add one call to the provider you chose — Codelux keeps no log of what passes through.

---

## What's new (September 2026)

- **The AI Development Space** — one environment for indexing, memory and team sharing.
- **Works with the new models** — Claude Opus 5.5, Fable 5.1, GPT-6 and any provider you configure.
- **Instant local calls** — the daemon answers on `localhost` over both IPv4 and IPv6 (no more 2-second waits on Windows).
- **Clean repositories** — Codelux's working folder `.codelux/` ignores itself in git.
- **Live indexing feedback** — the project's dot pulses in the sidebar while it indexes, with exact file counts.
- **Team plan** — zero-knowledge team memory: shared notes, journal and encrypted chat.

---

## What's in this repo

This is Codelux's home on GitHub: the README you are reading, the screenshots
and the Claude Code plugin (`.claude-plugin/`, `skills/`, `hooks/`, `scripts/` and the `.mcp.json`
pointing at the local daemon). Downloads live on [codelux.ai/download](https://codelux.ai/download),
docs on [codelux.ai/docs](https://codelux.ai/docs). No source code here — see
[codelux.ai/legal](https://codelux.ai/legal) for licensing terms. Found a bug or
have an idea? Use **Help → Feedback & ideas** inside the app.

## Questions

- **Docs:** [codelux.ai/docs](https://codelux.ai/docs)
- **FAQ:** [codelux.ai/faq](https://codelux.ai/faq)
- **Support:** through your [dashboard](https://codelux.ai/dashboard) once signed in.
- **Follow:** [X @codeluxai](https://x.com/codeluxai) · [Reddit u/codelux_ai](https://www.reddit.com/user/codelux_ai/)
