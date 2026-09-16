# Mighty Factory canonical documents

As of 2026-09-16, implementation must use these documents:

- Design: `specs/2026-09-16-herdr-software-factory-design-v3.md`
- Implementation plan: `plans/2026-09-16-herdr-software-factory-implementation-v3.md`

The 2026-09-15 Mighty Factory design and implementation-plan files are historical drafts and are superseded. Do not implement from them.

The canonical v0.1 design includes the third-review corrections: enforced `allowed_paths`, no generic public transition command, atomic run locking plus `active_turn`, no Git ignore-metadata mutation for outboxes, safe structured verification commands only, controller-owned `base_sha..commit` diff checking, full reviewer tracked/untracked immutability, explicit staging of new files, and bounded cleanup of Factory-owned resources only.
