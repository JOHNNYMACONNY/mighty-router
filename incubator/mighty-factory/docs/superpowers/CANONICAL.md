# Mighty Factory canonical documents

As of 2026-09-16, implementation must use these documents:

- Design: `specs/2026-09-16-herdr-software-factory-design-v8.md`
- Implementation plan: `plans/2026-09-16-herdr-software-factory-implementation-v8.md`

All Review-7 and earlier Mighty Factory design/implementation-plan files are historical drafts and are superseded. Do not implement from them.

The canonical v0.1 design includes Review-8 corrections: a final freshness gate rechecks task HEAD/branch/status and protected source state immediately before DONE; repair tickets are canonical byte-digested evidence; artifact ingestion uses no-follow descriptor-based reads with symlink-component rejection; verification subprocesses have pinned timeouts and bounded streaming output; only the exact Factory task branch may newly appear/move in protected refs; ownership-marker bytes are digested; and review verification is an explicit digested evidence step.
