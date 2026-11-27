<!-- markdownlint-disable MD013 -->

# Story Template

For user-facing change that delivers value to a person outside the team.

## Summary

`[Feature/Component]: brief description of the goal or change`

Example: `Homepage: surface short-form video feed for logged-out learners`

## Description skeleton

```
As a [user type],
I want to [action],
So that [objective].

*Context:*
[Current system state and why this change is needed — business context, technical background, or the problem being solved.]

*Acceptance Criteria:*
* [Specific, measurable result]
* [Condition on data, state, or functionality]
* [Edge case or non-functional requirement]

*Definition of Done:*
* [Environments the change must reach]
* [Documentation to update, and who it goes to]
* [Any verification particular to this change — visual baselines, migration rehearsal, etc.]

*Non-Functional Requirements:*
[Performance, security, accessibility — omit the whole section if none apply.]

*Dependencies:*
[Blocking teams, services, approvals — omit if none.]
```

`Additional Notes` is an optional section for links to designs, mockups or docs that don't belong in acceptance criteria.

### Definition of Done — keep it ticket-specific

List only items that carry information particular to this ticket. Writing code to
specification, passing unit and integration tests, and getting peer review apply to every
Story the team ships. Restating them tells a reader nothing they didn't already know, and
a section that reads identically on every ticket trains people to skim past it.

Name the environments, documents, audiences and verification steps that are actually
specific to this piece of work — "deployed to staging and production" on a ticket that
spans two environments, or "authoring documentation updated and shared with the content
team" where there is a real handoff.

## Fields

| Field | Notes |
|---|---|
| Priority | Relative to the rest of the backlog. DEMO uses `Normal` and similar, not Low/Medium/High — check with `jira_get_field_options` |
| Estimation | Story points |
| Assignee | Team member responsible |
| Label(s) | Apply only labels the user has named. Common on DEMO: `Learn`, and feature labels such as `md-serving` or `data-migration` |

## Worked example

Summary: `Homepage: surface short-form video feed for logged-out learners`

```
As a learner arriving on the Learn homepage without signing in,
I want to see a feed of short-form video content,
So that I can find something to watch immediately rather than browsing the full catalogue.

*Context:*
The logged-out homepage currently leads with the tutorial catalogue, which assumes the visitor already knows what they want. Short-form video is the highest-engagement format we publish and is not surfaced anywhere on entry.

*Acceptance Criteria:*
* The feed renders on the logged-out homepage above the catalogue section.
* Videos are fetched at build time and revalidated on the existing ISR cadence, not fetched per request.
* The section is omitted entirely — not left as an empty container — if the feed returns no items.
* Feed failures do not block homepage render.

*Definition of Done:*
* Playwright coverage added for the populated and empty states.
* Visual regression baselines updated for mobile and desktop.
* Deployed to production.

*Non-Functional Requirements:*
* No regression to homepage Largest Contentful Paint.
* Video thumbnails served through the existing asset CDN with `auto=format`.
* Feed is keyboard-navigable and each item has an accessible name.

*Dependencies:*
* Spike outcome on feed integration approach.
```

Priority: Normal · Estimation: 5 points · Labels: `Learn`
