<!-- markdownlint-disable MD013 -->

# Risk Template

For something that might go wrong and needs an owner, a mitigation, and a fallback. If it has already gone wrong, it's a Bug, not a Risk.

## Summary

`[Risk name]: concise title`

Example: `Single-person coverage of release tooling`

## Description skeleton

```
[The situation or event that could cause a negative impact, with background context.]

*Impact:*
[Consequences if the risk materialises — delays, cost, customer impact, legal or reputational exposure. Be specific about magnitude.]

*Likelihood:*
[Low/Medium/High, with the reasoning behind the estimate.]

*Risk Owner:*
[Name] ([role])

*Mitigation Plan:*
[Proactive steps to reduce likelihood or impact.]

*Contingency Plan:*
[Reactive steps if it happens anyway.]

*Deadline:*
[Date by which mitigation actions should be complete.]
```

The distinction between the two plans matters and is easy to blur: mitigation reduces the chance or severity beforehand, contingency is what gets done once it has already occurred. If a draft only has one of them, that's usually a gap rather than a simplification.

Risks often concern people — availability, capacity, coverage. Write them about the system and the capability gap, not about an individual's performance or plans. "Only one engineer can run the release pipeline unaided" is actionable and fair; naming someone as a liability is neither, and the ticket is permanent and widely readable.

## Fields

| Field | Notes |
|---|---|
| Assignee | The risk owner |

## Worked example

Summary: `Single-person coverage of release tooling`

```
Several parts of the deployment and release pipeline have only ever been operated end to end by one engineer. Whenever that person is unavailable — leave, illness, a competing priority, or a change of role — the team cannot run or debug those paths without rediscovering them under time pressure.

*Impact:*
Releases stall and incident response slows while the remaining engineers reconstruct undocumented procedures. Worst case, an incident touching those systems has no one able to respond confidently.

*Likelihood:*
Medium — no single absence is likely on a given day, but across a quarter some period of unavailability is close to certain, and the exposure compounds the longer the gap goes unaddressed.

*Risk Owner:*
[TBC] ([role])

*Mitigation Plan:*
Identify which systems currently have single-person coverage and name a second engineer for each.
Run recorded walkthrough sessions rather than relying on written handover alone.
Have the second engineer run each procedure once, unaided, while support is still available.
Land a runbook per system in the repo.

*Contingency Plan:*
Freeze non-essential changes to the affected systems until a runbook exists and has been used once.
Escalate to the wider platform group for temporary cover if an incident lands during a coverage gap.

*Deadline:*
[TBC] — set this early enough that a failed handover can be retried.
```

Assignee: [TBC]
