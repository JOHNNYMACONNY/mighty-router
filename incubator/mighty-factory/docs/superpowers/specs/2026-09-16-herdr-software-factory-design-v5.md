# Mighty Factory — Canonical v0.1 Design (Review 5)

**Status:** Canonical design for implementation  
**Date:** 2026-09-16  
**Supersedes:** Review-4, Review-3, and all 2026-09-15 Mighty Factory drafts  
**Incubation:** `mighty-router` branch `incubator/mighty-factory-v0` only

## 1. Goal

Build a small local software-factory controller around Herdr where:

- the human-facing Codex/Luna-Max session owns planning and judgment,
- deterministic Node.js code owns authority, lifecycle, concurrency, routing, verification, recovery, cleanup, and completion,
- fresh Antigravity worker turns implement bounded changes,
- fresh Cline reviewer turns independently review the exact verified commit in an isolated clone,
- escalation launches genuinely stronger fresh specialist turns,
- a crash cannot silently create a second logical turn or silently redeliver a task prompt,
- a run cannot change meaning because its configuration file changed after authorization,
- resource preparation is resumable and ownership is persisted before external mutation,
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
  | validate trust + snapshot config + pin base_sha
  v
persist intended task-resource identity
  |
  | reconcile/create task worktree
  v
claim active_turn + deterministic launch identity
  |
  | reconcile/create Herdr workspace + start agent
  | persist prompt_attempted BEFORE prompt delivery
  v
Fresh worker turn
  |
  | commit implementation, then write result outbox
  v
Controller verification
  |
  | allowed-path audit + Git invariants + trusted-repo checks
  | re-check worktree status after repo checks
  v
Independent reviewer clone (origin removed)
  |
  v
Fresh reviewer turn
  |
  +---- PASS -------------------------------> DONE gate
  |
  +---- FAIL -> repair -> arbiter -> strong worker -> replan cap
```

## 2. Security and trust model

Mighty Factory v0.1 is **not a security sandbox**.

It is designed for repositories the user already trusts enough to execute locally. Worker-generated code and repository-defined test/lint/typecheck scripts run with the user's local OS permissions. Sanitized environments reduce accidental secret exposure but do not contain filesystem or network access.

Therefore:

- v0.1 must not claim to safely execute untrusted repositories,
- `/execute` requires `execution_trust: "trusted-local-repository"`,
- verification subprocesses receive a sanitized environment,
- provider launch environments receive config-controlled variable names only,
- secret values are never persisted in run snapshots or printed in logs,
- reviewer isolation is **repository/Git-metadata isolation**, not process, filesystem, or network isolation,
- true containment of untrusted code is deferred to a future container/sandbox mode.

This limitation must be visible in `README.md`, `doctor`, and `/execute` validation.

## 3. Source of truth and authority

Herdr is the terminal/process transport, not lifecycle truth.

The controller owns:

- exact `/execute` and `/cancel` authorization,
- immutable run configuration snapshot and digest,
- run/task/turn IDs,
- run revision and dispatch lease state,
- legal lifecycle transitions,
- crash/restart reconciliation,
- prompt-delivery ambiguity handling,
- pinned Git identity,
- deterministic resource identities,
- allowed-path enforcement,
- exact gear activation,
- artifact ingestion,
- independent verification,
- reviewer clone integrity checks,
- retry/escalation limits,
- cleanup of Factory-owned resources,
- DONE eligibility.

The orchestrator owns:

- conversation and requirements,
- classification judgment,
- task-contract construction,
- architecture/planning,
- bounded repair-ticket wording,
- interpretation of arbiter recommendations.

The skill must never maintain a shadow lifecycle or manufacture transition events.

## 4. PLAN / EXECUTE / CANCEL boundary

PLAN mode is non-mutating. No specialist agent is launched.

Only exact `/execute` grants execution authority in v0.1. `build it`, `fix it`, `go for it`, or inferred intent do not count.

The public CLI does **not** expose a generic `transition` command. High-level controller commands perform internal transitions only after their invariants pass.

Public authority commands:

```text
mighty-factory authorize-execute
mighty-factory cancel
mighty-factory recover-run
```

### 4.1 Cancellation semantics

- if `active_turn == null`, cancel transitions to `CANCELLED` immediately,
- if a turn has already been durably claimed, that claim is the point of no return for the current specialist turn,
- cancellation during an active turn sets `cancel_requested: true`,
- the current claimed turn may launch/finish and its result may be ingested,
- before any new worker/reviewer/arbiter turn **or new mutation-capable verification step**, the controller transitions to `CANCELLED`,
- cancellation never erases or pretends an already-claimed turn did not exist.

## 5. Task contract

A task is durable JSON created before execution.

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

Rules:

- code-changing tasks require non-empty `allowed_paths`,
- changed paths must be inside at least one allowed prefix,
- `.mighty-factory-outbox/` may never appear in a commit,
- code-changing tasks require at least one repository-specific executable verification check,
- `execution_trust` must be the exact supported v0.1 value,
- controller-owned Git invariants are mandatory and are not model-authored commands,
- unsupported verification forms fail closed.

## 6. Immutable run configuration snapshot

The mutable operator config file is consulted only during authorization.

`authorize-execute` must:

1. load and validate the operator config,
2. normalize non-secret values,
3. resolve every policy-reachable gear to an exact concrete launch specification,
4. construct a non-secret immutable run snapshot,
5. persist `config.snapshot.json`,
6. persist its SHA-256 digest in `run.json`,
7. use that snapshot for every later route/launch/verification/cleanup decision in the run.

Snapshot content includes:

- confidence threshold,
- state/temp roots as absolute paths,
- verification policy and allowed script names,
- allowed environment variable **names**,
- provider adapter name,
- `herdr_kind`, model alias, effort label,
- exact non-secret launch argv for all reachable gears,
- artifact transport policy,
- cleanup behavior flags that are part of v0.1 policy.

Snapshot content must **not** include secret environment values, auth tokens, passwords, cookies, or provider session material.

Runtime environment values are read only when launching/running commands, filtered through the names pinned in the snapshot.

If the live config file changes after authorization, the active run is unaffected.

## 7. Trusted-repository verification policy

Supported task-authored kinds:

```text
npm-script
pnpm-script
yarn-script
node-test
node-check
```

Package-script names must be present in `verification.allowed_scripts` from the **run snapshot**. Recommended defaults:

```text
test
lint
typecheck
check
```

`build` is opt-in because build scripts can have repository-specific side effects.

Constraints:

- no shell strings,
- no arbitrary executable names,
- no `sh`, `bash`, `zsh`, `rm`, `curl`, `wget`, `npx`, package installation, migration execution, deployment, Git reset/clean/checkout/switch,
- node-test/node-check paths must be normalized repository-relative paths inside the task worktree,
- unsupported checks block rather than improvise.

Controller-owned Git checks include:

```text
git rev-parse <reported_commit>^{commit}
git merge-base --is-ancestor <base_sha> <reported_commit>
git diff --name-only <base_sha>..<reported_commit>
git diff --check <base_sha>..<reported_commit>
git status --porcelain=v1 --untracked-files=all
```

`git diff --check` is whitespace/diff hygiene, not syntax validation.

### 7.1 Verification environment

Verification subprocesses receive an explicit sanitized environment. By default only approved non-secret operational names are retained, such as:

```text
PATH
HOME
TMPDIR
LANG
LC_ALL
TERM
CI=1
```

Additional names require explicit run-snapshot allowlisting. Secret values are never printed in diagnostics or artifacts.

## 8. Allowed-path enforcement

Before reviewer dispatch, controller audits:

```text
git diff --name-only <base_sha>..<reported_commit>
```

Fail closed for:

- path traversal / absolute paths,
- files outside `allowed_paths`,
- `.mighty-factory-outbox/**` in committed tree,
- empty diff unless `allow_noop` is true.

A task can pass all tests and still fail verification if scope widened.

## 9. Pinned Git identity

`base_ref` resolves once during task preparation to immutable `base_sha` and is persisted.

All ancestry checks, diffs, reviewer inputs, and path audits use `base_sha`.

## 10. Correlation, locking, and active-turn state

Every execution has controller-generated:

```text
run_id
task_id
turn_id
```

Every specialist request/result echoes all three.

Every state-changing command uses an atomic per-run lock. Lock metadata contains nonce, PID, timestamp, and command. Existing lock returns `run_locked`; stale locks are never auto-deleted.

Explicit recovery:

```text
mighty-factory recover-run --run <id> --lock-nonce <nonce>
```

may clear a stale lock only when nonce matches and recorded PID is confirmed dead. Recovery immediately reconciles the run.

Minimum state:

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

Allowed turn stages:

```text
claimed
workspace_ready
agent_started
prompt_attempted
result_ingested
```

## 11. Crash-safe specialist dispatch and prompt delivery

A turn identity, deterministic agent name/workspace label, request artifact, prompt bytes/digest, expected result path, and gear launch spec are persisted before external launch/prompt mutation.

Dispatch flow:

1. acquire run lock,
2. validate phase and cancellation,
3. create or reuse the matching active turn,
4. reconcile/create the exact labelled workspace,
5. persist real workspace/root-pane IDs and `workspace_ready`,
6. reconcile/start deterministic agent and persist `agent_started`,
7. persist exact prompt payload/digest and set `stage=prompt_attempted` **before** calling `herdr agent prompt`,
8. call prompt once,
9. release lock after short prompt acknowledgement/timeout classification,
10. wait/inspect outside the lock,
11. ingest result under lock only for the matching active turn.

### 11.1 Prompt ambiguity rule

`prompt_attempted` means delivery may or may not have occurred.

On restart/retry:

- if a valid expected result already exists, ingest/reconcile it,
- if the deterministic agent is visibly working/idle/done and prior delivery cannot be disproved, **do not resend**,
- if Herdr/provider exposes evidence that the prompt was definitely not delivered, the same exact persisted prompt may be sent once,
- if non-delivery cannot be proven and no result can be safely ingested, transition to `BLOCKED` with operator instructions,
- never allocate a replacement turn merely because prompt delivery is ambiguous.

This favors duplicate-execution prevention over automatic retry.

## 12. Crash-safe task resource preparation

Task preparation uses deterministic intended resource identity persisted **before** `git worktree add`.

Before mutation, `run.json` records:

```json
{
  "task_branch": "mf/run-<runSuffix>",
  "task_worktree": "/absolute/factory/path/run-.../task",
  "task_resource_stage": "intended",
  "base_sha": "..."
}
```

Preparation reconciliation rules:

- intended path absent + branch absent -> create expected branch/worktree,
- exact path exists as worktree on expected branch at expected base/descendant state -> adopt,
- expected branch exists but points somewhere incompatible -> BLOCKED,
- expected path exists but is not the recorded worktree -> BLOCKED,
- multiple candidate resources -> BLOCKED,
- after successful creation/adoption set `task_resource_stage=ready`.

No new random path/branch is allocated during retry.

## 13. Worker artifact transport and verification ordering

Worker result path:

```text
<task-worktree>/.mighty-factory-outbox/<turn_id>/worker-result.json
```

Rules:

- worker commits implementation first,
- worker writes outbox after commit,
- controller rejects committed outbox files,
- exact expected outbox is the only tolerated temporary untracked path.

Verification order:

1. verify result correlation,
2. verify commit existence/HEAD/ancestry,
3. audit changed paths and committed outbox absence,
4. run controller-owned `git diff --check`,
5. check initial worktree status,
6. run all trusted-repository verification commands in sanitized environment,
7. **re-run full worktree status after all repository commands**, permitting only exact expected outbox,
8. bind evidence to exact commit.

Any verification command that dirties the checkout causes verification failure even if its exit code is zero.

## 14. Reviewer isolation: independent clone

Reviewer uses an independent disposable clone under the Factory temp root, not a linked worktree.

Intended reviewer resource identity is persisted before clone creation:

```text
<temp-root>/<run_id>/review/<turn_id>/repo/
```

with ownership nonce and resource stage.

Creation/reconciliation:

1. persist intended path + ownership nonce,
2. if absent, `git clone --no-local --no-checkout <source> <clone>`,
3. checkout detached exact verified commit,
4. remove `origin`,
5. verify clone common Git dir is internal to clone,
6. write ownership marker,
7. mark reviewer resource ready,
8. on retry, adopt only if exact path, ownership marker, commit, and no-origin invariants match; otherwise BLOCKED.

Reviewer isolation guarantees repository/Git-metadata separation from the source repository. It is not OS/process/network isolation.

Reviewer result outbox is the only tolerated working-tree delta. Any other tracked/untracked change or HEAD movement invalidates PASS.

## 15. Arbiter isolation and crash-safe bundle preparation

Arbiter receives no target checkout.

Its intended evidence bundle path and ownership nonce are persisted before directory creation:

```text
<temp-root>/<run_id>/arbiter/<turn_id>/
```

Bundle contains sanitized copied evidence only: task summary/allowed paths/verification policy, classification, commit identifiers, verification artifact, reviewer findings, repair history, adjudication question.

It must omit:

- `target_repo`,
- task worktree absolute path,
- source remote URLs,
- secrets,
- `.git` metadata.

On retry, adopt only an exact ownership-marked bundle matching the active turn.

## 16. Routing and gears

Required specialist gears:

```text
ORCH_ESCALATE_1
WORK_DEFAULT
WORK_STRONG
REVIEW_DEFAULT
REVIEW_STRONG
```

The human-facing foreman contract is recorded separately as `ORCH_DEFAULT_EXPECTED` because Factory does not own that already-running session.

### 16.1 Foreman verification semantics

- operator config may declare expected foreman model/effort, e.g. Luna/max,
- `doctor` reports this as `configured-session-contract`,
- if a supported provider/Herdr introspection mechanism can prove the current session identity, status may be `current-session-verified`,
- otherwise Factory must not claim the live foreman is verified merely because config says so,
- runtime qualification reports the distinction.

All Factory-launched specialist gears require `launch.resolved: true` and exact concrete non-secret argv in the run snapshot.

## 17. Escalation

First material review failure:

- `REPAIR_PENDING`,
- Luna creates bounded repair ticket,
- previous verification/review evidence becomes stale,
- next worker normally uses `WORK_DEFAULT`.

Second material failure:

- `ESCALATION_PENDING`,
- fresh `ORCH_ESCALATE_1` arbiter runs from evidence bundle,
- next worker uses `WORK_STRONG`.

Third material failure:

- `REPLAN_REQUIRED`,
- no fourth blind automatic dispatch.

## 18. Cleanup policy and active-turn guard

Cleanup may touch only exact resources recorded as Factory-owned.

Before deleting/closing any resource, cleanup must verify it is **not referenced by a nonterminal active turn**.

If a resource belongs to current `active_turn`, cleanup returns `resource_in_use` and leaves it untouched.

Herdr cleanup uses supported exact workspace/pane identifiers. A generic agent-stop command is not assumed.

Filesystem/Git cleanup:

- exact ingested outbox directory,
- ownership-marked reviewer clone after its workspace is closed,
- ownership-marked arbiter bundle after its workspace is closed,
- task worktree only after terminal state and explicit task-worktree cleanup authority.

Task worktree removal uses native Git without `--force` by default. Dirty refusal is reported, not overridden. Task branch remains unless separately authorized.

Cleanup is idempotent.

## 19. Public CLI surface

```text
mighty-factory help
mighty-factory doctor
mighty-factory print-config
mighty-factory route
mighty-factory authorize-execute
mighty-factory cancel
mighty-factory recover-run
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

There is no generic `transition` command.

## 20. Doctor

`doctor` is non-mutating and checks:

- Node >= 20,
- Git available,
- Herdr available/server reachable,
- config parses,
- specialist gears are resolved,
- expected foreman contract is present but distinguished from current-session verification,
- provider adapters construct concrete launch specs,
- controller state/temp roots writable,
- run-lock primitive works in disposable directory,
- trusted-repository warning is surfaced,
- sanitized env strips a synthetic secret,
- verification policy accepts safe fixtures/rejects unsafe fixtures,
- independent reviewer clone can be created and `origin` removed,
- current Herdr workspace lifecycle operations required for cleanup exist.

## 21. Authority boundaries

After `/execute`, Factory may:

- create/reconcile its recorded task worktree,
- create/reconcile independent reviewer clone and arbiter evidence bundle,
- launch configured specialists,
- let worker mutate only task worktree,
- run trusted-repository verification commands,
- commit on task branch,
- create/delete exact outbox artifacts,
- close exact owned Herdr workspaces,
- clean exact owned disposable resources.

It may not implicitly:

- merge to main,
- deploy/mutate production,
- change credentials,
- approve billing/purchases,
- install packages as verification,
- execute arbitrary task-authored commands,
- claim to sandbox untrusted code,
- reset/stash/clean unrelated user changes,
- alter Git ignore metadata,
- delete resources not recorded as Factory-owned,
- delete resources referenced by active turn,
- force-remove dirty worktrees by default.

## 22. DONE gate

DONE requires simultaneously:

1. active run/task IDs valid,
2. no conflicting active turn,
3. no pending cancellation,
4. immutable run config snapshot digest matches stored snapshot,
5. worker artifact correlated,
6. exact worker commit verified,
7. allowed-path audit passed,
8. committed outbox absent,
9. controller diff-hygiene check passed,
10. trusted-repository verification commands passed,
11. post-verification worktree status is clean except exact outbox,
12. reviewer artifact correlated and references same commit,
13. independent reviewer clone integrity passed,
14. no later mutation made evidence stale,
15. escalation/retry policy satisfied,
16. every Factory-launched specialist gear recorded concrete launch spec,
17. no implicit merge/deploy/production mutation occurred.

Foreman session verification is reported separately and is not fabricated as part of DONE.

## 23. Runtime qualification

A disposable provider-backed smoke run must prove:

- PLAN spawns nothing,
- `/execute` snapshots config and pins base SHA,
- modifying live config afterward does not change the run,
- task-worktree preparation recovers same deterministic resource after interruption,
- duplicate dispatch is prevented,
- crash/restart after agent start uses same logical turn,
- interruption around prompt attempt never blindly redelivers ambiguous prompt,
- cancellation during active turn starts no next turn,
- WORK_DEFAULT launches concrete args,
- forbidden-path change is rejected,
- disallowed verification form/script is rejected,
- sanitized verification env strips synthetic secret,
- repository checks that dirty the checkout cause verification failure,
- reviewer uses independent clone with no origin,
- reviewer clone reconciliation does not allocate alternate path,
- reviewer stray file invalidates PASS,
- arbiter bundle contains no target checkout info,
- second failure launches real arbiter + WORK_STRONG,
- third failure stops,
- cleanup refuses active-turn resources and affects only recorded owned resources,
- foreman status is reported as configured vs verified accurately,
- main remains unchanged.

If skipped, report at most `UNIT_INTEGRATION_COMPLETE`, never `HERDR_RUNTIME_QUALIFIED`.

## 24. Review-5 corrections incorporated

1. **Prompt idempotency:** persist `prompt_attempted` and prompt digest before delivery; ambiguous delivery is never blindly resent.
2. **Immutable run configuration:** authorization snapshots normalized non-secret policy/gear config and pins its digest for the entire run.
3. **Crash-safe preparation:** task worktree, reviewer clone, and arbiter bundle identities are persisted before external creation and reconciled on retry.
4. **Post-check worktree integrity:** worker status is rechecked after all repository verification commands.
5. **Cleanup active-turn guard:** resources owned by a nonterminal active turn cannot be cleaned.
6. **Reviewer guarantee wording:** independent clone provides repository/Git-metadata isolation only, not OS/process/network containment.
7. **Foreman truthfulness:** `ORCH_DEFAULT` is an expected session contract unless current-session identity can be independently verified.

## 25. Deferred work

Not in v0.1:

- true container/VM sandboxing for untrusted repositories,
- automatic provider model-catalog discovery,
- provider usage accounting,
- token-price optimization,
- multiple parallel workers on one task,
- automatic merge/deploy,
- web UI,
- remote orchestration,
- raw Herdr socket subscriber,
- direct UAL integration,
- autonomous PLAN -> EXECUTE switching,
- automatic permission approval.
