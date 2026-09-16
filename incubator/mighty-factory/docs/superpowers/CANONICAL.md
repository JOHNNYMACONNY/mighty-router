# Mighty Factory canonical documents

As of 2026-09-16, implementation must use these documents:

- Design: `specs/2026-09-16-herdr-software-factory-design-v7.md`
- Implementation plan: `plans/2026-09-16-herdr-software-factory-implementation-v7.md`

All Review-6 and earlier Mighty Factory design/implementation-plan files are historical drafts and are superseded. Do not implement from them.

The canonical v0.1 design includes Review-7 corrections: protected source worktree/refs/config/hooks baselines for linked-worker safety; verification rechecks HEAD/task-branch identity after repository commands; package-script lifecycle definitions used for verification are pinned to the authorized base; turn/review/verification evidence is exact-byte digested; outbox artifacts must be bounded regular files and cannot be symlinks; Factory roots cannot overlap the source repository or each other; the task-resource parent is ownership-marked before Git mutation; and concurrent settlement is idempotent.
