# Mighty Factory canonical documents

As of 2026-09-16, implementation must use these documents:

- Design: `specs/2026-09-16-herdr-software-factory-design-v6.md`
- Implementation plan: `plans/2026-09-16-herdr-software-factory-implementation-v6.md`

All Review-5, Review-4, Review-3, and 2026-09-15 Mighty Factory design/implementation-plan files are historical drafts and are superseded. Do not implement from them.

The canonical v0.1 design includes Review-6 corrections: config/task/classification are all frozen as exact-byte SHA-256 snapshots at authorization; canonical repository root and `base_sha` are pinned at authorization; task branch-without-worktree crashes are reconcilable; reviewer and arbiter owned parent markers are persisted before external mutation; result artifacts do not release active-turn leases until the producing agent settles and the turn is archived; ambiguous active turns have an explicit human-only `abandon-turn` path that never retries prompts; verification/verdicts consume archived settled-turn evidence; and stale-lock recovery distinguishes PID reuse using process-start identity rather than PID alone.
