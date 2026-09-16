# Mighty Factory — Canonical v0.1 Design (Review 11)

**Status:** Canonical implementation contract  
**Date:** 2026-09-16  
**Supersedes:** Review-10 and all earlier Mighty Factory drafts  
**Incubation:** `mighty-router` branch `incubator/mighty-factory-v0` only

## 1. Purpose and trust

Mighty Factory is a trusted-local-repository controller around Herdr. Luna-Max owns conversation, requirements, architecture, and bounded judgment. Deterministic Node.js owns authorization, immutable run inputs, lifecycle, locking, routing, resource reconciliation, evidence integrity, Git protection, verification, review, escalation, cleanup, and DONE.

v0.1 is not an OS/network sandbox. The controller does not authorize merge, push, deploy, production mutation, billing, credential changes, package installation, destructive cleanup, or permission approval.

## 2. Authority and public CLI

PLAN is non-mutating. Only exact `/execute` grants execution authority.

```text
mighty-factory help
mighty-factory doctor
mighty-factory print-config
mighty-factory route
mighty-factory authorize-execute
mighty-factory cancel
mighty-factory recover-run
mighty-factory abandon-turn
mighty-factory prepare-run
mighty-factory dispatch-worker
mighty-factory verify-worker
mighty-factory dispatch-reviewer
mighty-factory verify-review
mighty-factory dispatch-arbiter
mighty-factory record-repair
mighty-factory status
mighty-factory cleanup
```

No generic public transition command.

### Cancellation

- no active turn -> atomic transition to `CANCELLED`,
- active turn -> set `cancel_requested=true`, lease remains,
- active turn may only finish through normal safe finalization,
- its final atomic state update clears the lease and transitions directly to `CANCELLED` instead of the normal next phase,
- no verification/verdict/repair/arbiter/new specialist/DONE after cancellation request.

### Abandonment

`abandon-turn` is human-only for a turn whose prompt/process cannot be safely reconciled **before a completed turn archive exists**. It never resends. It requires exact turn/workspace ownership and proven workspace closure, archives status `abandoned`, then atomically clears lease + transitions `CANCELLED`.

If a valid completed turn archive already exists, `abandon-turn` is rejected. Any remaining transport-cleanup problem must be resolved by resuming `finalizing`/`recover-run`, preserving the completed evidence rather than creating a contradictory abandoned archive.

## 3. Immutable authorization

At `/execute` under one controller transaction:

1. validate config/task/classification/trust,
2. canonicalize source worktree/Git top-level/common Git dir,
3. require non-bare worktree support,
4. pin `base_ref -> base_sha`,
5. reject source/state/temp containment overlap,
6. allocate run/task IDs + deterministic task branch/path; branch must not preexist,
7. normalize config/task/classification; task snapshot embeds canonical Git identity,
8. write canonical exact UTF-8 JSON atomically,
9. SHA-256 exact written bytes,
10. persist all three digests in `run.json`,
11. transition PLAN -> READY after durable success only.

Later commands verify exact bytes before parse and never reread mutable input files.

Canonical JSON recursively sorts keys, preserves arrays, permits finite JSON values only, and has exactly one trailing newline.

## 4. Classification and route

```json
{
  "scope": "tiny|normal|broad|architectural",
  "risk": "low|medium|high",
  "ambiguity": "low|medium|high",
  "change_kind": "question|docs|bugfix|feature|refactor|migration|security",
  "cross_cutting": false,
  "confidence": 0.89
}
```

Factory gears: `ORCH_ESCALATE_1`, `WORK_DEFAULT`, `WORK_STRONG`, `REVIEW_DEFAULT`, `REVIEW_STRONG`.

- normal low/medium -> default worker/reviewer,
- high risk -> REVIEW_STRONG,
- broad/architectural -> approved PLAN must precede exact `/execute`,
- low confidence/high unresolved ambiguity -> authorization rejected until clarified,
- first material review failure -> repair/default worker,
- second -> arbiter/strong worker,
- third -> REPLAN_REQUIRED.

Every launched gear is exact pinned argv. Foreman expectation is separate and only reported verified when introspection proves it.

## 5. Lifecycle

```text
PLAN
READY
PREPARING
WORKING
VERIFYING_WORK
REVIEWING
VERIFYING_REVIEW
REPAIR_PENDING
ESCALATION_PENDING
REPLAN_REQUIRED
BLOCKED
DONE
CANCELLED
```

Core transitions:

```text
PLAN -> READY                     authorize
READY -> PREPARING                prepare
PREPARING -> WORKING              task resource + source baseline ready
WORKING -> VERIFYING_WORK         atomic completed worker finalization
VERIFYING_WORK -> REVIEWING       verification PASS
VERIFYING_WORK -> REPAIR_PENDING  repairable verification FAIL
VERIFYING_WORK -> BLOCKED         integrity/authority violation
REVIEWING -> VERIFYING_REVIEW     atomic completed reviewer finalization
VERIFYING_REVIEW -> DONE          PASS + freshness
VERIFYING_REVIEW -> REPAIR_PENDING first material review FAIL
VERIFYING_REVIEW -> ESCALATION_PENDING second material review FAIL
VERIFYING_REVIEW -> REPLAN_REQUIRED third material review FAIL
REPAIR_PENDING -> WORKING         canonical repair accepted
ESCALATION_PENDING -> WORKING     arbiter completed + strong route selected
any nonterminal -> BLOCKED         unrecoverable integrity/recovery ambiguity
```

Illegal transitions are rejected. Counters/stale flags are durable.

### Verification failure taxonomy

Repairable examples:

- project test/lint/typecheck failure,
- implementation defect inside immutable authorized scope where repository integrity remains intact.

Integrity/authority violations are **not** auto-repaired and transition BLOCKED, including:

- input/evidence digest mismatch,
- protected source ref/config/hooks/source-worktree mutation,
- unsafe/mismatched artifact,
- forbidden committed path/scope breach,
- unexpected Git identity/branch/worktree mismatch,
- verification subprocess group cannot be proven terminated.

## 6. Ownership, locking, safe files

Every task/review/arbiter parent gets a canonical byte-digested owner marker before external mutation. Adoption/deletion requires exact marker digest.

Every state change is run-locked with nonce, PID, process-start token, controller-instance ID, timestamp, command. Recovery distinguishes PID reuse; ambiguous identity fails closed; no force clear.

Externally produced JSON is read descriptor-safely: owned-root containment, no symlink components, final no-follow open on target macOS, regular-file `fstat`, result <=1 MiB, bounded descriptor read, stable pre/post identity+size, then JSON/schema/IDs validation and exact-byte digest/copy.

## 7. Turn dispatch and prompt ambiguity

Active stages:

```text
claimed
workspace_ready
agent_started
prompt_attempted
result_seen
settling
finalizing
```

Persist turn/workspace/agent identity, pinned gear, request, prompt bytes/digest, expected result path before external mutation. `prompt_attempted` is durable before prompt call. Definite non-delivery may resend exact prompt once; ambiguous delivery never blindly resends.

A result file never completes a turn; producer must settle first.

## 8. Atomic crash-safe finalization

Once producer is settled:

1. lock run, set `finalizing`,
2. safely ingest result,
3. capture role final snapshot/integrity with source outbox present,
4. write canonical completed turn archive + persist archive digest,
5. delete only exact ingested source outbox,
6. verify exact deletion/no unrelated delta,
7. perform **one atomic state write** that:
   - records archive digest/finalization evidence,
   - clears `active_turn`,
   - increments revision,
   - transitions to normal next phase **or directly CANCELLED if `cancel_requested`**.

There is no durable state where the lease is cleared but the old phase remains.

Crash/retry:

- no archive -> resume ingest/snapshot/archive,
- valid completed archive + outbox exists -> retry exact deletion only,
- valid completed archive + outbox absent + active turn still `finalizing` -> perform the one atomic clear+transition state write,
- archive digest mismatch -> BLOCKED,
- delete failure/ambiguity -> BLOCKED with completed archive + active `finalizing` lease retained; operator may correct filesystem permissions/state and `recover-run`, but may **not** abandon this completed archived turn,
- concurrent finalizers converge on one archive and one atomic state transition.

## 9. Evidence chain and repair

Every decision-bearing evidence object is canonical exact-byte SHA-256 evidence:

```text
worker archive -> worker verification -> reviewer request
-> reviewer archive -> review verification
-> repair ticket (FAIL) -> arbiter evidence/result (if escalated)
-> final freshness
```

`record-repair` accepts only current validated FAIL, cannot widen immutable scope/path/policy, writes/digests bounded repair evidence, and next worker request binds its digest.

## 10. Task worktree and protected source

Task owner marker precedes Git mutation. Reconcile exact deterministic branch/path only; branch-only crash may attach existing valid unattached branch; incompatible/foreign state BLOCKS; never invent alternate identity.

Pinned canonical `git_common_dir` is used even when source itself is linked worktree.

Protected baseline after task prep/before first worker:

- source worktree HEAD/status,
- all refs except exact task branch,
- task branch OID separately,
- common config exact bytes,
- common hooks deterministic tree digest.

Each protected check requires source HEAD/status, all protected refs, config, hooks unchanged; no new refs except task branch; task branch exact expected commit. Mismatch BLOCKS with no auto reset.

## 11. Verification policy and bounded process groups

Allowed forms: `npm-script`, `pnpm-script`, `yarn-script`, `node-test`, `node-check`. No arbitrary shell/binary/install/migrate/deploy/destructive Git.

Package `pre<script>/<script>/post<script>` definitions at reported commit must equal pinned base definitions.

Timeout pinned per command: default 10 minutes, config 1–30. Runner uses no shell, own process group/session on target macOS, 16 KiB stdout/stderr tail buffers, terminates whole group on timeout, bounded grace then group kill, and proves group termination before final Git checks. Failure to prove termination is BLOCKED.

## 12. Worker verification

Requires finalized completed worker archive digest and no active lease.

Order:

1. run-input digests,
2. archive digest/correlation,
3. task HEAD + task branch == reported commit,
4. base ancestry,
5. committed paths/outbox,
6. protected-source baseline,
7. `git diff --check`,
8. clean task worktree after transport deletion,
9. package lifecycle integrity,
10. bounded sanitized checks,
11. group termination proof,
12. recheck task HEAD/branch,
13. clean final status,
14. protected-source baseline,
15. canonical verification evidence digest.

Repairable project-check failures route REPAIR_PENDING. Integrity failures route BLOCKED per §5.

## 13. Reviewer and review verification

Reviewer uses ownership-marked independent `git clone --no-local --no-checkout`, exact detached verified commit, origin removed, internal common Git dir, clean pre-launch status. Request binds worker-verification digest.

Reviewer turn uses the same settled/finalizing/atomic-clear protocol. Review verification checks archive digest, commit, bound verification digest, finding/verdict schema, and writes digested evidence.

PASS may contain only explicitly non-material minor/informational findings. Any BLOCKER/IMPORTANT/material finding requires FAIL; contradictory PASS is invalid evidence -> BLOCKED.

## 14. Arbiter/escalation

Arbiter gets ownership-marked evidence bundle only: immutable task summary/scope, classification, commit/evidence/repair digests, findings/history, question. No checkout/source paths/remotes/.git/secrets.

First material FAIL repair/default; second arbiter + WORK_STRONG; third REPLAN_REQUIRED.

## 15. Final freshness and DONE

Immediately before DONE under run lock:

1. verify all immutable input/evidence digests,
2. no active turn/cancellation/stale evidence,
3. exact task worktree HEAD == verified commit,
4. exact task branch == verified commit,
5. task worktree clean,
6. protected source HEAD/status/refs/common config/hooks equal baseline except task branch at verified commit,
7. retry/escalation policy satisfied.

Then one atomic transition to DONE. DONE is point-in-time, not permanent external-mutation prevention.

## 16. Cleanup

Only exact valid-owner resources; never active/finalizing resources; never evidence-needed resources before digests exist. Task worktree removal requires terminal run + explicit authority, uses native Git without force, branch retained unless separately authorized.

## 17. Qualification

Doctor is non-mutating and checks Node/Git/Herdr, config/gears/routing, roots/common Git, serializer, state/temp writability, lock/process identity, no-follow support, sanitizer, process-group runner, reviewer isolation, foreman truthfulness.

`UNIT_INTEGRATION_COMPLETE`: complete local matrix at one HEAD.

`HERDR_RUNTIME_QUALIFIED`: additionally provider-backed Mac/Herdr smoke proof of lifecycle/cancel, prompt/finalization recovery, artifacts, process groups, source protection, review, freshness, escalation, cleanup.

## 18. Review-11 corrections

1. Lease clear and phase transition are one atomic state write after completed archive + exact outbox deletion.
2. Completed archived turns with pending transport cleanup cannot be abandoned into a contradictory archive; recovery resumes finalization instead.
3. Cancellation is integrated into the same atomic finalization write, transitioning directly to CANCELLED after safe handoff.
4. Verification failures are explicitly split into repairable implementation failures vs integrity/authority violations that BLOCK.

## 19. Deferred

OS/container sandboxing; guaranteed network isolation; model catalog/usage pricing; parallel workers; auto merge/push/deploy; web/remote orchestration; raw socket subscription; UAL integration; autonomous PLAN->EXECUTE; automatic permission approval.
