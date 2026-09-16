# Mighty Factory canonical documents

As of 2026-09-16, implementation must use these documents:

- Design: `specs/2026-09-16-herdr-software-factory-design-v9.md`
- Implementation plan: `plans/2026-09-16-herdr-software-factory-implementation-v9.md`

All Review-8 and earlier Mighty Factory design/implementation-plan files are historical drafts and are superseded. Do not implement from them.

The canonical v0.1 design includes Review-9 corrections: protected Git metadata is resolved through the canonical common Git directory; the protected-ref baseline tracks the Factory task branch separately; exact ingested outboxes are removed only after durable archive/final snapshots so repair rounds stay clean; verification timeouts terminate the entire spawned process group before final checks; reviewer PASS is invalid when material findings are present; and DONE is explicitly a point-in-time freshness assertion rather than a permanent external-mutation guarantee.
