# Mighty Factory — Canonical v0.1 Design (Review 7)

**Status:** Canonical design for implementation  
**Date:** 2026-09-16  
**Supersedes:** Review-6 and all earlier Mighty Factory drafts  
**Incubation:** `mighty-router` branch `incubator/mighty-factory-v0` only

## 1. Goal

Build a small local software-factory controller around Herdr where:

- the human-facing Codex/Luna-Max session owns planning and judgment,
- deterministic Node.js code owns authority, immutable run inputs, lifecycle, concurrency, routing, verification, recovery, cleanup, and completion,
- fresh Antigravity workers implement bounded changes,
- fresh Cline reviewers independently review the exact verified commit in an independent clone,
- escalation launches genuinely stronger fresh specialist turns,
- crashes do not silently duplicate turns, prompts, or resources,
- config/task/classification/repository/base identity cannot drift after authorization,
- specialist results are not trusted until the producer settles and its turn is archived,
- shared source-repository Git metadata is protected from worker/repository-check side effects,
- verification commands cannot silently move the verified commit or rewrite their own package-script definition,
- evidence artifacts are byte-digested and regular-file bounded,
- unrecoverable active turns have an explicit human-only abandonment path,
- no implicit merge, deploy, production mutation, or remote push is authorized.

```text
Human
  |
  v
Codex / Luna Max foreman
  |
  | exact /execute
  v
Controller authorization
  |  canonical repo + base_sha
  |  config/task/classification snapshots + exact-byte digests
  v
Crash-safe task resource plan
  |
  v
Fresh worker turn
  |  result -> settle -> archive+digest -> clear lease
  v
Controller verification
  |  scope + protected Git metadata + checks + final HEAD/status
  v
Independent reviewer clone
  |  result -> settle -> archive+digest -> clear lease
  v
Review verification
  +---- PASS --------------------------------> DONE
  +---- FAIL -> repair -> arbiter -> strong worker -> replan cap
```

## 2. Trust model

Mighty Factory v0.1 is **trusted-local-repository automation, not a security sandbox**.

Worker-generated code, repository tests, and provider CLIs execute with the user's local OS permissions. Environment sanitization and repository guards reduce accidental side effects but do not contain filesystem or network access.

Therefore:

- only `execution_trust: "trusted-local-repository"` is accepted,
- v0.1 does not claim safety for untrusted repositories,
- provider and verification subprocess environments use pinned variable-name allowlists,
- secret values are never persisted in snapshots or logs,
- reviewer isolation is repository/Git-metadata isolation only,
- the controller never authorizes push/deploy, but without OS sandboxing it cannot prove a model process never performed an external network side effect,
- true untrusted-code containment is deferred.

## 3. Authority model

The controller owns:

- `/execute`, `/cancel`, `recover-run`, and `abandon-turn`,
- immutable run snapshots and digests,
- canonical repo/base identity,
- run/task/turn IDs,
- locks and active-turn leases,
- process-owner identity,
- crash reconciliation,
- prompt ambiguity handling,
- turn settlement/archive/release,
- protected source-repository state,
- path and Git invariants,
- verification command policy,
- reviewer integrity,
- escalation caps,
- owned-resource cleanup,
- DONE eligibility.

The orchestrator owns requirements, classification before authorization, task construction before authorization, planning, bounded repair-ticket wording, and interpretation of arbiter recommendations. It never edits pinned run inputs or manufactures lifecycle transitions.

## 4. PLAN / EXECUTE / CANCEL / ABANDON

PLAN is non-mutating. Only exact `/execute` authorizes execution.

Public authority commands:

```text
mighty-factory authorize-execute
mighty-factory cancel
mighty-factory recover-run
mighty-factory abandon-turn
```

No public generic `transition` command exists.

### 4.1 Cancellation

- no active turn -> immediate `CANCELLED`,
- active turn -> `cancel_requested=true`, current turn may reach its safe settled handoff,
- before any subsequent mutation-capable verification or specialist operation -> `CANCELLED`,
- cancellation never erases an active turn.

### 4.2 Abandonment

`abandon-turn --run <run_id> --turn <turn_id>` is human-only and is used when an active turn cannot be safely reconciled.

It must:

1. lock the run,
2. match the exact active turn,
3. never resend its prompt,
4. close only its recorded Factory-owned Herdr workspace,
5. prove workspace closure/absence before release,
6. archive the turn as `abandoned` with evidence and archive digest,
7. clear the lease,
8. preserve task checkout/outboxes/evidence,
9. transition run to `CANCELLED` with reason `turn_abandoned`.

If closure cannot be proven, remain `BLOCKED` with lease retained.

## 5. Immutable authorization inputs

Before authorization the operator config, task, and classification are mutable inputs. After authorization they are never consulted again for run decisions.

`authorize-execute` performs one controller transaction:

1. validate config/task/classification,
2. canonicalize target repository via filesystem realpath and `git rev-parse --show-toplevel`,
3. require a non-bare repository suitable for native worktrees,
4. resolve `base_ref` immediately to `base_sha`,
5. validate Factory state/temp roots and canonical repo do not overlap,
6. generate run/task IDs and deterministic task branch/path,
7. require deterministic task branch not to preexist at authorization,
8. normalize config/task/classification,
9. embed canonical repo + base SHA into task snapshot,
10. atomically write exact canonical snapshot bytes,
11. SHA-256 hash the exact bytes written,
12. persist `run.json` with all three digests and base identity,
13. transition PLAN -> READY only after all durable writes succeed.

Canonical run inputs:

```text
config.snapshot.json
task.snapshot.json
classification.snapshot.json
run.json
```

Every later command hashes the exact file bytes before parsing and rejects digest mismatch.

### 5.1 Canonical JSON bytes

Snapshot serialization is:

- UTF-8 JSON,
- recursive object-key sorting,
- array order preserved,
- finite JSON numbers only,
- no `undefined`/functions/non-JSON values,
- exactly one trailing newline.

Digests are calculated over exact written bytes, not reconstructed objects.

### 5.2 Root separation

After path normalization/realpath of existing ancestors:

- `state_root` and `temp_root` must be distinct,
- neither may contain the other,
- neither may be inside the canonical target repository,
- the canonical target repository may not be inside either Factory root.

This prevents Factory state/cleanup from dirtying or recursively containing the source repository.

## 6. Safe verification policy

Supported task-authored check kinds:

```text
npm-script
pnpm-script
yarn-script
node-test
node-check
```

No shell strings, arbitrary binaries, package install, migration, deploy, `npx`, curl/wget, or destructive Git commands are representable.

Node paths must be normalized repository-relative paths. Package-script names must be in the pinned config allowlist.

### 6.1 Package-script definition integrity

A worker may not rewrite the definition of the command being used as independent verification.

For every npm/pnpm/yarn script check, the controller obtains from pinned `base_sha` the root `package.json` definitions for:

```text
pre<script>
<script>
post<script>
```

Before execution it reads the same definitions from the reported commit and requires exact equality, including absence/presence. If any selected lifecycle definition changed, that package-script verification form is invalid for the task and verification fails closed.

Tasks intentionally changing those script definitions must use another verification form such as explicit `node-test`/`node-check`, or a future separately-authorized policy.

### 6.2 Environment

Verification environment retains only names pinned in the config snapshot plus fixed safe values such as `CI=1`. Secret values are never logged.

## 7. Run locking and process identity

Every state-changing command acquires an atomic per-run lock.

Lock metadata contains nonce, PID, platform process-start token, controller-instance ID, creation timestamp, and command.

Stale-lock recovery requires exact nonce and process identity:

- PID absent -> stale owner may be recovered,
- same PID + same start token -> live owner, reject,
- same PID + different start token -> PID reuse, old owner stale,
- process identity unavailable/ambiguous -> fail closed with manual instructions,
- no force-clear CLI.

## 8. Active-turn state and evidence chain

Active stages:

```text
claimed
workspace_ready
agent_started
prompt_attempted
result_seen
settling
```

Completed/abandoned turns are archived at:

```text
turns/<turn_id>/turn.json
```

The archive exact bytes are canonicalized and SHA-256 hashed. The resulting `turn_archive_digest` is persisted in state/event history before the active lease is cleared.

Any later operation consuming a turn archive must hash its exact bytes and match that recorded digest before parsing/using it.

Role evidence chain:

```text
worker turn archive digest
  -> verification artifact exact-byte digest
     -> reviewer request records verification digest
        -> reviewer turn archive digest
           -> review-verification artifact digest
```

DONE validates this chain, not merely filenames.

## 9. Artifact ingestion safety

Every worker/reviewer/arbiter outbox artifact must:

- resolve to the exact expected path inside its owned workspace,
- pass `lstat` as a regular file, not symlink/socket/device/directory,
- be <= 1 MiB in v0.1,
- have stable size/metadata across the bounded read,
- decode as UTF-8 JSON,
- match schema/run/task/turn/role/commit expectations,
- be copied atomically into durable state,
- have SHA-256 calculated from the exact bytes ingested.

Unexpected artifact type/size/path blocks the turn; it is never followed through a symlink.

## 10. Prompt-safe dispatch

Before external launch/prompt mutation persist:

- turn ID,
- deterministic agent/workspace identity,
- exact pinned gear launch spec,
- request artifact,
- prompt bytes/digest,
- expected result path.

Flow:

1. lock run and verify input digests,
2. create/reuse same active turn,
3. reconcile/create exact workspace,
4. reconcile/start deterministic agent,
5. persist `agent_started`,
6. persist prompt bytes/digest and `prompt_attempted` **before** external prompt call,
7. call prompt once,
8. release lock after short acknowledgement/timeout classification,
9. inspect/wait outside lock,
10. result appearance sets `result_seen`; lease remains active.

Ambiguous prompt attempt is never blindly resent. Definite non-delivery may resend the exact persisted prompt at most once. Otherwise the run blocks and may be human-abandoned.

## 11. Settlement and lease release

A result file does not complete a turn.

After `result_seen`:

1. set `settling`,
2. wait/inspect exact deterministic agent,
3. require locally-qualified settled state (`idle` or `done`),
4. blocked/unknown/timeout without proof -> `BLOCKED`, lease retained,
5. reacquire run lock,
6. revalidate run input digests and active-turn ID,
7. safely ingest result bytes,
8. capture role-specific final state,
9. atomically write/digest turn archive,
10. persist archive digest,
11. clear active lease,
12. transition deterministic next phase.

Settlement is idempotent: if another controller already archived the same turn and cleared the lease, a concurrent waiter verifies the existing archive digest and returns the existing archived result rather than applying a second transition.

No verification, verdict application, repair, escalation, cleanup, or DONE consumes a still-active turn.

## 12. Crash-safe task resource

Before Git mutation the controller creates and ownership-marks a deterministic parent outside the source repository:

```text
<temp-root>/<run_id>/task/
  .mighty-factory-owner.json
  repo/   # native linked task worktree path
```

It also persists branch/path/base intent. The branch is required absent at authorization.

Reconciliation:

1. owned parent absent -> create+mark parent before Git mutation,
2. path absent + branch absent -> `git worktree add -b <branch> <path> <base_sha>`,
3. path absent + expected branch exists at base/valid task descendant and is unattached -> attach branch at exact path,
4. expected branch attached elsewhere -> BLOCKED,
5. expected branch incompatible with recorded run history -> BLOCKED,
6. exact recorded worktree/branch under owned parent -> adopt,
7. wrong/missing parent marker or non-worktree path -> BLOCKED,
8. retry never allocates another branch/path.

## 13. Protected source-repository state

The worker uses a native linked worktree, so it shares common Git metadata with the source repository. v0.1 therefore detects unauthorized shared-repository mutation explicitly.

After task worktree preparation and before the first worker launch, capture a protected-source baseline:

- canonical source worktree `HEAD`,
- full source worktree porcelain status including untracked files,
- every existing Git ref and object ID except the exact Factory task branch,
- exact local repository config bytes/digest,
- deterministic digest of `.git/hooks` entries (path, type, bytes; absent directory represented explicitly).

The baseline itself is atomically persisted and byte-digested.

After every worker settlement **and again after controller repository verification commands**, compare against the baseline:

- source worktree HEAD unchanged,
- source worktree status unchanged,
- all protected preexisting refs unchanged,
- no new refs except the exact Factory task branch and explicitly documented Git-worktree administrative refs,
- local config unchanged,
- hooks digest unchanged,
- exact Factory task branch points at the expected reported commit when verification completes.

Any mismatch is `BLOCKED`; the controller never auto-resets or repairs protected source metadata.

This is final-state detection, not OS sandbox prevention.

## 14. Worker verification ordering

Verification runs only from a settled, archived worker turn whose archive digest is valid.

Order:

1. verify all run snapshot byte digests,
2. verify archived-turn bytes/digest/correlation,
3. verify reported commit exists and task worktree HEAD/task branch equal reported commit,
4. verify pinned `base_sha` ancestry,
5. audit committed paths and reject committed outbox,
6. compare protected source baseline,
7. `git diff --check <base_sha>..<commit>`,
8. initial task-worktree status check,
9. validate package-script lifecycle definitions against base when applicable,
10. run trusted repository checks in sanitized environment,
11. re-check task worktree HEAD and exact task branch ref equal reported commit,
12. final task-worktree status check,
13. compare protected source baseline again,
14. write canonical verification artifact + exact-byte digest.

Final task-worktree status may contain only the expected worker-result outbox.

This catches verification scripts that create a clean new commit/reset HEAD as well as scripts that merely dirty files.

## 15. Reviewer clone

Reviewer uses an independent clone under an ownership-marked parent created before clone mutation:

```text
<temp-root>/<run_id>/review/<turn_id>/
  .mighty-factory-owner.json
  repo/
```

Clone sequence:

```text
git clone --no-local --no-checkout <canonical-source-repo> <repo>
git -C <repo> checkout --detach <verified_commit>
git -C <repo> remote remove origin
```

Adopt only if owner marker, exact HEAD, no-origin, and clone-internal common Git dir all match. Partial/incompatible clones block; no destructive repair or alternate path.

Reviewer request records the exact verification artifact digest. Reviewer result is not final until agent settlement. The archived reviewer turn contains the reviewed commit and verification digest. Post-settlement HEAD/status must differ only by expected reviewer outbox.

## 16. Arbiter bundle

Arbiter gets no checkout. Parent is ownership-marked before bundle population:

```text
<temp-root>/<run_id>/arbiter/<turn_id>/
  .mighty-factory-owner.json
  bundle/
```

Bundle includes only sanitized task summary/scope, classification, commit IDs, byte-digested verification/review evidence, repair history, and adjudication question. It omits source/worktree paths, remotes, `.git`, and secrets.

Adopt only exact ownership-marked complete bundle; partial/mismatched state blocks.

## 17. Review, repair, escalation

First material review failure -> `REPAIR_PENDING`, prior verification/review evidence stale, bounded repair ticket, next worker normally `WORK_DEFAULT`.

Second material failure -> `ESCALATION_PENDING`, fresh isolated `ORCH_ESCALATE_1` arbiter, next worker `WORK_STRONG`.

Third material failure -> `REPLAN_REQUIRED`, no automatic fourth retry.

All decisions consume valid byte-digested archived evidence.

## 18. Gears and foreman truthfulness

Factory-launched gears:

```text
ORCH_ESCALATE_1
WORK_DEFAULT
WORK_STRONG
REVIEW_DEFAULT
REVIEW_STRONG
```

Each is resolved to exact non-secret argv in the pinned config snapshot.

Human foreman is separate `foreman_expected`. Report `current-session-verified` only when supported introspection proves it; otherwise report only `configured-session-contract`.

## 19. Cleanup

Cleanup touches only durably recorded Factory-owned resources and never resources referenced by an active turn.

Eligible:

- ingested outbox directories,
- archived settled-turn Herdr workspaces by exact ID,
- reviewer/arbiter owned parents only after evidence required for verdict/arbiter consumption has been atomically persisted and digested,
- task worktree only after terminal run and explicit task-worktree cleanup authority.

Task worktree removal uses native Git without `--force`. Dirty refusal is reported. Task branch remains unless separately authorized.

`abandon-turn` is not cleanup and preserves filesystem evidence.

## 20. Public CLI

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

## 21. DONE gate

DONE requires:

1. no active turn or pending cancellation,
2. exact config/task/classification snapshot digests match,
3. canonical repo/base SHA match immutable manifest,
4. protected source-repository baseline still matches except exact allowed task branch,
5. worker archive digest valid and status completed,
6. worker commit independently verified,
7. verification artifact digest valid,
8. reviewer archive digest valid and references exact commit + verification digest,
9. reviewer integrity passed after settlement,
10. review-verification artifact digest valid and verdict PASS,
11. no later mutation made evidence stale,
12. escalation policy satisfied,
13. every Factory specialist launch used pinned gear spec,
14. no controller-authorized merge/push/deploy/production mutation occurred.

## 22. Runtime qualification

Provider-backed disposable smoke run must prove at least:

- immutable snapshots/base identity resist live-file/branch changes,
- root overlap is rejected,
- task parent marker precedes worktree mutation,
- branch-created/no-worktree crash reconciles exact resource,
- source worktree/ref/config/hooks baseline detects forbidden shared-repo mutation,
- duplicate dispatch launches once,
- ambiguous prompt is not blindly resent,
- human abandonment never retries and preserves checkout,
- result before settlement does not release lease,
- archived turn byte tampering is detected,
- symlink/oversized result artifact is rejected,
- package verification script definition rewrite is rejected,
- verification command moving HEAD cleanly is rejected,
- reviewer independent clone has no origin/common-dir sharing,
- reviewer result applied only after settlement,
- cleanup refuses active/evidence-needed resources,
- PID reuse recovery works,
- second failure launches arbiter + WORK_STRONG,
- third failure stops,
- source main/protected refs remain unchanged.

Without this provider-backed run, report at most `UNIT_INTEGRATION_COMPLETE`, never `HERDR_RUNTIME_QUALIFIED`.

## 23. Review-7 corrections

1. Protected source Git metadata/worktree baseline detects worker or verification side effects outside the task branch.
2. Verification rechecks HEAD and task branch after repository commands, catching clean commit/reset mutations.
3. Package-script lifecycle definitions are pinned to base so a worker cannot rewrite the verification command it is judged by.
4. Turn/verification/review evidence is exact-byte digested and later consumers verify those digests.
5. Outbox artifacts must be bounded regular files; symlinks and oversized/special files are rejected.
6. Factory roots may not overlap the canonical repository or each other.
7. Task resource parent is ownership-marked before worktree mutation, tightening branch/path crash adoption.
8. Settlement is explicitly idempotent for concurrent waiters.

## 24. Deferred

Not in v0.1:

- container/VM sandboxing,
- prevention of all external network side effects by provider/repository code,
- model-catalog discovery,
- provider usage accounting/token-price optimization,
- parallel workers on one task,
- auto merge/push/deploy,
- web UI/remote orchestration,
- raw Herdr socket subscriber,
- direct UAL integration,
- autonomous PLAN -> EXECUTE,
- automatic permission approval.
