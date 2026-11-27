---
name: jira-ticket-writer
description: "Writes well-structured Jira tickets using the team's official issue-type templates (Story, Task, Bug, Epic, Initiative, Risk, Collaboration), then files them in the the organization Learn (DEMO) Jira project once the user approves. Use this skill whenever the user wants to raise, write, draft, file, or log a Jira ticket, issue, story, bug, epic, or task — and also when they describe a piece of work, a defect, or a plan in a way that clearly wants to become a ticket (\"we need to fix X\", \"can you write this up for the backlog\", \"turn this into a ticket\"), even if they never say the word \"Jira\"."
---

<!-- markdownlint-disable MD013 -->
<!--
Last verified: 2026-08-10
-->

# Jira Ticket Writer

Turns a rough description of work into a ticket that matches the team's agreed
templates, then files it in the the organization Learn (`DEMO`) Jira project.

The value here is structure and honesty. A ticket that follows the template is
easier to estimate, pick up, and close — and a ticket that clearly marks what
nobody knows yet is far more useful than one where the gaps have been quietly
filled with plausible fiction.

## Prerequisites

Drafting works anywhere. Filing needs the team's Jira MCP server, which this
repository declares in `.mcp.json` at the root. Claude Code prompts for
approval per project directory, so each new worktree asks again.

The server authenticates with a personal bearer token read from
`JIRA_MCP_TOKEN` in the environment. Export it from your shell profile
(`~/.zshrc` or equivalent):

```sh
export JIRA_MCP_TOKEN=<your token>
```

The shell profile is the right home for it rather than the repo's `.envrc`.
`.envrc` is gitignored and per-clone, so a token set there is absent from every
worktree under `tmp/worktrees/`, while `.mcp.json` is tracked and present in
all of them — the combination fails only in worktrees, which is the harder bug
to recognise.

`Pending Verification`: how a token is issued is an internal process, and this
setup has not yet been confirmed end to end by anyone other than its author.
Ask the team for the current route rather than guessing.

Tool names in this document are written bare (`jira_create_issue`). The real
names are namespaced by server name, so with this repository's `.mcp.json` the
create call is `mcp__jira__jira_create_issue`. If someone has the server
configured under a different name, the prefix changes and the bare names do
not. A `jira` server defined in personal config at local scope overrides this
repository's `.mcp.json` entirely, since local scope outranks project scope and
entries are never merged.

Two different failures, with different responses:

- **Tools absent** — no `jira_*` tools registered. Produce the draft and say
  plainly that filing isn't possible from here rather than pretending
  otherwise.
- **Tools present but rejected** — the call returns 401 or 403. The token is
  missing, empty, or expired; `claude mcp list` shows the server and any
  missing-variable warning. Do not retry the call, and do not report the ticket
  as filed. Say which step failed, confirm no issue key was returned, and point
  at `JIRA_MCP_TOKEN`. Keep the approved draft in the reply so the user does
  not have to reconstruct it.

## Project

**Default to `DEMO` (the organization Learn).** This is the team's project and effectively
all tickets belong there, so don't ask which project unless there's a reason
to.

Still show `Project: DEMO` in the draft rather than filing silently — a visible
default can be corrected in one word, an invisible one gets discovered after
the ticket is in the wrong backlog. If the user names a different project, use
theirs without argument.

Board and sprint IDs for DEMO change over time, so look them up rather than
hardcoding: `jira_get_agile_boards` with `project_key: "DEMO"`, then
`jira_get_sprints_from_board`.

## Workflow

1. **Pick the issue type.** See the selection table below. If it's genuinely
   ambiguous, draft the most likely one and say which alternative was
   considered and why it was rejected — the user can redirect in one word.
2. **Read the matching reference file** from `references/` in this skill
   directory (`references/task.md`, `references/bug.md`, and so on). Each
   defines the Summary convention, the Description skeleton, and the fields
   that type needs. Read only the one that applies.
3. **Draft it**, following the inference rules below. Where the draft names a
   value the server constrains — priority especially — resolve the accepted
   vocabulary now rather than at create time, so the user approves a value
   that will survive filing.
4. **Present the draft in chat for approval.** Never file a ticket without
   showing it first.
5. **On approval, create it in Jira**, verify the stored result (see below),
   and return the issue key and link.

## Choosing the issue type

| Type | Use when | Signals |
|---|---|---|
| **Story** | User-facing change that delivers value to someone | "as a user", new feature, UX change, something a person will notice |
| **Task** | Work with no direct user-facing outcome | config, setup, migration, spike, chore, infra, "set up", "upgrade" |
| **Bug** | Something is behaving incorrectly right now | "broken", "failing", error messages, "should be X but does Y" |
| **Epic** | A body of work that needs breaking into several stories/tasks | multiple workstreams, spans sprints, "revamp", "redesign" |
| **Initiative** | Business-level effort spanning teams, tracked in quarters | strategy, targets and percentages, named stakeholders across departments |
| **Risk** | A thing that *might* go wrong and needs a mitigation owner | "risk that", "if X doesn't land", vendor/dependency exposure |
| **Collaboration** | Coordinating several teams toward a shared date | cross-team, launch coordination, "align with", communication plan |

Common confusions worth getting right:

- **Story vs Task** — ask who benefits. If the answer names a user or customer,
  it's a Story. If the answer is "the team" or "the system", it's a Task.
- **Bug vs Story** — a Bug means the behaviour is wrong against an existing
  expectation. Something that merely doesn't exist yet is a Story, however much
  someone wants it.
- **Epic vs Initiative** — an Epic contains tickets; an Initiative contains
  Epics and usually has business metrics attached.
- **Risk vs Bug** — a Risk hasn't happened. Once it has, it is no longer a
  Risk: file a Bug if something is now behaving incorrectly, or whichever type
  fits the work the outcome actually created.

## What to infer, and what to leave open

Judgement calls can be inferred from context, then flagged so the user can
correct them:

- **Priority** — reason from stated impact: production breakage or revenue
  impact is High; a cosmetic issue is Low.
- **Estimation** — offer a rough figure only where the scope is clear, and say
  it's a starting point for the team to refine.
- **Issue type** — as above.

**Labels are not inferred.** Apply only labels the user has explicitly named.
DEMO's label vocabulary is inconsistent and largely ad hoc, so a
plausible-looking guess is more likely to be wrong than right — and a wrong
label quietly skews whatever board or filter depends on it. If a label seems
like it would help, suggest it in the draft and let the user confirm.

Labels actually in use on DEMO, for recognising rather than guessing: `Learn`,
`infrastructure`, `terraform`, `test`, `documentation`, `coordination`,
`Sanity`, `Alerts`, plus workstream labels such as `md-serving`,
`data-migration`, `legacy-decommission`, `genesis`, `SP/EP`. Bugs additionally
carry paired `Impact:*` and `Severity:*` labels.

Facts that aren't in the conversation must never be invented. Write `[TBC]`
instead, and list what's missing under the draft so the user can fill it in:

- Steps to reproduce, error messages, log output, versions, browsers, OS
- Assignee names, stakeholder names, team names
- Dates, deadlines, target start/end
- Links to designs, docs, dashboards, or related tickets

The reason to hold this line: an invented repro step reads exactly like a real
one, so it survives review and then wastes an engineer's afternoon. A `[TBC]`
costs the user ten seconds to fill in. Ask for the important gaps rather than
papering over them — for a Bug especially, repro steps and environment are
worth one round of questions before drafting.

Omit optional sections that genuinely don't apply rather than padding them with
filler. A Story with no dependencies should have no Dependencies heading.

**Definition of Done: keep it ticket-specific.** List only items carrying
information particular to this ticket — the environments it must reach, the
documents to update and who they go to, any verification specific to this
change. Writing code to specification, passing unit and integration tests, and
getting peer review apply to every ticket the team ships, so restating them
tells a reader nothing they didn't already know and trains people to skim the
section.

A closing condition that belongs to the issue *type* is not boilerplate and
should stay. An Epic cannot close while its children are open, which is why
`references/epic.md` opens its Definition of Done with exactly that line. The
test is whether the item tells a reader when this ticket may be closed, not
whether it happens to recur across tickets of the same type.

## Recording risks and open technical questions

Where the work carries a risk or an unresolved technical question, state the
risk plainly and offer options as options. Do not present one approach as
settled unless the user has settled it. Name the tradeoffs, say what is known
and what isn't, and make clear that whoever picks the ticket up is expected to
evaluate rather than follow a recipe. A ticket that quietly narrows the
solution space costs more than one that leaves it honestly open.

## Writing about people

Tickets are permanent and widely readable. Where work involves a person's
availability, capacity, or knowledge — Risks especially — write about the
system and the capability gap rather than the individual. "Only one engineer
can run the release pipeline unaided" is actionable and fair; framing someone
as a liability is neither.

Never infer who owns something. Use `[TBC]` and ask.

## Output format — write Markdown, never wiki markup

**The Jira MCP tools accept Markdown and convert it to Jira wiki markup
themselves.** Sending wiki markup gets double-converted and renders wrongly.
This has bitten the team more than once, so it is worth being precise about:

| Intent | Write this (Markdown) | Do NOT write | Why the wrong one breaks |
|---|---|---|---|
| Section heading | `**Steps to Complete:**` | `*Steps to Complete:*` | Markdown reads single asterisks as *italic*, so the heading renders italic instead of bold |
| Numbered steps | `1.` `2.` `3.` at line start | `#` at line start | Markdown reads `#` as an H1 heading, so every step renders as a giant title |
| Bullets | `-` at line start | `*` at line start | Ambiguous with emphasis; `-` is unambiguous |
| Code, filenames, errors | `` `middleware.ts` `` | `{{middleware.ts}}` | Braces render literally |

The reference files describe the *shape* of each template (which sections, in
which order), and their skeletons are written in wiki markup. Translate that
shape into Markdown when you actually write the field — do not copy the
wiki-markup examples through verbatim.

Leave a blank line between sections, and a blank line before the first item of
any list.

Keep the prose tight. Acceptance criteria should be specific and checkable —
"search results return within 2 seconds at p95" rather than "search is fast".

## Presenting the draft

Show it as a field list, so it's obvious what goes where:

```
Type:        Bug
Project:     DEMO
Summary:     Homepage: expired session returns HTTP 500 instead of the logged-out page
Priority:    High  ← inferred from "affects every returning user with a stale session"
Environment: Production
Labels:      [none — say if you want any]
Assignee:    [TBC]

Description:
<the Markdown body>
```

Mark every inferred value with `←` and the reason. Then list open `[TBC]` items
as questions, and ask whether to file it.

## Creating the ticket

Once the user approves, create the issue with `jira_create_issue`.

- Set the type-specific fields (Environment for Bugs, parent Epic link where
  relevant) rather than burying that detail in the description.
- **Don't assume the priority vocabulary.** It varies by issue type on DEMO — a
  Task create was rejected for `Medium`, while Bugs carry `High`. An unaccepted
  value fails the whole create call. Resolve the accepted values with
  `jira_get_field_options` or `jira_search_fields` *before* presenting the
  draft, so the priority shown is one the server will take. If a value is
  rejected at create time anyway, stop and re-confirm rather than substituting
  a working one — approval covers what was shown, and quietly filing a
  different priority means the ticket that exists is not the ticket the user
  agreed to.
- **Story points live on `customfield_10002`** on DEMO — the field named
  `Story Points`. Do not pick a field by name alone: the instance also carries
  `Story point estimate` (`customfield_46115`), `Story Points (Actual)`
  (`customfield_46305`), `Original story points` (`customfield_14302`) and
  `Epic Story Points` (`customfield_21003`), and writing to the wrong one
  achieves nothing visible on the board. The scale in practice runs 1–5 for
  most Stories and Tasks, with 8 and 13 reserved for genuinely large items.
  Check comparable tickets before pointing rather than assuming a generic
  Fibonacci reading.
- **Sprint assignment is a separate call.** `jira_create_issue` cannot set the
  sprint. To put a ticket in the current sprint: `jira_get_agile_boards` with
  `project_key: "DEMO"` → `jira_get_sprints_from_board` with `state: "active"` →
  `jira_add_issues_to_sprint`. Confirm the sprint name and dates back to the
  user, since "this sprint" is ambiguous near a boundary.
- Report the issue key and URL. If the user mentioned attachments, screenshots,
  or logs, remind them to attach those, using the ticket key as the filename
  (`DEMO-123(a)`) per the template convention.

## Verify after filing

Formatting bugs are invisible from the create response alone, because the
response echoes what you sent rather than what Jira stored. After creating or
updating a ticket, read it back with `jira_search`
(`fields: summary,status,labels,assignee,priority,description`) and check the
stored description:

- Headings should appear as `*Bold:*` — wiki bold. If you see `_Italic:_`, you
  sent wiki markup by mistake.
- Numbered steps should appear as `#` at line start — wiki ordered list. If you
  see `h1.`, same mistake.
- Every field you actually sent should be present. One you set that comes back
  empty was rejected — say so rather than letting the user discover it later.
  A field deliberately left unset is not evidence of rejection: an assignee
  held at `[TBC]` is the workflow behaving correctly, so do not flag it, and
  never resolve it by inventing a name.

Fix and re-verify before reporting success. Report any field the server changed
or dropped.

If the user only wanted a draft, stop after presenting it. Don't file anything
on an ambiguous "thanks".

## Reference files

Read the one matching the chosen type, from `references/`:

- `references/story.md` — worked example: surfacing a short-form video feed on
  the Learn homepage
- `references/task.md` — hosting GitHub Actions test artefacts via Tessen
- `references/bug.md` — expired session returning HTTP 500 instead of the
  logged-out homepage
- `references/epic.md` — decommissioning legacy Example App infrastructure
- `references/initiative.md` — moving Learn to unattended multi-daily releases
- `references/risk.md` — single-person coverage of release tooling
- `references/collaboration.md` — standing up app.test.example.com across
  Learn, PRE and Ops

These are the Learn team's own templates. The worked examples are drawn from
real Example App work so the shape of a good ticket is recognisable, and
names are left as `[TBC]` deliberately — fill in the real ones per ticket
rather than copying whoever appears in the template.

## Maintaining this skill

**Changing a template.** This skill lives in the repository, so `SKILL.md` and
every file in `references/` is edited in place and shipped through a normal
pull request.

Treat a template edit as a team-wide change, because it shapes every ticket
raised afterwards:

- Follow the repo branch and PR policy in `AGENTS.md`. Stage explicit paths.
- Keep the change scoped to the template that is actually wrong. Resist
  rewriting the others for consistency in the same pass.
- Field IDs, priority vocabularies, and label sets drift. Re-check them against
  the live instance (`jira_search_fields`, `jira_get_field_options`) before
  changing what this file asserts about them, rather than editing from memory.
- Update `Last verified` above when the workflow, field IDs, or tool names
  change, and note what you checked in the PR description.
