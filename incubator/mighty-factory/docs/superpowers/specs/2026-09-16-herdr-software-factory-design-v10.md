# Mighty Factory — Canonical v0.1 Design (Review 10)

**Status:** Canonical design for implementation  
**Date:** 2026-09-16  
**Supersedes:** Review-9 and all earlier Mighty Factory drafts  
**Incubation:** `mighty-router` branch `incubator/mighty-factory-v0` only

## 1. Purpose and trust model

Mighty Factory is a local Herdr-backed software-factory controller. The human-facing Codex/Luna-Max session owns conversation, requirements, architecture, and bounded judgment. Deterministic Node.js code owns authorization, immutable run inputs, lifecycle, locking, routing, resource reconciliation, evidence integrity, Git protection, verification, review, escalation, cleanup, and DONE.

v0.1 supports only `execution_trust: "trusted-local-repository"`. It is **not** an OS/network security sandbox. Provider CLIs and repository code execute with the user's OS permissions. The controller never authorizes merge, push, deploy, production mutation, billing, credentials changes, package installation, destructive cleanup, or permission approval, but cannot prove an unsandboxed process never caused an external side effect.

## 2. PLAN / EXECUTE / CANCEL / ABANDON authority

PLAN is non-mutating and launches no specialist. Only exact `/execute` grants execution authority.

Public high-level CLI:

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

There is no public generic `transition` command.

### 2.1 Cancellation

- if `active_turn == null`, `/cancel` transitions immediately to `CANCELLED`,
- if an active turn exists, set `cancel_requested: true`; do not erase the lease,
- the already-claimed turn may finish only through the normal safe settlement/archive handoff,
- after that handoff, before worker verification, reviewer verdict application, repair, arbiter, cleanup mutation, or another specialist launch, transition to `CANCELLED`,
- no DONE transition is legal while `cancel_requested` is true.

### 2.2 Human-only abandonment

`abandon-turn --run <run_id> --turn <turn_id>` is for unrecoverable active-turn ambiguity. It never resends a prompt. It locks the run, requires exact active-turn match, closes only the recorded Factory-owned workspace, proves closure/absence, archives status `abandoned`, clears the lease, preserves filesystem evidence, and transitions to `CANCELLED`. If closure cannot be proven, remain `BLOCKED` with lease retained.

## 3. Immutable authorization manifest

At `/execute`, one controller transaction:

1. validate config/task/classification and trust mode,
2. canonicalize target worktree root and Git top-level,
3. resolve/canonicalize `git rev-parse --git-common-dir`,
4. require non-bare worktree support,
5. pin `base_ref -> base_sha`,
6. reject overlap among source repo, `state_root`, and `temp_root` in either containment direction,
7. allocate run/task IDs and deterministic task branch/path; branch must not preexist,
8. normalize config/task/classification; task snapshot embeds canonical repo/common-Git/base identity,
9. write canonical exact UTF-8 JSON bytes atomically,
10. SHA-256 exact written bytes,
11. persist three input digests and immutable Git identity in `run.json`,
12. transition PLAN -> READY only after durable success.

Canonical files:

```text
config.snapshot.json
task.snapshot.json
classification.snapshot.json
run.json
```

Later commands hash exact snapshot bytes before parse and never reread mutable source inputs.

Canonical JSON recursively sorts object keys, preserves array order, accepts finite JSON values only, and ends with exactly one newline.

## 4. Classification and deterministic routing

Classification schema:

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

Routing code, not prompts, maps classification + durable failure state to named gears.

Factory-launched gears:

```text
ORCH_ESCALATE_1
WORK_DEFAULT
WORK_STRONG
REVIEW_DEFAULT
REVIEW_STRONG
```

Rules:

- low/medium normal work -> WORK_DEFAULT + REVIEW_DEFAULT,
- high risk -> REVIEW_STRONG,
- broad/architectural requires approved plan before execution,
- low confidence or high unresolved ambiguity rejects authorization/execution until clarified,
- first material review failure -> repair + normally WORK_DEFAULT,
- second material review failure -> ORCH_ESCALATE_1 arbiter + WORK_STRONG,
- third material review failure -> REPLAN_REQUIRED; no automatic fourth attempt.

Every Factory gear resolves to exact non-secret argv inside pinned config. Human foreman is separate `foreman_expected`; `current-session-verified` may be reported only when supported introspection proves it.

## 5. Deterministic lifecycle

Phases:

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

Representative legal transitions:

```text
PLAN -> READY                  validated authorize-execute
READY -> PREPARING             prepare-run begins
PREPARING -> WORKING           owned task worktree + protected baseline ready
WORKING -> VERIFYING_WORK      worker turn settled/archived/outbox finalized
VERIFYING_WORK -> REVIEWING    worker verification PASS
VERIFYING_WORK -> REPAIR_PENDING worker verification FAIL requiring repair
REVIEWING -> VERIFYING_REVIEW  reviewer turn settled/archived/outbox finalized
VERIFYING_REVIEW -> DONE       review PASS + final freshness gate
VERIFYING_REVIEW -> REPAIR_PENDING first material review FAIL
VERIFYING_REVIEW -> ESCALATION_PENDING second material review FAIL
VERIFYING_REVIEW -> REPLAN_REQUIRED third material review FAIL
REPAIR_PENDING -> WORKING      canonical repair accepted, stale evidence invalidated
ESCALATION_PENDING -> WORKING  arbiter settled/archived and strong-worker route selected
nonterminal/no active turn -> CANCELLED on cancel
nonterminal/active turn -> cancel_requested on cancel; CANCELLED after safe handoff
any nonterminal -> BLOCKED      hard/recovery ambiguity
```

Illegal transitions are rejected. Failure counters and stale-evidence flags live in state, never chat memory.

## 6. Ownership, locks, safe files

Every task/review/arbiter parent gets a canonical owner marker written and byte-digested before external mutation. Adoption/deletion requires exact marker bytes/digest.

Every state-changing command uses exclusive per-run lock metadata: nonce, PID, platform process-start token, controller-instance ID, time, command. Recovery requires nonce + process identity; PID reuse is distinguished by start token; ambiguous probe fails closed; no force-clear CLI.

Externally produced JSON is read via no-follow descriptor safety:

- lexical containment under owned root,
- reject symlink path components,
- final `O_NOFOLLOW` on target macOS,
- regular-file `fstat`,
- turn-result max 1 MiB,
- bounded descriptor read with stable pre/post identity+size,
- captured bytes parsed as UTF-8 JSON,
- schema/IDs/commit checked,
- exact bytes hashed and atomically copied to durable state.

## 7. Turn dispatch, prompt ambiguity, settlement

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

Persist deterministic workspace/agent identity, pinned gear spec, request, prompt bytes/digest, and expected result path before external mutation. `prompt_attempted` is durable before prompt call. Definite non-delivery permits exact prompt resend at most once; ambiguous delivery never blindly resends and may require abandonment.

A result file does not finish a turn. Producer must reach qualified settled state.

### 7.1 Crash-safe finalization after settlement

Once settled:

1. under lock set stage `finalizing`,
2. safely ingest exact result into durable state,
3. capture role final snapshot/integrity with source outbox present,
4. write canonical turn archive and persist archive digest,
5. delete only the exact ingested source outbox path,
6. verify exact outbox deletion and no unrelated path delta,
7. clear active lease,
8. apply exactly one lifecycle transition.

Crash/retry rules:

- archive absent -> resume from safe ingest/final snapshot,
- valid archive exists + outbox still exists -> verify archive digest, retry deletion of that exact outbox only, then clear lease/transition,
- valid archive exists + outbox absent + active lease still matches -> clear lease/transition idempotently,
- archive digest mismatch -> BLOCKED,
- outbox deletion failure/ambiguity -> remain `BLOCKED` in `finalizing` with active lease retained; do not create an abandoned/conflicting archive,
- concurrent finalizers reuse one valid archive and one transition.

Thus no completed archive coexists ambiguously with a released lease before transport cleanup is proven.

## 8. Evidence chain and repair tickets

All decision-bearing durable evidence is canonical exact-byte SHA-256 evidence.

```text
worker turn archive
 -> worker verification
 -> reviewer request binds verification digest
 -> reviewer turn archive
 -> review verification
 -> repair ticket if FAIL
 -> arbiter evidence/result if escalated
 -> final freshness
```

`record-repair` consumes only the current validated FAIL, validates a bounded schema, cannot widen immutable task scope/path/policy, writes canonical repair evidence/digest, and binds that digest into next worker request. Later modification fails digest check.

## 9. Crash-safe task worktree

Task owner marker exists before Git mutation. Task branch was proven absent at authorization.

Reconcile only exact deterministic identity:

- branch/path absent -> create exact worktree/branch at pinned base,
- branch exists at valid recorded base/descendant and unattached -> attach exact branch to exact path,
- attached elsewhere/incompatible -> BLOCKED,
- exact owned worktree -> adopt,
- wrong/tampered marker/non-worktree/alternate path -> BLOCKED.

Never allocate alternate identity on retry.

## 10. Protected source Git state

Canonical source may itself be linked worktree; common metadata is always addressed through pinned canonical `git_common_dir`.

After task preparation/before first worker launch capture/digest baseline:

- source worktree HEAD,
- full source porcelain status,
- protected refs map = all refs except exact Factory task branch,
- exact task branch initial OID separately,
- common config bytes from `<git_common_dir>/config`,
- deterministic `<git_common_dir>/hooks` tree digest.

At each protected check:

- source HEAD/status equal baseline,
- every protected ref unchanged and none missing,
- no new ref except exact task branch,
- common config/hooks unchanged,
- exact task branch equals expected task commit.

Mismatch BLOCKS; no automatic reset/repair.

## 11. Verification policy and bounded subprocesses

Allowed checks:

```text
npm-script
pnpm-script
yarn-script
node-test
node-check
```

No arbitrary shell/binary/install/migrate/deploy/destructive-Git forms.

For package scripts, root `package.json` `pre<script>/<script>/post<script>` definitions at reported commit must exactly equal pinned base definitions.

Each command timeout is pinned: default 10 minutes, config range 1–30 minutes.

Runner:

- `spawn` without shell,
- own process group/session on target macOS,
- 16 KiB stdout and stderr tail ring buffers,
- timeout terminates whole process group, bounded grace, then group force-kill,
- waits for process-group termination before post-checks,
- inability to prove group termination -> BLOCKED, never PASS,
- no environment values persisted.

## 12. Worker verification

Eligible only after completed finalized worker turn archive with valid digest and no active lease.

Order:

1. verify immutable input digests,
2. verify worker archive digest/correlation,
3. task worktree HEAD + task branch == reported commit,
4. pinned-base ancestry,
5. committed path/outbox audit,
6. protected-source check,
7. `git diff --check`,
8. task worktree clean (source outbox finalized/removed),
9. package lifecycle definition integrity,
10. bounded sanitized verification commands,
11. prove command process groups terminated,
12. recheck task HEAD/task branch == reported commit,
13. final task status clean,
14. protected-source check,
15. write/digest worker verification evidence.

## 13. Reviewer isolation and verdict consistency

Reviewer parent marker precedes clone mutation. Independent clone uses `--no-local --no-checkout`, detached exact verified commit, then removes origin. Require internal common Git dir, exact HEAD, empty remotes, clean pre-launch status.

Reviewer request binds worker verification digest. Reviewer result becomes evidence only after normal settlement/finalization. Reviewer final snapshot allows only exact outbox before its exact finalization deletion.

Review verification checks archive digest, reviewed commit, bound verification digest, finding schema, verdict, and writes digested review-verification evidence.

`PASS` may contain only explicitly non-material minor/informational findings. Any BLOCKER/IMPORTANT/material finding requires `FAIL`; contradictory PASS is invalid evidence and BLOCKS.

Reviewer isolation is repository/Git-metadata isolation only.

## 14. Arbiter and escalation

Arbiter receives ownership-marked evidence bundle only: immutable task summary/scope, classification, commit IDs, evidence/repair digests, findings/history, adjudication question. No checkout/source paths/remotes/.git/secrets.

First material FAIL -> repair + normally WORK_DEFAULT. Second -> fresh ORCH_ESCALATE_1 arbiter + WORK_STRONG. Third -> REPLAN_REQUIRED, no automatic fourth attempt.

## 15. Final freshness and DONE

Immediately before DONE, under run lock:

1. verify all immutable input/evidence digests,
2. no active turn, cancellation, or stale evidence,
3. exact task worktree HEAD == verified commit,
4. exact task branch == verified commit,
5. task worktree clean,
6. protected source HEAD/status/refs/common config/hooks equal baseline except task branch at verified commit,
7. retry/escalation policy satisfied.

Only then transition DONE. DONE is a point-in-time verified state, not permanent prevention of subsequent external mutation.

## 16. Cleanup

Cleanup touches only exact recorded valid-owner resources, never active-turn resources, and never evidence-needed resources before durable digests exist. Task worktree removal requires terminal run + explicit authority, uses native Git without `--force`, and retains task branch unless separately authorized.

## 17. Doctor and qualification

Doctor is non-mutating and checks Node/Git/Herdr, config, gears, roots/common-Git identity, canonical serializer, state/temp writability, lock/process identity, no-follow support on target platform, sanitizer, bounded process-group runner capability, reviewer isolation capability, and foreman configured-vs-verified truthfulness.

`UNIT_INTEGRATION_COMPLETE` requires the entire local TDD/E2E matrix at one HEAD.

`HERDR_RUNTIME_QUALIFIED` additionally requires disposable provider-backed Mac/Herdr proof of prompt/settlement/finalization semantics, no-follow artifacts, process-group timeout termination, protected source state, reviewer isolation, final freshness, escalation, and cleanup.

## 18. Review-10 corrections

1. Restores explicit `/cancel` semantics that had been compressed out of Review 9.
2. Restores the canonical lifecycle state machine and legal transition ownership.
3. Restores deterministic classification/routing rules including high-risk REVIEW_STRONG and three-failure cap.
4. Restores the complete public CLI contract.
5. Adds `finalizing` stage and crash-safe archive/outbox-delete/lease-release recovery so a crash after archive creation cannot wedge or create conflicting turn outcomes.

## 19. Deferred

OS/container sandboxing; guaranteed network isolation; model catalog/usage pricing; parallel workers; auto merge/push/deploy; web/remote orchestration; raw socket subscription; direct UAL integration; autonomous PLAN->EXECUTE; automatic permission approval.
