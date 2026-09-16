# Mighty Factory canonical documents

As of 2026-09-16, implementation must use these documents:

- Design: `specs/2026-09-16-herdr-software-factory-design-v5.md`
- Implementation plan: `plans/2026-09-16-herdr-software-factory-implementation-v5.md`

All Review-4, Review-3, and 2026-09-15 Mighty Factory design/implementation-plan files are historical drafts and are superseded. Do not implement from them.

The canonical v0.1 design includes Review-5 corrections: prompt-delivery ambiguity is guarded by a persisted `prompt_attempted` stage and prompt digest; authorization pins a non-secret immutable run-config snapshot/digest; task worktree, reviewer clone, and arbiter bundle identities are persisted before external creation and reconciled after crashes; worker status is rechecked after all repository verification commands; cleanup refuses resources referenced by a nonterminal active turn; reviewer isolation is described narrowly as repository/Git-metadata isolation; and the human-facing foreman is reported as an expected session contract unless current-session identity can be independently verified.
