# Providers

A provider is four operations plus three facts. Nothing else about a tracker matters to
`ticket-flow`.

| Operation | Purpose |
|---|---|
| **fetch** | Get a ticket by its human id. Returns current status + the ids that make up `scope`. |
| **statuses** | List the statuses valid *for that ticket* (scoped per list, team, or project). |
| **set** | Write the new status. |
| **mine** | List my open tickets. Powers the bare verb and the id fallback. |

| Fact | Why |
|---|---|
| `set` accepts | a status **name** or a state **id** — decides whether you must map name -> id first |
| ordering field | powers the backwards-move guard |
| `scope` keys | what `fetch` yields and every later call needs |

Tool names below omit the MCP prefix (`mcp__<server>__`), which depends on how the server is
registered locally. Confirm the actual prefix from the session's tool list during `setup`.

---

## `clickup`

**Status: verified** against a live ClickUp MCP.

| Operation | Tool | Notes |
|---|---|---|
| fetch | `clickup_get_task` | `task_id` **accepts the human custom id directly** (`ABC-1234`) — no search step. Pass `expand_statuses: true` to get statuses in the same call. |
| statuses | *(same call)* | `available_statuses[]` — each `{status, orderindex, type}`. `type` is `open` / `custom` / `closed`. |
| set | `clickup_update_task` | `task_id` + `status`. Takes the **exact status name**, case-sensitive. |
| mine | `clickup_filter_tasks` | `assignees: [<id>]` + `space_ids: [scope.space_id]`. Leave `include_closed` at its default so closed tickets drop out. |

- `set` accepts: **name**
- ordering field: `orderindex`
- `scope` keys: `workspace_id`, `space_id` — both come back on the fetched task (`space.id`)
- identity: `clickup_resolve_assignees` with `"me"`. Never store the numeric id.

Notes worth keeping:

- `expand_statuses` folds *statuses* into *fetch*, so ClickUp needs one read, not two.
- Statuses are **per list**. Verified in one workspace: active sprint lists ran
  `backlog → in progress → code review → qa → ready for prod → blocked → done`, while older
  lists in the same space used `to do` and `review` instead, and a backlog-style list had a
  different ladder again. This is the whole reason for reading before writing.
- `clickup_get_list` also returns a list's statuses, if you ever need them without a ticket.

---

## `linear`

**Status: NOT verified.** No Linear MCP was connected when this was written, so these names come
from Linear's MCP documentation, not from observation. `setup` step 3 exists to prove them —
expect to correct something here on the first real run, and fix this file when you do.

| Operation | Tool | Notes |
|---|---|---|
| fetch | `get_issue` | Accepts the identifier (`ENG-123`). |
| statuses | `list_issue_statuses` | Workflow states, scoped to a **team** — pass `scope.team_id`. |
| set | `update_issue` | Verify whether `state` wants a **name** or a state **id**; assume id and map from the `statuses` result. |
| mine | `list_my_issues` | Already scoped to the caller — no identity lookup needed. |

- `set` accepts: **id** (assumed — prove it)
- ordering field: `position`, with the state `type` (`backlog` / `unstarted` / `started` /
  `completed` / `canceled`) as a coarser fallback
- `scope` keys: `team_id`
- identity: not needed; `list_my_issues` is implicitly the current user.

Convenient coincidence: Linear identifiers (`ENG-123`) and ClickUp custom ids (`ABC-1234`) share
a shape, so the default `branch_pattern` of `[A-Z]+-[0-9]+` covers both with no change.

---

## Adding a provider

Fill in the two tables above for your tracker, then run `setup` — it proves the block by calling
all four operations before writing any config. If an operation is missing from your tracker's
MCP, that tracker cannot be supported without one; there is no REST fallback here on purpose
(see the README).
