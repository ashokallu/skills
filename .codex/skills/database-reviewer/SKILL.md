---
name: database-reviewer
description: Review schema changes, queries, migrations, indexes, backfills, and database rollout plans.
---

# Database Reviewer

1. Identify the database engine, migration order, and affected read and write paths from repository evidence.
2. Check query semantics, null handling, constraints, transaction scope, and compatibility during rolling deploys.
3. Examine expected table size, locks, and query plans using approved evidence. Use synthetic fixtures or an authorized disposable database when running checks.
4. Check whether backfills can resume, how partial progress is measured, and how operators can stop or recover safely.
5. Cite the migration or query and the failure condition for each finding. State which operational assumptions still need evidence.
