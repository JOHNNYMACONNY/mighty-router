# Mighty Factory — Canonical v0.1 Design (Review 3)

**Status:** Canonical design for implementation  
**Date:** 2026-09-16  
**Supersedes:** 2026-09-15 Mighty Factory design drafts  
**Incubation:** `mighty-router` branch `incubator/mighty-factory-v0` only

## 1. Goal

Build a small local software-factory controller around Herdr where:

- the human-facing Codex/Luna-Max session owns planning and judgment,
- deterministic Node.js code owns authority, lifecycle, concurrency, routing, verification, and completion,
- Antigravity worker turns implement changes,
- Cline reviewer turns independently review the exact verified commit,
- escalation launches genuinely stronger fresh specialist turns,
- no agent can silently widen scope, skip verification, or mutate main/deploy by default.

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
  | pin base_sha + claim run step
  v
Fresh worker turn
  |
  | commit implementation, then write result outbox
  v
Controller verification
  |
  | path audit + git invariants + safe verification commands
  v
Fresh reviewer turn in disposable review worktree
  |
  +---- PASS -------------------------------> DONE gate
  |
  +---- FAIL -> repair -> escalation -> replan cap
```

## 2. Source of truth and authority

Herdr is the terminal/process transport, not lifecycle truth.

The controller owns:

- exact `/execute` and `/cancel` authorization,
- run/task/turn IDs,
- run revision and dispatch leases,
- legal transitions,
- pinned Git identity,
- allowed-path enforcement,
- gear activation,
- artifact ingestion,
- independent verification,
- reviewer immutability checks,
- retry/escalation limits,
- cleanup of Factory-owned resources,
- DONE eligibility.

The orchestrator owns:

- conversation and requirements,
- classification judgment,
- task contract construction,
- architecture/planning,
- bounded repair-ticket wording,
- interpreting arbiter recommendations.

The skill must never maintain a shadow lifecycle or manufacture transition events.

## 3. PLAN / EXECUTE boundary

PLAN mode is non-mutating. No specialist agent is launched.

Only the exact command `/execute` grants execution authority in v0.1. `build it`, `fix it`, `go for it`, or inferred intent do not count.

Only `/cancel` requests cancellation before the next mutation-capable controller step.

The public CLI does **not** expose a generic `transition` command. High-level controller commands perform their own internal transitions only after their invariants pass.

Public authority commands:

```text
mighty-factory authorize-execute
mighty-factory cancel
```

`authorize-execute` validates the task contract, classification, configuration, verification policy, and target repository before moving PLAN -> READY.

## 4. Task contract

A task is durable JSON created before execution.

```json
{
  "schema_version": 1,
  "summary": "Implement bounded feature X",
  "target_repo": "/absolute/path/to/repo",
  "base_ref": "main",
  "allowed_paths": ["src/", "tests/"],
  "allow_noop": false,
  "verification": {
    "policy": "safe-repo-checks",
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
- controller-owned Git invariants are mandatory and are not supplied by the model,
- unsupported verification command forms fail closed.

## 5. Verification-command policy

Task-authored verification is structured, not arbitrary executable argv.

v0.1 allowlisted command kinds:

```text
npm-script       -> npm run <script> OR npm test for script=test
pnpm-script      -> pnpm run <script> OR pnpm test
 yarn-script     -> yarn run <script> OR yarn test
node-test        -> node --test [validated relative test paths]
node-check       -> node --check <validated relative .js/.mjs/.cjs path>
```

Constraints:

- no shell strings,
- no `sh`, `bash`, `zsh`, `rm`, `curl`, `wget`, `npx`, package installation, migration execution, deployment, Git reset/clean/checkout/switch, or arbitrary binary commands,
- command arguments derived from task data must be validated relative paths inside the target worktree,
- controller always runs its own Git checks regardless of task-authored commands,
- any unsupported command requires a separate human-authorized future workflow; v0.1 blocks rather than improvises.

Controller-owned Git checks include:

```text
git rev-parse <reported_commit>^{commit}
git merge-base --is-ancestor <base_sha> <reported_commit>
git diff --name-only <base_sha>..<reported_commit>
git diff --check <base_sha>..<reported_commit>
git status --porcelain=v1 --untracked-files=all
```

## 6. Allowed-path enforcement

Before reviewer dispatch, the controller audits the exact committed diff:

```text
git diff --name-only <base_sha>..<reported_commit>
```

Every changed path must satisfy at least one `allowed_paths` prefix after normalized repository-relative path validation.

Fail closed for:

- path traversal / absolute paths,
- symlink-based escape where relevant to a check,
- files outside allowed prefixes,
- `.mighty-factory-outbox/**` present in the commit,
- empty diff unless `allow_noop` is true.

A task can pass all tests and still fail verification if it changed a forbidden path.

## 7. Pinned Git identity

`base_ref` is resolved once during preparation to immutable `base_sha` and persisted.

All later ancestry checks, diff checks, reviewer prompts, and path audits use `base_sha`, never the moving branch name.

## 8. Correlation and concurrency

Correlation IDs:

```text
run_id
 task_id
turn_id
```

Every specialist request/result echoes all three.

Correlation alone is not enough. The controller also enforces single-dispatch ownership.

### 8.1 Run lock

Every state-changing command acquires a per-run controller lock before reading or mutating run state.

Lock implementation requirement:

- atomic exclusive create (`open(..., 'wx')` or equivalent),
- lock metadata records nonce, pid, created timestamp, command,
- lock is released in `finally`,
- a live lock causes `run_locked`, never concurrent mutation,
- stale-lock recovery is not automatic in v0.1; surface a BLOCKED condition with explicit operator recovery instructions.

### 8.2 State revision and active turn

`state.json` contains:

```json
{
  "revision": 12,
  "phase": "WORKING",
  "active_turn": {
    "turn_id": "turn_...",
    "role": "worker",
    "stage": "dispatched"
  }
}
```

A dispatch must atomically:

1. acquire run lock,
2. validate legal phase,
3. verify `active_turn == null`,
4. create turn ID and durable request,
5. persist `active_turn` and increment revision,
6. release lock,
7. launch the specialist.

A repeated concurrent dispatch must not launch another specialist. It returns `turn_in_progress` with the existing turn ID.

Completion/ingestion reacquires the run lock and only accepts the matching `active_turn.turn_id`.

## 9. Deterministic lifecycle

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
PLAN -> READY                 authorize-execute after validation
READY -> PREPARING            prepare-run starts
PREPARING -> WORKING          pinned worktree persisted
WORKING -> VERIFYING_WORK     matching worker artifact ingested
VERIFYING_WORK -> REVIEWING   worker verification passes
VERIFYING_WORK -> REPAIR_PENDING verification fails
REVIEWING -> VERIFYING_REVIEW matching review artifact ingested
VERIFYING_REVIEW -> DONE      review PASS + immutability + same verified commit
VERIFYING_REVIEW -> REPAIR_PENDING first material FAIL
VERIFYING_REVIEW -> ESCALATION_PENDING second material FAIL
VERIFYING_REVIEW -> REPLAN_REQUIRED third material FAIL
REPAIR_PENDING -> WORKING     bounded repair accepted; stale evidence invalidated
ESCALATION_PENDING -> WORKING correlated arbiter result accepted
nonterminal -> CANCELLED      /cancel before next mutation-capable step
nonterminal -> BLOCKED        hard external blocker
```

No public command accepts a raw event name.

## 10. Gear routing and real activation

Required reachable gears:

```text
ORCH_DEFAULT
ORCH_ESCALATE_1
WORK_DEFAULT
WORK_STRONG
REVIEW_DEFAULT
REVIEW_STRONG
```

Every gear must have `launch.resolved: true` and concrete model/effort arguments.

Routing returns gear names only. Provider adapters build actual launch argv/env.

Worker/reviewer/arbiter specialists are fresh per turn, so gear escalation launches a genuinely different configured process.

The human-facing Luna-Max orchestrator remains the foreman. `ORCH_ESCALATE_1` is a fresh bounded arbiter turn, not a relabel of the existing conversation.

## 11. Artifact transport without Git metadata mutation

Do **not** edit `.git/info/exclude`, tracked `.gitignore`, or any shared Git ignore metadata.

Default outbox paths live inside each specialist worktree:

```text
.mighty-factory-outbox/<turn_id>/worker-result.json
.mighty-factory-outbox/<turn_id>/review-result.json
.mighty-factory-outbox/<turn_id>/arbiter-result.json
```

Rules:

- worker commits implementation **before** writing its result artifact,
- reviewer/arbiter do not commit,
- controller allows only the exact expected outbox path as temporary untracked state,
- any other untracked/modified/deleted file is a verification failure for read-only roles,
- controller rejects any commit containing `.mighty-factory-outbox/**`,
- after ingestion, controller copies the artifact into external durable state and may delete only the exact Factory-owned outbox directory for that turn.

Canonical durable state:

```text
~/.local/state/mighty-factory/runs/<run_id>/
```

## 12. Worker verification

A worker result never proves completion.

Controller verification requires all of:

1. matching run/task/turn IDs,
2. reported commit exists,
3. task worktree HEAD equals reported commit,
4. `base_sha` is ancestor,
5. committed diff non-empty unless allowed,
6. committed changed paths stay inside `allowed_paths`,
7. committed tree contains no Factory outbox files,
8. controller-owned `git diff --check <base_sha>..<commit>` passes,
9. worktree status contains no unexpected changes/untracked files except the exact result outbox,
10. all safe task-contract verification commands run independently and pass,
11. evidence is bound to exact commit SHA.

Worker self-reported tests are informational only.

## 13. Reviewer isolation and immutability

Reviewer runs in a separate disposable worktree detached at the exact verified commit.

Before launch, controller records:

- HEAD,
- full `git status --porcelain=v1 --untracked-files=all`,
- base-to-head identity.

After reviewer result appears, controller rechecks full status.

Allowed delta: exactly the expected `.mighty-factory-outbox/<turn_id>/review-result.json` path.

Any other tracked or untracked path, HEAD change, deletion, rename, or commit invalidates the review.

Reviewer PASS must reference the exact controller-verified commit.

## 14. Escalation

First material review failure:

- controller enters `REPAIR_PENDING`,
- Luna produces bounded repair ticket,
- next fresh worker normally uses `WORK_DEFAULT`,
- all previous verification/review evidence becomes stale.

Second material failure:

- controller enters `ESCALATION_PENDING`,
- launches fresh `ORCH_ESCALATE_1` arbiter,
- accepts only correlated arbiter artifact,
- next worker turn uses `WORK_STRONG`.

Third material failure:

- `REPLAN_REQUIRED`,
- no fourth blind automatic dispatch.

## 15. Public CLI surface

```text
mighty-factory help
mighty-factory doctor
mighty-factory print-config
mighty-factory route
mighty-factory authorize-execute
mighty-factory cancel
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

There is no generic `transition` command in v0.1.

## 16. Cleanup policy

Factory may clean up only resources it created and persisted in `run.json` / turn launch records.

Eligible cleanup:

- exact turn outbox directories after successful ingestion,
- disposable reviewer/arbiter worktrees,
- Herdr workspaces/panes/agents recorded for the completed turn,
- task worktree only when explicitly requested after a terminal run state.

Never automatically remove:

- source repository worktrees not owned by the run,
- unrelated branches,
- unrelated panes/workspaces,
- user-created files,
- the task branch after successful implementation unless explicit cleanup authority exists.

Cleanup is idempotent. Missing already-cleaned resources are not fatal.

At terminal states, controller reports remaining Factory-owned resources even if cleanup is skipped.

## 17. Doctor

`doctor` is non-mutating and checks:

- Node >= 20,
- Git available,
- Herdr available/server reachable,
- config parses,
- six reachable gears exist and are resolved,
- provider adapters can construct concrete launch specs,
- state root controller-writable,
- run-lock primitive works in a disposable state directory,
- temporary worktree can host an untracked outbox without changing Git ignore metadata,
- verification command policy validates the configured/task fixture.

If provider model introspection is unavailable, report `configured-not-provider-validated`.

## 18. Authority boundaries

After `/execute`, Factory may:

- create task/review worktrees,
- launch configured specialists,
- let worker mutate only the task worktree,
- run safe verification commands,
- commit on the task branch,
- create/delete its exact outbox artifacts,
- clean its own disposable resources.

It may not implicitly:

- merge to main,
- deploy or mutate production,
- change credentials,
- approve billing/purchases,
- install packages as a verification side effect,
- execute arbitrary task-authored commands,
- reset/stash/clean unrelated user changes,
- alter Git ignore metadata,
- delete resources not recorded as Factory-owned.

## 19. DONE gate

DONE requires simultaneously:

1. active run/task IDs valid,
2. no conflicting active turn,
3. worker artifact correlated,
4. exact worker commit verified,
5. allowed-path audit passed,
6. outbox absent from committed tree,
7. controller-owned diff check passed,
8. safe task verification commands passed,
9. reviewer artifact correlated and references same commit,
10. reviewer full worktree immutability check passed except exact outbox,
11. no later mutation made evidence stale,
12. escalation/retry policy satisfied,
13. selected gears recorded concrete launch specs,
14. no implicit merge/deploy/production mutation occurred.

Only controller state `DONE` allows the orchestrator to summarize completion.

## 20. Runtime qualification

Unit/integration completion is not runtime qualification.

A disposable provider-backed smoke run must prove:

- PLAN spawns nothing,
- `/execute` validates and pins base SHA,
- duplicate worker dispatch is prevented,
- WORK_DEFAULT launches concrete default args,
- worker cannot pass after touching a forbidden path,
- unsafe verification command is rejected,
- controller reruns safe verification commands,
- reviewer uses separate exact-commit worktree,
- reviewer arbitrary untracked mutation invalidates PASS,
- second failure launches real arbiter + WORK_STRONG,
- third failure stops at REPLAN_REQUIRED,
- cleanup touches only recorded Factory resources,
- main remains unchanged.

If skipped, report at most `UNIT_INTEGRATION_COMPLETE`, never `HERDR_RUNTIME_QUALIFIED`.

## 21. Review 3 corrections incorporated

1. `allowed_paths` is now an enforced committed-diff invariant.
2. Generic public lifecycle mutation is removed; high-level commands own internal transitions.
3. Dispatch uses an atomic per-run lock plus `active_turn`/revision to prevent duplicate concurrent specialists.
4. Git ignore metadata is never modified; outbox is an explicitly tolerated temporary untracked path.
5. Verification commands are constrained to a safe structured allowlist; arbitrary commands fail closed.
6. Controller owns `git diff --check <base_sha>..<commit>` so committed whitespace/syntax damage cannot hide behind a clean worktree.
7. Reviewer immutability uses full porcelain status, including untracked files, with only the exact result outbox allowed.
8. Implementation commits must explicitly stage newly created files.
9. Factory-owned resource cleanup is bounded, recorded, and idempotent.
