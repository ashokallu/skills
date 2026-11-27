---
name: browser-e2e
description: Reproduce UI behavior, write browser E2E tests, or investigate a failed browser test.
---

# Browser E2E

1. Record the revision, browser, route, and test data needed to reproduce the behavior. Use a synthetic account in an authorized test environment.
2. Drive the UI as a user would. Prefer locators based on accessible roles and names, and assert a visible outcome.
3. Use a fresh browser context when session state matters. Wait for observable application state instead of fixed delays.
4. On failure, inspect the first failing assertion and compare the trace, logs, and screenshots from failed and successful attempts. A passing retry is evidence about reproducibility.
5. Remove session state and sensitive page content from any artifacts before sharing them.
