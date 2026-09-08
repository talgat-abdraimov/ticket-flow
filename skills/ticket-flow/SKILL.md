---
name: ticket-flow
description: >
  Move a tracker ticket through the dev flow, and report what you moved. Works with ClickUp,
  Linear, or any tracker exposing an MCP. Use when the user picks up a ticket, opens a PR for
  review, deploys to staging, or asks what they are working on. Trigger phrases: "start this
  ticket", "move ABC-123 to review", "move my ticket to qa", "what am I working on", "what are
  my tickets", "set up ticket-flow", "configure ticket-flow". Also fire this yourself, without
  being asked, after `gh pr create` on a ticket-id branch (-> review) and after a staging deploy
  is dispatched (-> qa).
---

# ticket-flow

Keeps a tracker ticket in step with the work: picked up -> `start`, sent for review ->
`review`, deployed to dev -> `qa`. Status names and the tracker itself are configured, never
hardcoded, because every team names these differently.

**Ticket bookkeeping must never block the work.** Every write here is best-effort: on failure
you print one line and carry on. A card in the wrong column is an annoyance; a failed deploy
because a tracker call errored is a real problem.

## Config

Read `~/.claude/ticket-flow.json` before doing anything:

```json
{
  "provider": "clickup",
  "branch_pattern": "[A-Z]+-[0-9]+",
  "statuses": { "start": "in progress", "review": "code review", "qa": "qa" },
  "scope": { "workspace_id": "9001234567", "space_id": "90120000000" }
}
```

- `provider` selects a block in `providers.md` — read that block for the four tool names.
- `scope` is an **opaque per-provider bag**. Pass its keys through to the provider's tools.
  Never interpret it; that is what keeps provider details out of this file.
- Missing config file -> run the `setup` verb instead of guessing.

## Verbs

| Invocation | Do this |
|---|---|
| bare (`ticket-flow`, "what am I working on") | Run *list my items*, print id + title + current status. No writes. **Filter it** — see below. |
| `start` / `review` / `qa` | Resolve the id, then transition to `statuses.<verb>`. |
| `setup` | Detect, prove, and write the config. See below. |

**Filtering the listing.** An unfiltered "everything assigned to me" query is close to useless —
in one real workspace it returned 64 tickets spanning years of closed-out sprints and a goals
list whose statuses (`idea`) have nothing to do with the dev flow. So:

- Narrow **server-side** by passing the configured status values (`statuses.*`) to the provider's
  *mine* operation, so you get only work actually in flight.
- If `scope.list_ids` is set in config, narrow to those lists too.
- For the **id fallback** (step 1.3) widen it — include the backlog-ish statuses, since the whole
  point there is to pick up something not yet started.
- Cap the printed list at ~15, newest first, and say how many you hid.

There is deliberately no `done` verb — closing a ticket belongs to whatever release process the
team already runs.

## Step 1 — Resolve the ticket id

In this order, stopping at the first that works:

1. **Explicit argument** — an id (`ABC-1234`) or a pasted ticket URL.

   URLs need care: a **ClickUp** URL carries the *internal* id, not the human one
   (`app.clickup.com/t/869ev1gz3`), while a **Linear** URL carries the human identifier
   (`linear.app/acme/issue/ENG-123/slug`). So: match `branch_pattern` against the URL first, and
   if nothing matches, take the **last meaningful path segment** as a native id. Both providers'
   *fetch* tools accept their own native id, so either form works — do not reject a URL just
   because no `ABC-123` appears in it.
2. **Current branch** — `git rev-parse --abbrev-ref HEAD`, then match `config.branch_pattern`:
   ```bash
   git rev-parse --abbrev-ref HEAD 2>/dev/null | grep -oE '[A-Z]+-[0-9]+' | head -1
   ```
   Use the pattern from config, not the literal above. This is the free path: both ClickUp custom
   IDs and Linear identifiers are accepted directly by their fetch tools, so no search is needed.
3. **Fall back to the listing** — run *list my items* and ask the user to pick.

Handle both "not a git repo" and "on `main` with no id in the branch name" by falling through to
step 3. Never error out, and never invent an id.

## Step 2 — Read before you write

Always fetch the ticket and its valid statuses **first**, via the provider's *fetch* and
*list valid statuses* operations. This single read is what makes the skill safe:

- **Confirm the target exists.** Status sets are scoped per list (ClickUp) or per team (Linear),
  so the same configured name is not valid everywhere. If `statuses.<verb>` is absent from the
  returned set, try a case-insensitive then a substring match. Still nothing -> print the
  available statuses and tell the user to re-run `setup`. Do not write a guess.
- **Resolve a name to an id** if the provider's *set status* takes an id (Linear does; ClickUp
  does not). `providers.md` says which.
- **Idempotence.** Already in the target status -> print `= <id> already <status>` and stop. No
  write, no error.
- **Backwards-move guard.** If the target sits *earlier* in the ordering than the current status,
  stop and ask for confirmation, quoting both. A mistyped `start` must not drag a ticket back out
  of `qa`. Use the provider's ordering field from `providers.md`.

## Step 3 — Write, and say so

Call the provider's *set status* operation. Then print exactly one line:

```
✓ ABC-1234 → code review
```

On any failure — non-2xx, thrown error, unknown tool — print one line and **continue**:

```
⚠ failed to set ABC-1234 → code review (404 not found) — skipping
```

If step 1 resolved no id at all, skip silently unless the user asked for a transition
explicitly; in that case say you could not find a ticket and show the listing.

## The `setup` verb

Run by `install.sh`, and re-runnable any time — it is also how someone fixes a mapping after
their team renames a status.

1. **Pick the provider.** Detect which tracker MCP tools are available in the session. Exactly
   one -> use it. Several -> ask. None -> tell the user to connect a tracker MCP first, and stop.
2. **Get one representative ticket.** Ask for an id or URL from the project they actually work
   in. Statuses are scoped per list/team, so a ticket from the wrong place yields a wrong ladder.
3. **Prove the provider.** Call all four operations once against that ticket, *set status* being
   a no-op re-set of its current status. Any failure stops setup and names the exact
   `providers.md` key that looks wrong. Do not write a config you could not prove.
4. **Derive `scope`** from the fetched ticket — workspace/space/team ids come back on it.
5. **Propose the verb mapping.** Substring matching alone is not enough — `qa` matches
   exactly and `review` finds `code review`, but `start` matches nothing in a ladder like
   `backlog / in progress / code review / qa`. So match each verb against these synonyms, in
   order, case-insensitively, taking the first hit:

   | Verb | Try, in order |
   |---|---|
   | `start` | `in progress`, `in-progress`, `started`, `doing`, `wip`, `in development`, `active` |
   | `review` | `code review`, `in review`, `peer review`, `pr review`, `review` |
   | `qa` | `qa`, `in qa`, `ready for qa`, `testing`, `in testing`, `verification`, `staging` |

   Then fall back to structure, which is more reliable than names:
   - If the provider marks state **kinds** (Linear's `type`: `backlog` / `unstarted` /
     `started` / `completed`), `started` is your `start` candidate.
   - Otherwise use ordering: `start` is typically the first status after the initial
     backlog/open one.

   Always print the proposal for confirmation rather than accepting a match silently — a wrong
   guess here is the one error that persists into every later transition.
6. **Confirm and write.** Print the detected ladder in order beside the proposed mapping, take
   corrections, then write `~/.claude/ticket-flow.json`.

Then tell the user the two things that make transitions automatic, since neither is done for
them:

- add the `CLAUDE.md` snippet from the README
- allow the provider's *set status* tool in `~/.claude/settings.json`, or every transition
  prompts

## Failure modes

| Situation | Do |
|---|---|
| No config file | Run `setup`. Do not guess a provider or status names. |
| Config names a status the list does not have | Print available statuses, point at `setup`. No write. |
| Fetch returns 404 | Say so, show the id you tried. Do not invent ticket content. |
| No id resolvable | Fall back to the listing. Never error. |
| Set-status errors | One `⚠` line, continue. Never fail the surrounding work. |
| Several tracker MCPs connected | Ask once, record the answer in config. |

## Rules

- Never hardcode a status name, workspace id, or user id. Config or runtime lookup only.
- Never write a status you have not seen in that ticket's own status set.
- Resolve "me" through the provider's own identity lookup; never store a user id in config.
- One line of output per transition. This runs inside larger workflows and must stay quiet.
- Reading is always safe; writing is always best-effort and always announced.
