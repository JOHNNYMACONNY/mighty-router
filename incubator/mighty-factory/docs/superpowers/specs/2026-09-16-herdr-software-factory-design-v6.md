# Mighty Factory — Canonical v0.1 Design (Review 6)

**Status:** Canonical design for implementation  
**Date:** 2026-09-16  
**Supersedes:** Review-5, Review-4, Review-3, and all 2026-09-15 Mighty Factory drafts  
**Incubation:** `mighty-router` branch `incubator/mighty-factory-v0` only

## 1. Goal

Build a small local software-factory controller around Herdr where:

- the human-facing Codex/Luna-Max session owns planning and judgment,
- deterministic Node.js code owns authority, immutable run inputs, lifecycle, concurrency, routing, verification, recovery, cleanup, and completion,
- fresh Antigravity worker turns implement bounded changes,
- fresh Cline reviewer turns independently review the exact verified commit in an isolated clone,
- escalation launches genuinely stronger fresh specialist turns,
- a crash cannot silently create a second logical turn, silently redeliver an ambiguous prompt, or silently create a second resource,
- a run cannot change meaning because config/task/classification/base branch changed after authorization,
- specialist results are not trusted until the producing agent is settled and its turn lease is archived,
- a human can safely abandon an unrecoverably ambiguous active turn without retrying it,
- no agent can silently widen scope, skip verification, mutate main, or deploy by default.

```text
Human
  |
  v
Codex / Luna Max foreman
  |
  | exact /execute
  v
Mighty Factory controller
  |
  | normalize + snapshot config/task/classification
  | canonicalize target repo + pin base_sha
  v
immutable run manifest + digests
  |
  | persist intended task resource identity
  v
reconcile/create task worktree
  |
  | claim active_turn + deterministic launch identity
  | persist prompt bytes/digest BEFORE delivery
  v
Fresh worker turn
  |
  | commit -> result outbox -> agent settles
  v
archive worker turn + clear lease
  |
  v
Controller verification
  |
  | scope + Git + trusted-repo checks + post-check status
  v
Independent reviewer clone
  |
  | review result -> reviewer settles
  v
archive reviewer turn + clear lease
  |
  +---- PASS -------------------------------> DONE gate
  |
  +---- FAIL -> repair -> arbiter -> strong worker -> replan cap
```

## 2. Security and trust model

Mighty Factory v0.1 is **not a security sandbox**.

It is for repositories the user already trusts enough to execute locally. Worker-generated code and repository-defined test/lint/typecheck scripts run with the user's OS permissions. Sanitized environments reduce accidental secret exposure but do not contain filesystem or network access.

Therefore:

- v0.1 accepts only `execution_trust: "trusted-local-repository"`,
- v0.1 must not claim to safely execute untrusted repositories,
- verification subprocesses use sanitized environments,
- provider launch environments use config-controlled variable-name allowlists,
- secret values are never persisted in run snapshots or printed in logs,
- reviewer isolation means repository/Git-metadata isolation only,
- true containment of untrusted code is deferred.

## 3. Authority model

Herdr is process transport, not lifecycle truth.

The controller owns:

- `/execute`, `/cancel`, `recover-run`, and `abandon-turn` authority,
- immutable run manifest and input digests,
- canonical target repository + pinned `base_sha`,
- run/task/turn IDs,
- run locks and active-turn leases,
- process-owner identity used for stale-lock recovery,
- crash reconciliation for resources and turns,
- prompt-delivery ambiguity handling,
- turn settlement/archive/lease release,
- allowed-path enforcement,
- exact specialist gear activation,
- artifact ingestion,
- independent verification,
- reviewer integrity checks,
- retry/escalation limits,
- bounded cleanup,
- DONE eligibility.

The orchestrator owns:

- conversation and requirements,
- classification judgment before authorization,
- task-contract construction before authorization,
- planning/architecture,
- bounded repair-ticket wording,
- interpretation of arbiter recommendations.

The orchestrator never maintains a shadow lifecycle or edits pinned run inputs.

## 4. PLAN / EXECUTE / CANCEL / ABANDON boundary

PLAN is non-mutating. No specialist agent launches.

Only exact `/execute` authorizes execution in v0.1.

Public authority commands include:

```text
mighty-factory authorize-execute
mighty-factory cancel
mighty-factory recover-run
mighty-factory abandon-turn
```

There is no public generic lifecycle `transition` command.

### 4.1 Cancellation

- if `active_turn == null`, `/cancel` transitions directly to `CANCELLED`,
- if a turn is already claimed, cancellation sets `cancel_requested: true`,
- the claimed turn may reach its terminal/settled handoff,
- before any new mutation-capable operation or new specialist turn, the run becomes `CANCELLED`,
- cancellation never erases a claimed turn.

### 4.2 Human-only turn abandonment

`abandon-turn` exists only for an active turn that cannot be safely reconciled, especially prompt-delivery ambiguity.

Required syntax:

```text
mighty-factory abandon-turn --run <run_id> --turn <turn_id>
```

Rules:

1. acquire the run lock,
2. require exact active-turn ID match,
3. never resend the prompt,
4. close only the exact Factory-owned Herdr workspace for that turn,
5. if workspace closure/absence cannot be proven, remain `BLOCKED`,
6. archive the turn with `status: "abandoned"` and reason/evidence,
7. clear `active_turn`,
8. preserve task worktree, commits, outboxes, and durable evidence for inspection,
9. transition the run to `CANCELLED` with reason `turn_abandoned`,
10. later cleanup remains explicit and ownership-bounded.

## 5. Task contract before authorization

Example operator task input:

```json
{
  "schema_version": 1,
  "summary": "Implement bounded feature X",
  "target_repo": "/absolute/path/to/repo",
  "base_ref": "main",
  "execution_trust": "trusted-local-repository",
  "allowed_paths": ["src/", "tests/"],
  "allow_noop": false,
  "verification": {
    "policy": "trusted-repo-checks",
    "commands": [
      {"kind": "npm-script", "script": "test"},
      {"kind": "npm-script", "script": "typecheck"}
    ]
  }
}
```

Before authorization it is mutable operator input. After authorization it is not consulted again.

## 6. Immutable authorization manifest

`authorize-execute` freezes **all decision-bearing inputs**, not only config.

Authorization performs under one controller transaction:

1. load and validate mutable operator config,
2. validate task and classification,
3. canonicalize `target_repo` using filesystem realpath + `git rev-parse --show-toplevel`,
4. require those canonical roots to identify the same repository,
5. resolve `base_ref` immediately to immutable `base_sha`,
6. normalize config/task/classification into snapshot objects,
7. add canonical target repo and pinned `base_sha` to the normalized task snapshot,
8. write canonical snapshot bytes atomically,
9. hash the **exact written bytes** with SHA-256,
10. persist the three digests and immutable authorization metadata in `run.json`,
11. transition PLAN -> READY only after all writes succeed.

Canonical files:

```text
config.snapshot.json
task.snapshot.json
classification.snapshot.json
run.json
```

`run.json` stores:

```json
{
  "run_id": "run_...",
  "task_id": "task_...",
  "input_digests": {
    "config": "sha256:...",
    "task": "sha256:...",
    "classification": "sha256:..."
  },
  "target_repo": "/canonical/git/root",
  "base_ref": "main",
  "base_sha": "<40-hex>"
}
```

Every later command:

- reads the exact snapshot file bytes,
- hashes those bytes before parsing,
- compares against `run.json`,
- rejects digest mismatch,
- never rereads mutable task/classification/config files for run decisions.

### 6.1 Canonical JSON bytes

Snapshot serialization is deterministic:

- UTF-8 JSON,
- recursively sorted object keys,
- array order preserved,
- no insignificant whitespace except one trailing newline,
- finite JSON numbers only,
- no `undefined`, functions, or non-JSON values.

The digest is calculated over the exact bytes written to disk. A later read verifies those exact bytes before JSON parsing. Reconstructed objects are not used as the primary integrity source.

Snapshot content never stores secret environment values, auth tokens, cookies, passwords, or provider session material.

## 7. Verification policy and environments

Supported task-authored check kinds:

```text
npm-script
pnpm-script
yarn-script
node-test
node-check
```

Script names must be in the pinned run snapshot allowlist.

Constraints:

- no shell strings,
- no arbitrary executables,
- no package installation, migration, deployment, `npx`, reset/clean/switch, curl/wget, or shell invocation,
- node paths must be normalized repository-relative paths,
- unsupported forms fail closed.

Controller-owned Git checks always include:

```text
git rev-parse <reported_commit>^{commit}
git merge-base --is-ancestor <base_sha> <reported_commit>
git diff --name-only <base_sha>..<reported_commit>
git diff --check <base_sha>..<reported_commit>
git status --porcelain=v1 --untracked-files=all
```

`git diff --check` is whitespace/diff hygiene, not syntax validation.

Verification environment retains only names pinned in the run snapshot plus fixed safe values such as `CI=1`. Secret values are not logged.

## 8. Allowed-path enforcement

The controller audits exact committed paths from pinned `base_sha` to reported commit.

Fail closed for:

- absolute/traversal paths,
- any committed path outside `allowed_paths`,
- committed `.mighty-factory-outbox/**`,
- empty diff unless `allow_noop` is true.

## 9. Run locking and process-owner identity

Every state-changing command uses an atomic per-run lock.

Lock metadata:

```json
{
  "nonce": "...",
  "pid": 12345,
  "process_start_token": "platform-derived-start-identity",
  "controller_instance_id": "ctl_...",
  "created_at": "...",
  "command": "dispatch-worker"
}
```

The controller obtains `process_start_token` at lock creation from an injectable platform probe. On the user's macOS target, the implementation may use a non-mutating `ps` query whose normalized process-start output is stable for that process lifetime.

Recovery with `recover-run --lock-nonce <nonce>`:

- wrong nonce -> reject,
- PID absent -> stale owner may be recovered,
- PID present with matching start token -> owner still live, reject,
- PID present with a different start token -> PID reuse; old owner is stale and may be recovered,
- start identity unavailable/ambiguous -> fail closed and print manual recovery instructions.

Manual recovery instructions must tell the operator to inspect the recorded PID/start metadata with OS tools before removing the lock file. v0.1 does not expose a force-clear flag.

## 10. Active turn stages and durable archive

`state.json` minimum:

```json
{
  "revision": 12,
  "phase": "WORKING",
  "cancel_requested": false,
  "active_turn": {
    "turn_id": "turn_...",
    "role": "worker",
    "stage": "prompt_attempted",
    "agent_name": "mf-worker-a1b2-c3d4",
    "workspace_label": "mighty-factory:turn_...",
    "prompt_digest": "sha256:..."
  }
}
```

Allowed active stages:

```text
claimed
workspace_ready
agent_started
prompt_attempted
result_seen
settling
```

Active turns are never the permanent source for completed-turn evidence.

Completed/abandoned turns are archived under:

```text
turns/<turn_id>/turn.json
```

Archive contains IDs, role, gear launch spec digest, workspace IDs, prompt digest, result artifact digest, settlement evidence, final turn status (`completed|abandoned|blocked`), and timestamps.

## 11. Crash-safe specialist dispatch and prompt ambiguity

Persist before external mutation:

- turn ID,
- deterministic agent name/workspace label,
- gear launch spec,
- request artifact,
- exact prompt bytes and digest,
- expected result path.

Dispatch flow:

1. acquire run lock,
2. validate phase/cancellation/input digests,
3. create or reuse the same active turn,
4. reconcile/create exact labelled Herdr workspace,
5. persist real workspace/pane IDs,
6. reconcile/start deterministic agent,
7. persist `agent_started`,
8. persist exact prompt bytes/digest and set `prompt_attempted` **before** prompt call,
9. call prompt once,
10. release lock after short acknowledgement/timeout classification,
11. inspect/wait outside lock,
12. when expected result appears, mark `result_seen` under lock but do not clear lease yet.

Prompt ambiguity rules:

- existing valid expected result -> continue toward settlement,
- definite provider evidence of non-delivery -> resend the exact persisted prompt at most once under the same turn,
- otherwise never blindly resend,
- ambiguous no-result turn -> `BLOCKED` with active turn retained,
- operator may later use `abandon-turn`.

## 12. Specialist settlement and active-turn release

A result artifact does **not** end a turn.

After `result_seen`, controller requires the deterministic agent to reach an accepted settled state (`idle` or `done`, according to locally qualified Herdr semantics) before consuming the result as final evidence.

Settlement flow:

1. set active stage `settling`,
2. inspect/wait for exact deterministic agent,
3. `blocked`/`unknown`/timeout without proven settlement -> run `BLOCKED`, lease retained,
4. on settled state, reacquire run lock,
5. revalidate input digests and active-turn ID,
6. ingest/correlate final result,
7. perform role-specific final snapshot needed before release:
   - worker: capture post-settlement task-worktree status,
   - reviewer: capture post-settlement clone HEAD/status,
   - arbiter: capture post-settlement bundle status,
8. write immutable turn archive atomically,
9. clear `active_turn`,
10. transition to the next deterministic phase.

No worker verification, reviewer verdict application, repair, escalation, cleanup, or DONE can depend on a still-active turn.

This prevents a specialist from writing a result and continuing to mutate after the controller has treated it as finished.

## 13. Crash-safe task resource preparation

Task resource intent is persisted before Git mutation:

```json
{
  "branch": "mf/run-<suffix>",
  "worktree_path": "/factory/.../task",
  "base_sha": "...",
  "stage": "intended"
}
```

Preparation uses only the pinned task snapshot and pinned `base_sha` from authorization.

Reconciliation matrix:

1. path absent + branch absent -> `git worktree add -b <branch> <path> <base_sha>`,
2. path absent + branch exists at exact expected base and branch is not attached to another worktree -> `git worktree add <path> <branch>`,
3. path absent + branch attached elsewhere -> BLOCKED,
4. path absent + branch points to incompatible commit before worker execution -> BLOCKED,
5. path exists as exact recorded worktree/branch rooted in canonical source repo -> adopt,
6. path exists but is not the recorded worktree -> BLOCKED,
7. multiple matching candidates -> BLOCKED.

Retry never allocates a different path or branch.

## 14. Worker transport and verification ordering

Worker result path:

```text
<task-worktree>/.mighty-factory-outbox/<turn_id>/worker-result.json
```

Worker commits implementation before writing result.

After the worker turn is settled, archived, and active lease cleared, verification performs:

1. archived-turn/result correlation,
2. input digest verification,
3. commit existence/HEAD/ancestry against pinned `base_sha`,
4. allowed-path audit and committed-outbox rejection,
5. controller `git diff --check`,
6. initial full worktree status check,
7. trusted repository checks in sanitized environment,
8. final full worktree status check,
9. permit only exact expected worker-result outbox,
10. bind evidence to exact commit + input digests.

Any repository check that dirties the checkout fails verification even if command exits 0.

## 15. Reviewer isolation and crash-safe provisioning

Reviewer uses an independent clone. It is repository/Git-metadata isolation only.

Before clone creation, controller creates and ownership-marks a deterministic parent directory:

```text
<temp-root>/<run_id>/review/<turn_id>/
  .mighty-factory-owner.json
  repo/
```

Parent ownership marker is written **before** `git clone`.

Then:

```text
git clone --no-local --no-checkout <canonical-source-repo> <parent>/repo
git -C <repo> checkout --detach <verified_commit>
git -C <repo> remote remove origin
```

Reconciliation:

- parent absent -> create parent + marker first, then clone,
- parent exists wrong/missing marker -> BLOCKED,
- valid owned parent + repo absent -> resume clone into exact `repo/`,
- valid owned parent + exact clone HEAD/no-origin/common-dir-internal -> adopt,
- partial/incompatible repo -> BLOCKED; no destructive auto-repair or alternate path.

Reviewer result is final only after reviewer agent settles. Post-settlement HEAD/status must differ from initial state only by exact expected outbox.

## 16. Arbiter isolation and crash-safe provisioning

Arbiter gets no target checkout.

Controller first creates and marks deterministic owned parent:

```text
<temp-root>/<run_id>/arbiter/<turn_id>/
  .mighty-factory-owner.json
  bundle/
```

Marker is written before bundle population.

Bundle contains sanitized copied evidence only and omits target repo/worktree paths, remotes, secrets, and `.git`.

Reconciliation:

- owned parent + missing bundle -> populate exact bundle path,
- owned parent + complete manifest/digest match -> adopt,
- wrong/missing owner marker or partial/mismatched bundle -> BLOCKED,
- never allocate alternate path.

Arbiter result is consumed only after agent settlement and turn archival.

## 17. Routing and gears

Factory-launched gears:

```text
ORCH_ESCALATE_1
WORK_DEFAULT
WORK_STRONG
REVIEW_DEFAULT
REVIEW_STRONG
```

All must be resolved to concrete non-secret launch argv inside the pinned config snapshot.

Human-facing foreman is recorded separately as `foreman_expected`.

Status values:

```text
configured-session-contract
current-session-verified
```

Factory may report `current-session-verified` only when supported introspection proves it. Otherwise it reports only the configured expectation.

## 18. Review/repair/escalation

First material review failure -> `REPAIR_PENDING`, evidence stale, bounded repair ticket, next worker normally `WORK_DEFAULT`.

Second material review failure -> `ESCALATION_PENDING`, fresh isolated `ORCH_ESCALATE_1` arbiter, then `WORK_STRONG`.

Third material review failure -> `REPLAN_REQUIRED`, no blind fourth retry.

All decisions consume archived settled-turn evidence.

## 19. Cleanup

Cleanup may touch only Factory-owned resources recorded durably.

Before touching a resource, verify it is not referenced by `active_turn`.

If active -> `resource_in_use`, no close/delete.

Allowed cleanup:

- exact ingested outbox directory,
- settled archived-turn Herdr workspace using exact recorded workspace ID,
- ownership-marked reviewer parent/clone after workspace close,
- ownership-marked arbiter parent/bundle after workspace close,
- task worktree only after terminal run + explicit task-worktree cleanup authority.

Native task worktree removal does not use `--force` by default. Dirty refusal is reported. Branch remains unless separately authorized.

`abandon-turn` is not cleanup: it only closes the exact active workspace, archives the abandoned turn, clears the lease, and cancels the run while preserving filesystem evidence.

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

## 21. Doctor

Doctor is non-mutating and checks:

- Node >= 20,
- Git available,
- Herdr available/server reachable,
- config parses,
- specialist gears resolve,
- foreman expected contract distinguished from current-session verification,
- provider launch specs concrete,
- state/temp roots writable,
- canonical snapshot serializer deterministic,
- run-lock primitive works,
- process-start identity probe works or is explicitly reported unavailable,
- trusted-repository warning surfaced,
- sanitized env strips synthetic secret,
- verification policy fixtures,
- review clone can be independently created and origin removed,
- required Herdr workspace lifecycle operations available.

## 22. DONE gate

DONE requires simultaneously:

1. exact run/task IDs,
2. no active turn,
3. no pending cancellation,
4. config/task/classification snapshot byte digests match run manifest,
5. canonical target repo and pinned `base_sha` unchanged in run manifest,
6. worker turn archived as settled/completed,
7. exact worker commit independently verified,
8. allowed-path audit passed,
9. committed outbox absent,
10. diff hygiene passed,
11. trusted repository checks passed,
12. final post-check worktree status acceptable,
13. reviewer turn archived as settled/completed,
14. reviewer artifact references exact same verified commit,
15. independent reviewer clone integrity passed after settlement,
16. no later mutation made evidence stale,
17. escalation policy satisfied,
18. every Factory specialist launch used pinned concrete gear spec,
19. no implicit merge/deploy/production mutation.

Foreman verification status is reported separately and never fabricated.

## 23. Runtime qualification

A provider-backed disposable smoke run must prove:

- PLAN launches nothing,
- `/execute` pins canonical repo, `base_sha`, and config/task/classification snapshots,
- mutating live config/task/classification/base branch afterward does not alter run meaning,
- snapshot byte tampering is detected,
- task worktree crash after branch creation reconciles the same branch/path,
- duplicate dispatch launches once,
- prompt ambiguity never blindly resends,
- ambiguous turn can be explicitly abandoned without retry and run becomes cancelled,
- result-before-settlement never clears active turn,
- settled worker archives turn before verification,
- verification dirt fails final status,
- reviewer parent marker exists before clone mutation,
- reviewer result is applied only after reviewer settles,
- arbiter parent marker exists before bundle population,
- cleanup refuses active-turn resources,
- stale-lock PID reuse is distinguished with process-start identity,
- second failure launches arbiter + WORK_STRONG,
- third failure stops,
- main remains unchanged.

Without this smoke run, report at most `UNIT_INTEGRATION_COMPLETE`, never `HERDR_RUNTIME_QUALIFIED`.

## 24. Review-6 corrections incorporated

1. **Immutable task/classification:** authorization snapshots and byte-digests config, task, and classification; later commands use only pinned copies.
2. **Base pin at authorization:** canonical target repo and `base_sha` are frozen when `/execute` is authorized, not later during preparation.
3. **Canonical digest semantics:** snapshot SHA-256 is over exact deterministic UTF-8 bytes; later reads verify file bytes before parsing.
4. **Partial resource recovery:** task branch-without-worktree is reconcilable; reviewer/arbiter owned parent markers are created before external clone/bundle mutation.
5. **Settled-turn handshake:** result artifact alone does not finish a turn; agent must settle, role-specific final state is captured, turn is archived, then active lease is cleared.
6. **Explicit abandonment:** ambiguous active turns can be human-abandoned without resend; exact workspace closes, evidence remains, turn archives abandoned, run cancels.
7. **PID reuse protection:** run locks include process-start identity in addition to PID/nonce; ambiguous probes fail closed with manual recovery instructions.

## 25. Deferred

Not in v0.1:

- untrusted-code container/VM sandboxing,
- automatic model catalog discovery,
- provider usage accounting,
- token-price optimization,
- multiple parallel workers on one task,
- automatic merge/deploy,
- web UI,
- remote orchestration,
- raw Herdr socket subscriber,
- direct UAL integration,
- autonomous PLAN -> EXECUTE,
- automatic permission approval.
