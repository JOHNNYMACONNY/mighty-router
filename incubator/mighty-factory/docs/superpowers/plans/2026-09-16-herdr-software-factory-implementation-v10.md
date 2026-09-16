# Mighty Factory v0.1 Implementation Plan — Review 10

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans task-by-task. Steps use checkbox syntax.

**Goal:** Implement Review-10 Mighty Factory with immutable authorization, deterministic lifecycle/routing, crash-safe owned resources, prompt-safe turn finalization, protected common Git state, byte-digested evidence, bounded verification, isolated review, escalation caps, and final freshness.

**Architecture:** Luna-Max owns planning/judgment. Exact `/execute` freezes config/task/classification/repository/base identity. The controller owns all later authority and state. Workers use one linked task worktree guarded against shared Git mutation. Reviewers use independent clones. Arbiters receive evidence bundles only.

**Tech Stack:** Node.js >=20, ESM, built-in `node:test`, stdlib only, native Git, Herdr CLI.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-16-herdr-software-factory-design-v10.md`

## Global constraints

- Exact `/execute`; PLAN non-mutating.
- Explicit cancel/abandon semantics from spec.
- No generic transition CLI.
- Freeze config/task/classification/repo/common-Git/base SHA at authorization.
- Deterministic route from classification + durable failure state.
- Roots cannot overlap source/each other.
- Owner marker before external resource mutation.
- State mutation under run lock + process-start identity.
- Prompt attempted before delivery; no blind resend.
- Result -> settled producer -> `finalizing` -> archive digest -> exact outbox deletion -> lease release.
- Active-finalizing crash recovery is idempotent.
- Safe descriptor-based artifact reads, no-follow, <=1MiB results.
- Protect source HEAD/status/refs/common config/hooks; only exact task branch may differ.
- Package verification lifecycle definitions unchanged from base.
- Bounded process-group verification commands.
- Decision evidence canonical/digested, including repair tickets.
- Reviewer PASS cannot contain material findings.
- Final freshness immediately before DONE.
- No implicit merge/push/deploy/production/billing/credential/install/destructive cleanup.

---

### Task 1 — CLI and task/classification schemas

- [ ] RED help lists complete public CLI including cancel/recover/abandon; excludes `transition`.
- [ ] RED task trust/path/check validation.
- [ ] RED classification exact schema/enums/confidence.
- [ ] Implement minimal package/CLI/errors/schemas.
- [ ] Focused/full tests, diff-check, explicit stage/commit.

### Task 2 — Immutable authorization, roots, common Git, gears

Create canonical JSON/config/authorization/environment/route/adapters.

- [ ] RED canonical byte determinism/tamper.
- [ ] RED temp repo at A; after authorization mutate live config/task/classification/main B; pinned values remain A.
- [ ] RED canonical worktree/Git top-level/common Git identity and non-bare requirement.
- [ ] RED root overlap all directions/symlinked ancestors.
- [ ] RED deterministic task branch must not preexist.
- [ ] RED classification routing: normal defaults; high risk REVIEW_STRONG; low confidence/high unresolved ambiguity rejected; second material failure arbiter+WORK_STRONG; third REPLAN_REQUIRED.
- [ ] RED exact specialist gear argv; foreman expectation separate.
- [ ] RED environment secret stripping.
- [ ] Implement/verify/commit.

### Task 3 — Lifecycle, locks, process identity, evidence store

- [ ] RED legal phase transitions from spec; illegal raw transitions rejected.
- [ ] RED cancel no active -> CANCELLED; cancel active -> `cancel_requested`, safe handoff then CANCELLED before verification/new turn/DONE.
- [ ] RED failure counters/stale evidence durable.
- [ ] RED PID absent/live/reused/ambiguous recovery.
- [ ] RED canonical evidence/turn archive digest tamper detection.
- [ ] RED active stages include `finalizing`.
- [ ] Implement atomic state/events/evidence; verify/commit.

### Task 4 — Task worktree and protected source guard

- [ ] RED owner marker before first Git mutation.
- [ ] RED worktree reconciliation matrix including branch-only crash.
- [ ] RED wrong/tampered marker blocks; no alternate identity.
- [ ] RED source may be linked worktree; common config/hooks use pinned common Git dir.
- [ ] RED baseline protects source HEAD/status/all refs except separately tracked task branch/common config/hooks.
- [ ] RED main/other/new ref/config/hooks/source status mutation blocks; task branch expected movement allowed.
- [ ] Implement/commit.

### Task 5 — Safe-file ingest and bounded command runner

- [ ] RED regular bounded JSON accepted/digested.
- [ ] RED symlink path component/final symlink/special/oversize/path escape/unstable descriptor/bad JSON rejected.
- [ ] RED allowed verification forms only; package pre/script/post definition equality.
- [ ] RED timeout default/range.
- [ ] RED process-group grandchild termination on timeout and bounded 16KiB stream tails.
- [ ] Implement/commit.

### Task 6 — Prompt-safe dispatch, settlement, finalizing/outbox recovery

- [ ] RED deterministic workspace/agent reuse after crash.
- [ ] RED prompt attempt persisted before call; ambiguity no resend; definite non-delivery same bytes once.
- [ ] RED result while agent working keeps active lease.
- [ ] RED normal settlement: result ingest -> final snapshot -> turn archive digest -> exact outbox delete -> lease clear -> one transition.
- [ ] RED crash after archive before outbox delete: retry uses existing archive, deletes exact outbox, clears same lease, one transition.
- [ ] RED archive exists/outbox absent/lease active: retry verifies digest then clears/advances once.
- [ ] RED outbox deletion failure leaves stage finalizing, active lease retained, BLOCKED; no conflicting abandonment archive created unless human later explicitly abandons and archive state rules allow only non-completed turn.
- [ ] RED concurrent finalizers idempotent.
- [ ] RED abandon never resends and requires workspace closure proof.
- [ ] Verify/commit.

### Task 7 — Worker verifier

- [ ] RED refuses active/unfinalized/tampered worker archive.
- [ ] RED input/commit/branch/ancestry/path/outbox/diff/source baseline checks.
- [ ] RED task worktree clean after transport outbox finalized.
- [ ] RED package lifecycle rewrite rejected.
- [ ] RED verification dirt/clean commit-reset/source Git mutation/timeout all fail.
- [ ] RED process-group termination proven before final checks.
- [ ] GREEN canonical worker verification digest bound to inputs/archive/source baseline.
- [ ] Implement/commit.

### Task 8 — Reviewer, review verification, repair, arbiter

- [ ] RED reviewer owner marker before clone, independent no-local clone, exact detached commit, no origin, internal common dir, clean pre-launch.
- [ ] RED retry exact adoption only; partial mismatch blocks.
- [ ] RED reviewer request binds worker verification digest.
- [ ] RED reviewer settlement uses same finalizing/outbox deletion state machine.
- [ ] RED PASS+material finding invalid; PASS+minor/info accepted.
- [ ] RED review-verification canonical digest; archive tamper fails.
- [ ] RED record-repair only current validated FAIL, no scope/policy widening, canonical repair digest, tamper detection, next worker binds digest.
- [ ] RED arbiter evidence-only bundle and escalation rules.
- [ ] Implement/commit.

### Task 9 — Controller, final freshness, cleanup, doctor, contracts

- [ ] RED happy path follows exact phase sequence to PASS then freshness -> DONE.
- [ ] RED cancellation during worker/reviewer safe handoff then CANCELLED before verification/verdict/new turn.
- [ ] RED duplicate dispatch/finalization no duplicate effects.
- [ ] RED first review fail repair/default; second arbiter/strong; third stop.
- [ ] RED final freshness detects post-review task HEAD/branch/status or protected source mutation/evidence tamper.
- [ ] RED cleanup refuses active/finalizing/evidence-needed resources; exact owner only; non-force task removal.
- [ ] RED doctor checks Node/Git/Herdr, roots/common Git, serializer, locks/process identity, no-follow, process-group runner, gear routes, reviewer isolation, foreman truthfulness.
- [ ] RED contracts document trusted model/no push-deploy authority/reviewer metadata-only isolation.
- [ ] Wire full public CLI; implement/commit.

### Task 10 — E2E/README/qualification

- [ ] Fake-Herdr + real-temp-Git happy path.
- [ ] E2E regressions: immutable inputs, route rules, cancellation, branch-only resource crash, source Git mutations, prompt ambiguity, finalizing crash windows, stale outbox absence across repair rounds, symlink/oversize, evidence/repair tamper, package script rewrite, process-group timeout, clean HEAD movement, reviewer verdict consistency, final freshness mutations, cleanup guards, PID reuse, escalation cap.
- [ ] README documents lifecycle/routing/cancel/finalizing/recovery/trust/evidence/verification/review/cleanup/qualification.
- [ ] Run full matrix: `npm test`, `npm run test:e2e`, `git diff --check`, CLI help, doctor.
- [ ] Self-review every Review-10 requirement at same HEAD; explicit stage/commit.

## Review gate

Every task: observe RED -> GREEN -> full tests -> diff-check -> inspect status/diff -> explicit stage -> commit -> fresh independent review. Do not batch.

## Qualification

`UNIT_INTEGRATION_COMPLETE` requires full local matrix at one HEAD. `HERDR_RUNTIME_QUALIFIED` additionally requires provider-backed Mac/Herdr proof of installed lifecycle, cancellation, prompt/finalizing recovery, safe artifacts, process-group bounds, Git protection, review, freshness, escalation, and cleanup. Without it, do not claim runtime qualification.
