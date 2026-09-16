# Mighty Factory canonical documents

As of 2026-09-16, implementation must use these documents:

- Design: `specs/2026-09-16-herdr-software-factory-design-v4.md`
- Implementation plan: `plans/2026-09-16-herdr-software-factory-implementation-v4.md`

All Review-3 and 2026-09-15 Mighty Factory design/implementation-plan files are historical drafts and are superseded. Do not implement from them.

The canonical v0.1 design includes Review-4 corrections: crash-resumable deterministic specialist launch identity, explicit stale-lock recovery, trusted-repository execution instead of a false sandbox claim, sanitized subprocess environments, independent reviewer clones with `origin` removed, isolated arbiter evidence bundles, deterministic cancellation around active turns, correct `git diff --check` semantics, and cleanup through exact Factory-owned Herdr/Git/filesystem resources without force by default.
