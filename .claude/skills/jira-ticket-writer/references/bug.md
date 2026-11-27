<!-- markdownlint-disable MD013 -->

# Bug Template

For behaviour that is wrong against an existing expectation.

A bug ticket lives or dies on whether someone else can reproduce it. Steps to reproduce, environment, and the actual error text are the parts worth asking the user for before drafting — they can't be inferred, and a guessed repro step is worse than none because it looks real.

## Summary

`[Component/Feature]: concise description of the fault`

Example: `Homepage: expired session returns HTTP 500 instead of the logged-out page`

## Description skeleton

```
[What the expected behaviour is, what actually happens, and the impact this is having.]

*Environment and build details:*
* OS: [version]
* Browser: [version]
* Version: [release or build version]
* [Sentry/dashboard] link: [url]

*Steps to reproduce:*
# [First action]
# [Second action]
# [Third action]

*Expected Result:*
[What should happen if the system were working correctly.]

*Actual Result:*
[What happens instead, including exact error messages.]

*Notes:*
[Related incidents, recent changes, suspected causes, related tickets — omit if none.]
```

## Fields

| Field | Notes |
|---|---|
| Priority | Based on impact on users and the system |
| Environment | Production, Staging, or both |
| Assignee | Investigator/fixer |
| Attachments | Screenshots, console logs, video capture, Sentry event links |
| Label(s) | Apply only labels the user has named. DEMO bugs often carry paired severity labels — `Impact:High`, `Severity:Critical` — alongside an area label |

Attachment convention: create the ticket first, then name attachments after the key — `DEMO-123(a)`, `DEMO-123(b)`.

## Worked example

Summary: `Homepage: expired session returns HTTP 500 instead of the logged-out page`

```
When a learner returns to the Learn homepage with an expired session cookie, server-side rendering throws and the request fails with a 500. Expected behaviour is for the stale session to be discarded and the logged-out homepage served. Affected users see an error page and cannot recover without manually clearing cookies.

*Environment and build details:*
* OS: macOS 15.3
* Browser: Chrome 138
* Version: example-app v0.302.0, Production
* Sentry: [link to the grouped issue]

*Steps to reproduce:*
# Sign in to Learn, then let the session expire (or edit the session cookie to a past expiry).
# Navigate to the Learn homepage.

*Expected Result:*
The expired session is cleared and the logged-out homepage renders.

*Actual Result:*
The response is HTTP 500 and the error page is shown. Sentry records the failure during server-side session resolution rather than a handled redirect.

*Notes:*
Same root cause is suspected for protected pages returning 500 rather than redirecting. Worth handling the session-resolution path once rather than per route.
```

Priority: Normal · Environment: Production · Labels: `Impact:High`, `Severity:Critical`
