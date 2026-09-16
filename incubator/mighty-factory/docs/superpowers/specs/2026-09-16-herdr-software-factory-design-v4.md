# Mighty Factory — Canonical v0.1 Design (Review 4)

**Status:** Canonical design for implementation  
**Date:** 2026-09-16  
**Supersedes:** Review-3 and all 2026-09-15 Mighty Factory drafts  
**Incubation:** `mighty-router` branch `incubator/mighty-factory-v0` only

## 1. Goal

Build a small local software-factory controller around Herdr where:

- the human-facing Codex/Luna-Max session owns planning and judgment,
- deterministic Node.js code owns authority, lifecycle, concurrency, routing, verification, recovery, cleanup, and completion,
- fresh Antigravity worker turns implement bounded changes,
- fresh Cline reviewer turns independently review the exact verified commit in an isolated clone,
- escalation launches genuinely stronger fresh specialist turns,
- a crash cannot silently create a second logical turn,
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
  | validate trust + pin base_sha + prepare task worktree
  v
claim active_turn + deterministic launch identity
  |
  v
Fresh worker turn
  |
  | commit implementation, then write result outbox
  v
Controller verification
  |
  | allowed-path audit + Git invariants + trusted-repo checks
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

It is designed for repositories the user already trusts enough to execute locally. Worker-generated code and repository-defined test/lint/typecheck scripts run with the user's local OS permissions. Even with an environment allowlist, trusted repository code may access files or the network through normal OS APIs.

Therefore:

- v0.1 must not claim to safely execute untrusted repositories,
- `/execute` requires the task contract to declare `execution_trust: "trusted-local-repository"`,
- verification subprocesses receive a sanitized environment, but this is defense-in-depth rather than a sandbox guarantee,
- specialist launch environments are sanitized by provider adapters, but provider authentication mechanisms may still make local credentials available to the provider CLI,
- true containment of untrusted code is deferred to a future container/sandbox execution mode.

This limitation must be visible in `README.md`, `doctor`, and `/execute` validation.

## 3. Source of truth and authority

Herdr is the terminal/process transport, not lifecycle truth.

The controller owns:

- exact `/execute` and `/cancel` authorization,
- run/task/turn IDs,
- run revision and dispatch lease state,
- legal lifecycle transitions,
- crash/restart reconciliation,
- pinned Git identity,
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

## 4. PLAN / EXECUTE / CANCEL authority boundary

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

`/cancel` is deterministic around active turns:

- if `active_turn == null`, cancel transitions the run to `CANCELLED` immediately,
- if a turn has already been durably claimed, that claim is the point of no return for the current specialist turn,
- cancellation during an active turn sets `cancel_requested: true`,
- the current claimed turn may launch/finish and its result may be ingested,
- before any new worker/reviewer/arbiter turn or new mutation-capable verification step, the controller transitions to `CANCELLED`,
- cancellation never erases or pretends an already-claimed turn did not exist.

This removes the claim/launch race from cancellation semantics.

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

## 6. Trusted-repository verification policy

Task-authored verification is structured, not arbitrary executable argv.

Supported kinds:

```text
npm-script
pnpm-script
yarn-script
node-test
node-check
```

Package-script names must also be present in `verification.allowed_scripts` from validated Factory configuration. Recommended v0.1 defaults are:

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
- controller always runs its own Git checks regardless of task-authored commands,
- unsupported checks require a future separately-authorized workflow; v0.1 blocks.

Controller-owned Git checks include:

```text
git rev-parse <reported_commit>^{commit}
git merge-base --is-ancestor <base_sha> <reported_commit>
git diff --name-only <base_sha>..<reported_commit>
git diff --check <base_sha>..<reported_commit>
git status --porcelain=v1 --untracked-files=all
```

`git diff --check` is a whitespace/diff-hygiene check. It is **not** a syntax validator. Syntax/type/build correctness comes from configured repository checks such as `node-check`, `typecheck`, tests, or an explicitly allowed build script.

### 6.1 Verification environment

Verification subprocesses use an explicit environment builder.

By default retain only non-secret operational variables needed for local tooling, such as:

```text
PATH
HOME
TMPDIR
LANG
LC_ALL
TERM
CI=1
```

Additional variable names require explicit config allowlisting. Values are never printed by `doctor`, `print-config`, launch records, or verification summaries.

This reduces accidental environment-secret exposure but does not make trusted repository code sandboxed; code may still read files accessible to the user account.

## 7. Allowed-path enforcement

Before reviewer dispatch, controller audits the exact committed diff:

```text
git diff --name-only <base_sha>..<reported_commit>
```

Every changed path must satisfy at least one normalized `allowed_paths` prefix.

Fail closed for:

- path traversal / absolute paths,
- files outside allowed prefixes,
- `.mighty-factory-outbox/**` present in the committed tree,
- empty diff unless `allow_noop` is true.

A task can pass all tests and still fail verification if it changed a forbidden path.

## 8. Pinned Git identity

`base_ref` is resolved once during preparation to immutable `base_sha` and persisted.

All later ancestry checks, diffs, reviewer inputs, and path audits use `base_sha`, never the moving branch name.

## 9. Durable correlation, locking, and dispatch leases

Every execution has controller-generated:

```text
run_id
 task_id
turn_id
```

Every specialist request/result echoes all three.

Correlation prevents stale results from satisfying a new turn. Dispatch leasing prevents duplicate specialists from mutating concurrently.

### 9.1 Per-run lock

Every state-changing command uses an atomic per-run lock.

Lock metadata contains:

```json
{
  "nonce": "...",
  "pid": 12345,
  "created_at": "...",
  "command": "dispatch-worker"
}
```

Rules:

- acquire by exclusive create (`open(..., "wx")` or equivalent),
- release in `finally`,
- existing lock returns `run_locked`,
- no automatic stale-lock deletion.

### 9.2 Explicit stale-lock recovery

`recover-run --run <id> --lock-nonce <nonce>` is the only v0.1 stale-lock recovery path.

It may clear a lock only when:

1. nonce exactly matches durable lock metadata,
2. controller can determine the recorded PID is no longer alive on the local machine,
3. no second live controller owns the run,
4. active-turn reconciliation is performed immediately afterward.

If PID liveness is ambiguous, recovery fails closed and prints operator instructions.

### 9.3 Active turn shape

```json
{
  "revision": 12,
  "phase": "WORKING",
  "cancel_requested": false,
  "active_turn": {
    "turn_id": "turn_...",
    "role": "worker",
    "stage": "claimed",
    "agent_name": "mf-worker-a1b2-c3d4",
    "workspace_label": "mighty-factory:turn_..."
  }
}
```

Allowed stages:

```text
claimed
workspace_ready
launched
result_ingested
```

A turn identity, deterministic agent name, deterministic workspace label, request artifact, and expected result path are persisted **before** external launch.

## 10. Crash-safe specialist dispatch and reconciliation

Specialist dispatch is resumable and idempotent with respect to one logical turn.

Fresh specialist workspaces use one Herdr workspace/root pane per turn; no pane split is required.

Dispatch flow:

1. acquire run lock,
2. validate phase and `cancel_requested`,
3. if no active turn, create/persist turn ID + deterministic agent/workspace identity and `stage=claimed`,
4. if the matching active turn already exists, reuse it; do not allocate a second turn,
5. create/reconcile the Herdr workspace labelled exactly for that turn,
6. persist returned workspace/root-pane IDs and `stage=workspace_ready`,
7. start or reconcile the deterministic agent name with exact gear argv,
8. persist launch record and `stage=launched`,
9. release lock after Herdr acknowledges the short launch operation,
10. wait/inspect outside the lock,
11. result ingestion reacquires lock and accepts only the matching active turn.

### 10.1 Reconciliation rules

When a dispatch command is repeated after crash/restart:

- `claimed` + no matching workspace/agent -> resume the same turn identity and launch it,
- matching uniquely-labelled workspace but missing durable workspace ID -> adopt that workspace and persist its real ID,
- matching agent exists -> adopt it as the same turn; never launch a second agent,
- more than one matching workspace/agent -> `BLOCKED` because uniqueness cannot be proven,
- `launched` + agent missing + valid expected result exists -> ingest/reconcile result,
- `launched` + agent missing + no result -> `BLOCKED`; do not silently create a replacement turn,
- stale result from another turn never clears the active lease.

A controller crash between an external Herdr mutation and durable persistence therefore has a deterministic reconciliation target instead of an unbounded orphan.

## 11. Deterministic lifecycle

States:

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

Representative internal transitions:

```text
PLAN -> READY                    authorize-execute after validation
READY -> PREPARING               prepare-run starts
PREPARING -> WORKING             pinned worktree persisted
WORKING -> VERIFYING_WORK        matching worker artifact ingested
VERIFYING_WORK -> REVIEWING      worker verification passes
VERIFYING_WORK -> REPAIR_PENDING verification fails
REVIEWING -> VERIFYING_REVIEW    matching review artifact ingested
VERIFYING_REVIEW -> DONE         PASS + clone integrity + same verified commit
VERIFYING_REVIEW -> REPAIR_PENDING       first material FAIL
VERIFYING_REVIEW -> ESCALATION_PENDING   second material FAIL
VERIFYING_REVIEW -> REPLAN_REQUIRED      third material FAIL
REPAIR_PENDING -> WORKING        repair accepted; evidence invalidated
ESCALATION_PENDING -> WORKING    correlated arbiter result accepted
nonterminal with no active turn -> CANCELLED       immediate cancel
nonterminal with active turn -> cancel_requested   finish current turn, then cancel
nonterminal -> BLOCKED           hard external/recovery ambiguity
```

No public command accepts a raw event name.

## 12. Gear routing and real activation

Required gears:

```text
ORCH_DEFAULT
ORCH_ESCALATE_1
WORK_DEFAULT
WORK_STRONG
REVIEW_DEFAULT
REVIEW_STRONG
```

Every reachable gear must have `launch.resolved: true` and concrete model/effort arguments.

Worker/reviewer/arbiter specialists are fresh per turn, so escalation launches a genuinely different configured process.

The human-facing Luna-Max session remains the foreman. `ORCH_ESCALATE_1` is a fresh bounded arbiter process, not a relabel of the existing conversation.

Provider adapters build exact argv and a sanitized launch environment. Environment variable names permitted for provider launch are config-controlled; secret values are never recorded.

## 13. Worker artifact transport

Do **not** modify `.git/info/exclude`, `.gitignore`, or shared Git ignore metadata.

Worker result path:

```text
<task-worktree>/.mighty-factory-outbox/<turn_id>/worker-result.json
```

Rules:

- worker commits implementation first,
- worker writes result outbox after commit,
- controller allows exactly that expected outbox path as temporary untracked state,
- any other unexpected worktree state fails verification,
- controller rejects any commit containing `.mighty-factory-outbox/**`,
- after ingestion the external durable copy is canonical.

## 14. Worker verification

Controller verification requires:

1. matching run/task/turn IDs,
2. reported commit exists,
3. task worktree HEAD equals reported commit,
4. `base_sha` is ancestor,
5. diff non-empty unless allowed,
6. changed paths stay inside `allowed_paths`,
7. committed tree contains no Factory outbox,
8. controller-owned `git diff --check <base_sha>..<commit>` passes,
9. worktree status has no unexpected delta except exact worker-result outbox,
10. trusted-repository verification commands run independently in the sanitized environment and pass,
11. evidence is bound to exact commit SHA.

Worker-reported tests are informational only.

## 15. Reviewer isolation: independent clone, not linked worktree

Reviewer turns do **not** use a linked Git worktree.

The controller creates an independent disposable clone under a Factory-owned temp root:

```text
<temp-root>/<run_id>/review/<turn_id>/repo/
```

Preparation sequence:

1. `git clone --no-local --no-checkout <source-repo> <review-clone>`,
2. `git -C <review-clone> checkout --detach <verified_commit>`,
3. verify HEAD equals the exact commit,
4. `git -C <review-clone> remote remove origin`,
5. record an ownership marker containing run/turn nonce,
6. snapshot full status and Git config/refs inside the clone as diagnostic evidence,
7. launch reviewer with cwd equal to this independent clone.

Removing `origin` prevents ordinary Git push paths back into the source repository. The clone has its own object database and Git metadata.

This is repository-metadata isolation, not an OS security sandbox; the trusted-repository model still applies.

### 15.1 Reviewer result and integrity

Reviewer outbox:

```text
<review-clone>/.mighty-factory-outbox/<turn_id>/review-result.json
```

After result appears, controller verifies:

- HEAD remains exact verified commit,
- full porcelain status differs only by the exact review result outbox,
- no commit was created,
- expected review artifact references exact verified commit.

Any other tracked/untracked change invalidates PASS.

Because the clone is independent and `origin` is removed, reviewer Git metadata mutations are confined to the disposable clone rather than the source repository.

## 16. Arbiter isolation

Arbiter does not receive a task repository checkout.

Controller creates a Factory-owned evidence bundle directory:

```text
<temp-root>/<run_id>/arbiter/<turn_id>/
```

It contains copied/sanitized inputs only:

- task contract,
- classification,
- `base_sha` and verified commit identifiers,
- controller verification artifact,
- reviewer findings,
- repair history,
- exact adjudication question.

Arbiter cwd is this bundle directory. Its only expected write is:

```text
.mighty-factory-outbox/<turn_id>/arbiter-result.json
```

No target checkout is available through the intended workspace contract.

## 17. Escalation

First material review failure:

- `REPAIR_PENDING`,
- Luna creates bounded repair ticket,
- previous verification/review evidence becomes stale,
- next worker normally uses `WORK_DEFAULT`.

Second material failure:

- `ESCALATION_PENDING`,
- fresh `ORCH_ESCALATE_1` arbiter runs in isolated evidence bundle,
- only correlated arbiter result is accepted,
- next worker uses `WORK_STRONG`.

Third material failure:

- `REPLAN_REQUIRED`,
- no fourth blind automatic dispatch.

## 18. Public CLI surface

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

## 19. Cleanup policy

Cleanup may touch only exact resources recorded as Factory-owned.

### 19.1 Herdr resources

Every specialist turn records its real Herdr `workspace_id` and `pane_id`.

Cleanup uses supported Herdr lifecycle operations for those exact IDs:

```text
herdr workspace close <workspace_id>
herdr pane close <pane_id>        # only when pane-level close is needed
```

A dedicated generic `agent stop` operation is not assumed.

### 19.2 Filesystem/Git resources

Eligible cleanup:

- exact ingested turn outbox directory,
- independent reviewer clone after workspace close,
- arbiter evidence bundle after workspace close,
- native task worktree only after terminal state and explicit task-worktree cleanup authority.

Task worktree removal uses native Git because v0.1 creates it with native Git:

```text
git -C <source-repo> worktree remove <task-worktree>
```

Do not use `--force` by default. Dirty-removal refusal becomes a cleanup warning/blocker, not destructive cleanup. The task branch is retained unless separately authorized.

For independent clone/bundle directory deletion, controller requires:

- path under configured Factory temp root,
- exact ownership marker matching run/turn nonce,
- resource recorded in `run.json`/launch record.

Cleanup is idempotent. Missing already-cleaned resources are not fatal.

## 20. Doctor

`doctor` is non-mutating and checks:

- Node >= 20,
- Git available,
- Herdr available/server reachable,
- config parses,
- all six gears resolved,
- provider adapters construct concrete launch specs,
- controller state/temp roots writable,
- run-lock primitive works in disposable directory,
- trusted-repository warning is surfaced,
- verification environment sanitizer strips a synthetic secret variable,
- verification policy accepts safe fixtures and rejects unsafe/script-name-disallowed fixtures,
- independent review clone can be created and have `origin` removed,
- Herdr workspace lifecycle operations used by cleanup are available.

If provider model introspection is unavailable, report `configured-not-provider-validated`.

## 21. Authority boundaries

After `/execute`, Factory may:

- create task worktree, independent review clone, and arbiter evidence bundle,
- launch configured specialists,
- let worker mutate only the task worktree,
- run trusted-repository verification commands,
- commit on the task branch,
- create/delete exact outbox artifacts,
- close exact owned Herdr workspaces,
- clean exact owned disposable resources.

It may not implicitly:

- merge to main,
- deploy or mutate production,
- change credentials,
- approve billing/purchases,
- install packages as verification,
- execute arbitrary task-authored commands,
- claim to sandbox untrusted repository code,
- reset/stash/clean unrelated user changes,
- alter Git ignore metadata,
- delete resources not recorded as Factory-owned,
- force-remove dirty worktrees by default.

## 22. DONE gate

DONE requires simultaneously:

1. active run/task IDs valid,
2. no conflicting active turn,
3. no pending cancellation,
4. worker artifact correlated,
5. exact worker commit verified,
6. allowed-path audit passed,
7. outbox absent from committed tree,
8. controller-owned diff-hygiene check passed,
9. trusted-repository verification commands passed in sanitized environment,
10. reviewer artifact correlated and references same commit,
11. independent reviewer clone integrity check passed,
12. no later mutation made evidence stale,
13. escalation/retry policy satisfied,
14. selected gears recorded concrete launch specs,
15. no implicit merge/deploy/production mutation occurred.

Only controller state `DONE` allows the orchestrator to summarize completion.

## 23. Runtime qualification

Unit/integration completion is not runtime qualification.

A disposable provider-backed smoke run must prove:

- PLAN spawns nothing,
- `/execute` validates trusted-repository mode and pins base SHA,
- duplicate dispatch is prevented,
- crash/restart reconciliation resumes one logical turn rather than creating a second,
- cancellation during an active turn stops before the next turn,
- WORK_DEFAULT launches concrete args,
- worker cannot pass after forbidden-path change,
- disallowed verification script/command is rejected,
- sanitized verification environment does not inherit a synthetic secret,
- reviewer uses independent exact-commit clone with `origin` removed,
- reviewer arbitrary untracked mutation invalidates PASS,
- arbiter runs from evidence bundle rather than task checkout,
- second failure launches real arbiter + WORK_STRONG,
- third failure stops at REPLAN_REQUIRED,
- cleanup closes/removes only recorded Factory-owned resources,
- main remains unchanged.

If skipped, report at most `UNIT_INTEGRATION_COMPLETE`, never `HERDR_RUNTIME_QUALIFIED`.

## 24. Review-4 corrections incorporated

1. **Crash recovery:** dispatch is resumable using persisted deterministic launch identity, staged `active_turn`, explicit stale-lock recovery, and reconciliation instead of allocating a second turn.
2. **Honest execution isolation:** v0.1 is explicitly trusted-repository execution, not a security sandbox; verification and provider environments are sanitized defense-in-depth.
3. **Reviewer isolation:** reviewer uses an independent `--no-local` clone with `origin` removed rather than a linked worktree sharing repository metadata.
4. **Arbiter isolation:** arbiter receives only a disposable evidence bundle, not the target checkout.
5. **Cancel race:** once a turn is claimed, cancellation becomes `cancel_requested` and takes effect before the next turn/mutation-capable step.
6. **Environment policy:** verification and provider subprocess environments use explicit variable-name allowlists and never log secret values.
7. **Diff-check wording:** `git diff --check` is defined correctly as whitespace/diff hygiene, not syntax validation.
8. **Lifecycle cleanup:** cleanup uses real Herdr workspace/pane close operations, native safe Git worktree removal without force, and ownership markers for independent temporary directories.

## 25. Current Herdr lifecycle assumptions

The design relies only on currently documented Herdr primitives that v0.1 needs:

- `workspace create/list/get/close`,
- `pane list/get/close`,
- `agent start/get/prompt/wait/read`.

The implementation must lock exact argv/JSON response shapes in tests against the locally installed Herdr version before provider-backed qualification.

## 26. Deferred work

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
