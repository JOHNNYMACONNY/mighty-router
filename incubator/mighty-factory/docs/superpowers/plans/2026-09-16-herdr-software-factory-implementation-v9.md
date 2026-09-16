# Mighty Factory v0.1 Implementation Plan — Review 9

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans task-by-task. Steps use checkbox syntax.

**Goal:** Implement Review-9 Mighty Factory with immutable authorization, owned crash-safe resources, protected common Git state, prompt-safe settled turns, byte-digested evidence, bounded verification subprocesses, isolated review, escalation caps, and a final freshness gate.

**Architecture:** Luna-Max owns planning/judgment. Exact `/execute` freezes config/task/classification/repository/base identity. Controller owns all later authority. Workers use a linked task worktree guarded against shared Git side effects. Reviewers use independent clones; arbiters use evidence bundles only.

**Tech Stack:** Node.js >=20, ESM, `node:test`, built-in stdlib only, native Git, Herdr CLI.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-16-herdr-software-factory-design-v9.md`

## Global constraints

- No runtime npm deps.
- Trusted-local-repository only; not sandboxed.
- No generic transition CLI.
- Freeze all decision-bearing run inputs at authorization.
- Roots non-overlapping with source and each other.
- Owner marker before every external resource mutation.
- Run lock + process-start identity for state mutation/recovery.
- Prompt attempt persisted before delivery; no blind resend.
- Result requires producer settlement, durable archive+digest, exact outbox removal, then lease release.
- Safe-file reader rejects symlink components/final symlink/special/oversized artifacts.
- Protect source HEAD/status/refs/common config/hooks; only exact task branch may differ.
- Package verification lifecycle definitions must equal base definitions.
- Verification subprocesses run bounded process groups with time/output limits.
- Repair/review/turn/verification evidence exact-byte digested.
- Reviewer PASS cannot contain material findings.
- Final freshness immediately precedes DONE.
- No implicit merge/push/deploy/production/billing/credentials/install/destructive cleanup.

---

### Task 1 — CLI and schemas

Create package/bin/CLI/errors/task/classification validators and tests.

- [ ] RED help requires all high-level commands including `abandon-turn`, excludes `transition`.
- [ ] RED task trust/path/verification validation.
- [ ] RED exact classification enums/confidence.
- [ ] Implement minimal scaffold.
- [ ] Focused/full tests, diff-check, explicit stage/commit.

### Task 2 — Immutable authorization and root/common-Git identity

Create canonical JSON, config, authorization, environment, routing, provider adapters, tests.

- [ ] RED canonical byte determinism/tamper detection.
- [ ] RED authorize temp repo at A, then mutate live inputs and main B; pinned snapshots/base remain A.
- [ ] RED resolve canonical source root + `git rev-parse --git-common-dir`; store canonical common Git path.
- [ ] RED reject bare repo, root overlap in all directions, symlinked-overlap cases, preexisting deterministic task branch.
- [ ] RED concrete specialist gear argv; foreman expectation separate.
- [ ] RED sanitizer strips synthetic secret.
- [ ] Implement and commit.

### Task 3 — Locks, lifecycle, evidence and turn archives

Create process identity, lock, state machine/store, evidence store, turn archive, tests.

- [ ] RED PID absent/live/reused/ambiguous cases.
- [ ] RED nonce+process identity recovery; no force clear.
- [ ] RED cancel/review-failure transitions and active stages.
- [ ] RED turn archive exact-byte digest/tamper rejection.
- [ ] RED no lease clear without matching archive; concurrent settlement idempotent.
- [ ] Implement atomic state/evidence/events and commit.

### Task 4 — Task resource + source guard

Create Git/resource/source-guard/artifact helpers and tests.

- [ ] RED task owner marker durable before first `git worktree` mutation.
- [ ] RED branch/path reconciliation matrix including branch-created/no-worktree crash.
- [ ] RED wrong/tampered marker blocks.
- [ ] RED source may itself be linked worktree; common config/hooks are taken from canonical common Git dir.
- [ ] RED baseline map excludes exact task branch and stores its OID separately.
- [ ] RED main/other/new ref, source checkout, common config, hooks changes fail.
- [ ] RED only exact task branch at expected commit allowed.
- [ ] Implement/commit.

### Task 5 — Safe-file ingest + verification runner policy

Create artifact-ingest, verification-policy, command-runner, tests.

- [ ] RED safe regular JSON descriptor ingest/digest.
- [ ] RED parent symlink, final symlink, dir/FIFO/special, oversize, path escape, unstable fstat, malformed JSON/IDs reject.
- [ ] RED allowed verification forms only.
- [ ] RED package `pre/script/post` base-vs-reported equality.
- [ ] RED timeout config default 10min/range 1–30min.
- [ ] RED subprocess created as killable process group; timeout terminates group, waits grace, force-kills group if needed; grandchildren fixture cannot survive.
- [ ] RED stdout/stderr bounded streaming 16KiB tails.
- [ ] Implement/commit.

### Task 6 — Worker settlement/outbox lifecycle/verifier

Create turn-launcher/recovery/verifier and tests.

- [ ] RED prompt attempt before external call; ambiguity no resend; definite non-delivery bounded one resend.
- [ ] RED result while producer working keeps active lease.
- [ ] RED settlement captures final task status, ingests result, archives/digests, then deletes exact outbox only; failed deletion BLOCKS before lease release/verification.
- [ ] RED two repair worker turns leave no stale prior outbox.
- [ ] RED verifier refuses active/tampered archive.
- [ ] RED HEAD/branch/ancestry/path/diff/source baseline checks.
- [ ] RED package script rewrite rejected.
- [ ] RED verification dirt/new clean commit/reset/source Git mutation/timeout all fail.
- [ ] GREEN verification artifact canonical/digested and bound to run inputs/archive/source baseline.
- [ ] Implement/commit.

### Task 7 — Reviewer and review verification

Create reviewer clone/guard/verifier, tests.

- [ ] RED marker before clone, exact independent no-local clone, detached commit, origin removed, common dir internal, clean pre-launch.
- [ ] RED retry exact adoption only; partial/wrong marker/head/origin blocks.
- [ ] RED reviewer request binds worker verification digest.
- [ ] RED settlement integrity allows only exact outbox, then durable archive/digest + exact outbox removal.
- [ ] RED `PASS` + BLOCKER/IMPORTANT/material finding invalid; PASS + explicit minor/info only accepted.
- [ ] RED review-verification artifact canonical/digested; archive tamper fails.
- [ ] Implement/commit.

### Task 8 — Repair evidence, arbiter, controller loop

Create repair, arbiter-bundle, controller, tests.

- [ ] RED record-repair only current validated FAIL; no immutable scope/path/policy widening; canonical repair digest; later file tamper rejected.
- [ ] RED next worker request binds exact repair digest.
- [ ] RED arbiter marker precedes bundle; evidence-only bundle omits paths/remotes/secrets/.git and binds digests.
- [ ] RED happy path to PASS-ready state.
- [ ] RED first fail repair/default worker; second arbiter/strong worker; third REPLAN_REQUIRED.
- [ ] RED cancel/abandon/recovery paths.
- [ ] Implement/commit.

### Task 9 — Final freshness, cleanup, doctor, contracts

Create freshness, cleanup, doctor, prompts/skill, tests.

- [ ] RED final freshness after reviewer PASS detects task branch move, task HEAD move, task dirt, main/other/new ref change, source checkout/config/hooks change, input/evidence tamper.
- [ ] RED final freshness PASS only then DONE.
- [ ] RED cleanup refuses active or evidence-needed resources; only exact valid owner markers; no force worktree removal; branch retained.
- [ ] RED doctor checks roots/common-Git, serializer, locks/process identity, no-follow support, process-group runner, Herdr, concrete gears, reviewer isolation, foreman truthfulness.
- [ ] Contracts state trust limits/no push-deploy authority/reviewer Git-metadata-only isolation.
- [ ] Wire all CLI commands and commit.

### Task 10 — E2E/README/qualification

- [ ] Real-temp-Git + fake-Herdr happy path.
- [ ] E2E all regressions: immutable inputs; common-dir/root rules; partial task resource; source baseline; outbox cleanup across repairs; prompt ambiguity; settlement; symlink/oversize; archive/repair tamper; package script rewrite; process-group timeout with grandchild; clean HEAD movement; contradictory reviewer PASS; post-review freshness mutation; reviewer isolation; cleanup guard; PID reuse; escalation cap.
- [ ] README documents Review-9 semantics.
- [ ] Run `npm test`, `npm run test:e2e`, `git diff --check`, CLI help, doctor.
- [ ] Self-review spec coverage at one HEAD; explicit stage/commit.

## Review gate

Every task: observe RED -> GREEN -> full tests -> diff-check -> inspect status/diff -> explicit stage -> commit -> fresh independent review. Do not batch tasks.

## Qualification

`UNIT_INTEGRATION_COMPLETE` requires full local matrix at one HEAD. `HERDR_RUNTIME_QUALIFIED` additionally requires disposable provider-backed Mac/Herdr smoke coverage of settlement, no-follow artifact safety, process-group timeout behavior, common Git protection, final freshness, escalation, and cleanup. Without it, do not claim runtime qualification.
