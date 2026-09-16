# Mighty Factory canonical documents

As of 2026-09-16, implementation must use these documents:

- Design: `specs/2026-09-16-herdr-software-factory-design-v10.md`
- Implementation plan: `plans/2026-09-16-herdr-software-factory-implementation-v10.md`

All Review-9 and earlier Mighty Factory design/implementation-plan files are historical drafts and are superseded. Do not implement from them.

The canonical v0.1 design includes Review-10 corrections: explicit cancellation semantics and the full deterministic lifecycle/routing contract are restored; the public CLI contract is complete; and specialist settlement now has a crash-safe `finalizing` stage so archive creation, exact outbox deletion, active-lease release, and the resulting lifecycle transition are resumable and idempotent.
