# Mighty Factory canonical documents

As of 2026-09-16, implementation must use these documents:

- Design: `specs/2026-09-16-herdr-software-factory-design-v11.md`
- Implementation plan: `plans/2026-09-16-herdr-software-factory-implementation-v11.md`

All Review-10 and earlier Mighty Factory design/implementation-plan files are historical drafts and are superseded. Do not implement from them.

The canonical v0.1 design includes Review-11 corrections: lease release and lifecycle advance are one atomic state write after archive/outbox finalization; completed archived turns with pending transport cleanup cannot be abandoned into contradictory outcomes; cancellation is folded into that same atomic finalization handoff; and worker verification failures are explicitly separated into repairable implementation failures versus integrity/authority violations that block.
