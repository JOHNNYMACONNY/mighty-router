# Mighty Factory v0.1 Implementation Plan — Review 11

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans task-by-task.

**Goal:** Implement Review-11 Mighty Factory with immutable authorization, deterministic lifecycle/routing, crash-safe resources, prompt-safe settled turns, atomic finalization, protected common Git state, digested evidence, bounded verification, isolated review, escalation caps, and final freshness.

**Architecture:** Luna-Max owns planning/judgment. Exact `/execute` freezes all run-defining inputs. The controller owns all later authority/state. Workers use a linked task worktree guarded against shared Git mutation. Reviewers use independent clones; arbiters get evidence bundles only.

**Tech Stack:** Node.js >=20, ESM, `node:test`, stdlib only, native Git, Herdr CLI.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-16-herdr-software-factory-design-v11.md`

## Global constraints

- Exact `/execute`; PLAN non-mutating.
- Full public CLI from spec; no generic transition.
- Explicit cancel/abandon semantics.
- Freeze config/task/classification/source/common-Git/base SHA at authorization.
- Deterministic route from classification + durable failure state.
- State/temp/source roots non-overlapping.
- Owner marker before external mutation.
- Run lock + process-start identity.
- Prompt attempt persisted before delivery; ambiguity never blindly resent.
- Result requires producer settlement.
- Finalization is archive -> exact outbox deletion -> **single atomic** archive-record/lease-clear/phase-transition state write.
- Completed archived turn pending outbox cleanup cannot be abandoned; recover finalization instead.
- Safe descriptor no-follow artifact reads.
- Protect source HEAD/status/refs/common config/hooks; only task branch may differ.
- Verification subprocesses bounded by process-group timeout/output caps.
- Package verification lifecycle definitions unchanged from base.
- Decision evidence canonical/digested including repair tickets.
- Integrity/authority violations BLOCK; only implementation/project-check failures may route repair.
- Reviewer PASS cannot contain material findings.
- Final freshness immediately before DONE.
- No implicit merge/push/deploy/production/billing/credentials/install/destructive cleanup.

---

### Task 1 — CLI, task and classification schemas
- [ ] RED complete command surface; no transition.
- [ ] RED task trust/path/check validation.
- [ ] RED exact classification schema.
- [ ] Implement package/CLI/errors/schemas.
- [ ] Focused/full tests, diff-check, explicit commit.

### Task 2 — Immutable authorization, roots, route/gears
- [ ] RED canonical JSON/tamper.
- [ ] RED pin repo/common-Git/base A; live config/task/classification/main mutation after auth cannot alter run.
- [ ] RED reject bare repo/root overlap/preexisting deterministic task branch.
- [ ] RED routing defaults/high-risk strong review/ambiguity rejection/failure escalation cap.
- [ ] RED exact specialist argv and foreman separation.
- [ ] RED env sanitizer.
- [ ] Implement/commit.

### Task 3 — Lifecycle, locks, process identity, evidence
- [ ] RED all legal/illegal phase transitions.
- [ ] RED cancel with/without active turn and cancellation gate before any later mutation.
- [ ] RED failure counters/stale evidence.
- [ ] RED PID reuse/ambiguous stale lock recovery.
- [ ] RED canonical turn/evidence digest tamper detection.
- [ ] RED active stages through `finalizing`.
- [ ] Implement atomic state/events/evidence; commit.

### Task 4 — Task worktree and protected source baseline
- [ ] RED owner marker before Git mutation.
- [ ] RED deterministic resource reconciliation including branch-only crash.
- [ ] RED linked-source common Git path handling.
- [ ] RED source HEAD/status/protected refs/task branch/common config/hooks baseline.
- [ ] RED protected mutations BLOCK.
- [ ] Implement/commit.

### Task 5 — Safe artifact reader and bounded command runner
- [ ] RED regular bounded JSON ingest/digest.
- [ ] RED symlink component/final symlink/special/oversize/path escape/unstable descriptor rejection.
- [ ] RED allowed verification forms + package pre/script/post equality.
- [ ] RED timeout bounds + process-group grandchild termination + 16KiB tail buffers.
- [ ] Implement/commit.

### Task 6 — Dispatch, settlement, atomic finalization, recovery, abandonment
- [ ] RED deterministic agent/workspace crash reuse.
- [ ] RED prompt attempt before call and ambiguity rules.
- [ ] RED result-before-settlement leaves lease active.
- [ ] RED normal finalization writes archive, removes exact outbox, then one atomic state write clears lease + advances phase.
- [ ] RED cancel-requested finalization atomically clears lease + goes directly CANCELLED.
- [ ] RED crash after archive before outbox delete resumes exact deletion then one atomic state transition.
- [ ] RED crash after outbox delete before atomic state write resumes using archive/outbox absence then one state transition.
- [ ] RED deletion failure keeps finalizing active lease/BLOCKED; completed archive forbids abandon-turn.
- [ ] RED abandon allowed only before completed archive and requires workspace closure proof.
- [ ] RED concurrent finalizers produce one archive/transition.
- [ ] Implement/commit.

### Task 7 — Worker verification and failure taxonomy
- [ ] RED finalized archive/no-active-turn required.
- [ ] RED input/commit/branch/ancestry/path/diff/source checks.
- [ ] RED package script rewrite.
- [ ] RED verification dirt/clean commit-reset/source mutation/timeout/process-group ambiguity.
- [ ] RED project test failure with intact integrity -> repairable result.
- [ ] RED digest mismatch/protected source mutation/unsafe artifact/forbidden path/Git identity mismatch/group termination ambiguity -> integrity violation BLOCK classification.
- [ ] GREEN verification artifact digest bound to inputs/archive/source baseline.
- [ ] Implement/commit.

### Task 8 — Reviewer, review verification, repair, arbiter
- [ ] RED independent clean reviewer clone/no origin/internal common dir.
- [ ] RED reviewer request binds worker verification digest.
- [ ] RED reviewer uses same atomic finalization protocol.
- [ ] RED contradictory PASS+material finding BLOCK.
- [ ] RED digested review-verification/tamper rejection.
- [ ] RED canonical repair current-FAIL only/no scope widening/digest binding.
- [ ] RED evidence-only arbiter + second-failure strong worker/third stop.
- [ ] Implement/commit.

### Task 9 — Controller, final freshness, cleanup, doctor, contracts
- [ ] RED happy phase sequence to freshness then DONE.
- [ ] RED cancellation during worker/reviewer finalization goes CANCELLED and prevents later verification/verdict.
- [ ] RED repairable vs integrity failure routing.
- [ ] RED duplicate dispatch/finalization idempotence.
- [ ] RED final freshness detects post-review task/source/evidence mutation.
- [ ] RED cleanup refuses active/finalizing/evidence-needed resources; exact owner only; no-force task removal.
- [ ] RED doctor checks lifecycle routes, roots/common Git, serializer, process identity, no-follow, bounded group runner, reviewer isolation, foreman truthfulness.
- [ ] Wire full CLI and prompts/skill; commit.

### Task 10 — E2E, README, qualification
- [ ] Fake-Herdr + real-temp-Git happy path.
- [ ] E2E immutable inputs, routing, cancel, partial resource crash, source protection, prompt ambiguity, both finalizing crash windows, completed-archive abandonment rejection, stale outbox absence, artifact safety, evidence tamper, package script rewrite, process-group timeout, repairable-vs-integrity routing, reviewer verdict consistency, final freshness, cleanup guards, PID reuse, escalation cap.
- [ ] README documents Review-11 semantics.
- [ ] Run full matrix: `npm test`, `npm run test:e2e`, `git diff --check`, CLI help, doctor.
- [ ] Self-review every spec requirement at same HEAD; explicit stage/commit.

## Review gate

Every task: RED -> GREEN -> full tests -> diff-check -> inspect diff/status -> explicit stage -> commit -> fresh independent review. Do not batch.

## Qualification

`UNIT_INTEGRATION_COMPLETE` requires the full local matrix at one HEAD. `HERDR_RUNTIME_QUALIFIED` additionally requires provider-backed Mac/Herdr proof of lifecycle/cancel, prompt/finalization recovery, artifact safety, process-group termination, Git protection, reviewer behavior, freshness, escalation, and cleanup. Without it, do not claim runtime qualification.
