# ticket-flow

A [Claude Code](https://claude.com/claude-code) skill that keeps your tracker ticket in step with
the work: pick it up → *in progress*, open a PR → *review*, deploy to dev → *qa*.

Works with **ClickUp** and **Linear**, and with any tracker whose MCP can do four things.
Status names are read from your own workspace at install time, so it fits whatever your team
calls its columns.

## Why a skill and not an MCP server

Your tracker already has an MCP. A second server wrapping it would add auth, a process, and a
release cycle to solve nothing — the whole job is two tool calls per transition. So this is
instructions, which also means adding a tracker is a table entry rather than a code change.

## Install

```bash
git clone git@github.com:talgat-abdraimov/ticket-flow.git
cd ticket-flow
./install.sh
```

`install.sh` **symlinks** `skills/ticket-flow/` into `~/.claude/skills/`, so a later `git pull`
updates the installed skill with no reinstall. Custom location:
`CLAUDE_SKILLS_DIR=/path/to/skills ./install.sh`.

Then, in Claude Code:

```
set up ticket-flow
```

Setup detects which tracker MCP you have connected, asks for one representative ticket, **proves
the connection by calling all four operations**, reads your real status ladder off that ticket,
proposes a verb → status mapping for you to confirm, and writes `~/.claude/ticket-flow.json`.
Nothing is hardcoded and you never hand-edit JSON — though
[`config.example.json`](skills/ticket-flow/config.example.json) documents the format if you want to.

Re-run setup any time; it is also how you adapt after your team renames a status.

## Use

| Say this | What happens |
|---|---|
| "what am I working on" | Lists your open tickets with their current status. |
| "start ABC-1234" / "start this ticket" | → your *in progress* status |
| "move it to review" | → your *review* status |
| "move it to qa" | → your *qa* status |

The ticket id is usually inferred from the branch name (`ABC-1234/some-slug`), so you rarely
type it. Pass it explicitly, or let it fall back to picking from your list.

There is no `done` verb on purpose — closing a ticket belongs to whatever release process you
already run.

## Making it automatic

Two things are left to you, because both are machine-local.

**1. Tell Claude when to fire.** Add to your `CLAUDE.md`:

```markdown
## Ticket status

Use the `ticket-flow` skill to keep the tracker in step, without being asked:
- starting work on a ticket branch → `start`
- after `gh pr create` on a ticket-id branch → `review`
- after dispatching a staging/dev deploy → `qa`
```

**2. Stop the permission prompts.** Allow your provider's update tool in
`~/.claude/settings.json` — otherwise every transition asks. It must be at **user** level; a
project-level allow will not reach sibling repos.

```jsonc
// ClickUp
"permissions": { "allow": ["mcp__clickup__clickup_update_task"] }
```

## Design notes

Three decisions that are load-bearing rather than incidental:

**Reads happen before every write.** Status sets are scoped per list (ClickUp) or per team
(Linear), so a name valid on one ticket is invalid on another — one real workspace turned up nine
distinct statuses across a single space (`backlog`, `to do`, `in progress`, `code review`, `qa`,
`ready for prod`, `blocked`, `idea`, `done`), varying by list. Trackers do not fuzzy-match:
writing `in review` to a list whose status is `code review` fails with
`Status does not exist`. That one read also buys idempotence, the name → id mapping Linear
needs, and a guard against moving a ticket *backwards* when a verb is mistyped.

**Every write is best-effort.** Failure prints one `⚠` line and continues. A card in the wrong
column is an annoyance; a deploy that fails because a tracker call errored is a real problem.

**Ticket ids come from the branch, not from state.** Both ClickUp custom ids and Linear
identifiers are accepted directly by their fetch tools, and both look like `ABC-123` — so one
regex resolves a ticket with no search, no cache, and no file to keep in sync. Branch naming is
inconsistent in practice, so picking from a list is always the fallback.

## Adding a tracker

A provider is four operations — fetch, list statuses, set status, list mine — plus three facts:
whether *set* takes a name or an id, which field gives ordering, and which scope ids to carry.
Fill those into [`providers.md`](skills/ticket-flow/providers.md) and run setup; it proves the
block before writing any config.

There is no REST/API-token fallback for trackers without an MCP. That would mean owning token
storage for every provider, which is a different project.

## Status

- **ClickUp** — verified against a live MCP.
- **Linear** — written from documentation, **not yet verified**; setup will surface any wrong
  tool name on first run. Corrections welcome.

## License

MIT
