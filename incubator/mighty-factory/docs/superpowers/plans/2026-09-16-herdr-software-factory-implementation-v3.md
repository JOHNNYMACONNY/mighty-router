# Mighty Factory v0.1 Implementation Plan — Review 3

> **Required execution style:** implement task-by-task with TDD. After each task: focused tests, full `npm test`, `git diff --check`, explicit staging of that task's files, commit, then independent review before continuing.

**Goal:** Implement the canonical 2026-09-16 Mighty Factory design as a dependency-free Node.js controller around Herdr with safe authority boundaries, pinned Git identity, exact gear activation, duplicate-dispatch prevention, enforced path scope, safe verification policy, independent review, bounded escalation, and owned-resource cleanup.

**Canonical spec:** `docs/superpowers/specs/2026-09-16-herdr-software-factory-design-v3.md`

**Runtime:** Node.js >= 20, ESM, `node:test`, built-in `fs`, `path`, `crypto`, `child_process`; native Git; no runtime npm dependencies.

## Global implementation rules

- Work only under `incubator/mighty-factory/` on `incubator/mighty-factory-v0`.
- Do not modify Mighty Router mainline behavior or UAL.
- TDD: observe RED before production implementation, then GREEN.
- No generic public `transition` CLI.
- Every state-changing command uses per-run locking.
- Every specialist dispatch atomically claims `active_turn` before launch.
- Never edit `.git/info/exclude` or tracked `.gitignore` for Factory outboxes.
- Worker commits implementation before writing result outbox.
- Controller enforces allowed paths from `base_sha..<reported_commit>`.
- Controller runs its own `git diff --check <base_sha>..<reported_commit>`.
- Task verification commands use structured allowlisted kinds only.
- Reviewer immutability includes untracked files; only exact outbox path is tolerated.
- Never use `git commit -am` for tasks that create files. Explicitly stage task files.
- Cleanup may touch only exact resources recorded as Factory-owned.

---

## Task 1 — Package scaffold, authority CLI, task/classification schemas

**Create:**
- `package.json`
- `bin/mighty-factory.js`
- `src/cli.js`
- `src/errors.js`
- `src/task-contract.js`
- `src/classify-schema.js`
- `tests/cli.test.js`
- `tests/task-contract.test.js`
- `tests/classify-schema.test.js`

**Interfaces:**
- `main(argv, io = { stdout: process.stdout, stderr: process.stderr }) -> Promise<number>`
- `validateTaskContract(value, classification)`
- `validateClassification(value)`

**Public command names reserved from day one:**

```text
help doctor print-config route authorize-execute cancel prepare-run
dispatch-worker verify-worker dispatch-reviewer verify-review
dispatch-arbiter record-repair status cleanup
```

No `transition` command.

**RED tests:**
1. `help` lists every command above and omits `transition`.
2. unknown command exits 2.
3. reserved unimplemented command exits operationally, not usage-error.
4. code task rejects empty `allowed_paths`.
5. code task rejects empty verification commands.
6. task path prefixes reject absolute paths / `..` traversal.
7. classification validates exact enums and confidence `0..1`.

**Implementation requirements:**
- `UsageError` -> exit 2.
- `OperationalError` -> exit 1.
- task contract verification command objects are schema-validated but policy enforcement lands Task 5.

**Verify:**

```bash
cd incubator/mighty-factory
node --test tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
npm test
git diff --check
```

**Stage/commit:**

```bash
git add package.json bin/mighty-factory.js src/cli.js src/errors.js \
  src/task-contract.js src/classify-schema.js \
  tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
git commit -m "feat(factory): scaffold authority and task contracts"
```

---

## Task 2 — Config, concrete gears, adapters, deterministic route

**Create:**
- `factory.config.example.json`
- `src/config.js`
- `src/route.js`
- `src/provider-adapters/index.js`
- `src/provider-adapters/codex.js`
- `src/provider-adapters/cline.js`
- `src/provider-adapters/antigravity.js`
- `tests/config.test.js`
- `tests/route.test.js`
- `tests/provider-adapters.test.js`

**Modify:** `src/cli.js`

**Required gears:**

```text
ORCH_DEFAULT ORCH_ESCALATE_1 WORK_DEFAULT WORK_STRONG REVIEW_DEFAULT REVIEW_STRONG
```

Each reachable gear requires:

```json
{
  "provider_adapter": "codex",
  "herdr_kind": "codex",
  "model_alias": "friendly-name",
  "effort": "max",
  "launch": {
    "resolved": true,
    "model_args": ["--model", "concrete-local-model-id"],
    "effort_args": ["--config", "model_reasoning_effort=max"],
    "extra_args": []
  }
}
```

**RED tests:**
- missing any reachable gear fails.
- `launch.resolved !== true` fails.
- model/effort args missing for a model/effort-bearing gear fails.
- `ORCH_DEFAULT.effort !== max` fails.
- route low confidence -> clarification.
- high risk -> `REVIEW_STRONG`.
- second material failure -> `require_arbiter`, `ORCH_ESCALATE_1`, `WORK_STRONG`.
- router fails if selected gear absent.
- adapter emits exact concrete argv; never raw routing flags.

**Verify/commit:**

```bash
node --test tests/config.test.js tests/route.test.js tests/provider-adapters.test.js
npm test
git diff --check
git add factory.config.example.json src/config.js src/route.js \
  src/provider-adapters/index.js src/provider-adapters/codex.js \
  src/provider-adapters/cline.js src/provider-adapters/antigravity.js \
  src/cli.js tests/config.test.js tests/route.test.js tests/provider-adapters.test.js
git commit -m "feat(factory): add resolved deterministic gears"
```

---

## Task 3 — Durable state, run locking, active-turn lease, lifecycle

**Create:**
- `src/ids.js`
- `src/run-lock.js`
- `src/state-machine.js`
- `src/state-store.js`
- `tests/ids.test.js`
- `tests/run-lock.test.js`
- `tests/state-machine.test.js`
- `tests/state-store.test.js`

**Modify:** `src/cli.js`

**State shape minimum:**

```json
{
  "revision": 0,
  "phase": "PLAN",
  "active_turn": null,
  "material_failures": 0,
  "verification_stale": false,
  "review_stale": false
}
```

**Interfaces:**
- `createId(prefix)`
- `withRunLock(runDir, command, fn)`
- `transitionInternal(state, event, payload)` — not exported by CLI
- `createStateStore(root)`
- `claimTurn({ runId, role, expectedPhase }, fn)` or equivalent controller primitive that persists `active_turn` atomically under the run lock.

**RED tests:**
1. exclusive lock second acquisition returns `run_locked`.
2. lock released in `finally` after thrown error.
3. stale lock is **not** auto-broken.
4. two concurrent worker claims cannot both succeed.
5. second dispatch reports existing active turn / `turn_in_progress` and launches nothing.
6. matching completion clears exact active turn; mismatched turn cannot.
7. state revision increments on each durable state mutation.
8. review failure progression caps at repair/escalation/replan.
9. repair invalidates old evidence.
10. public CLI contains `authorize-execute`/`cancel`, no arbitrary event input.

**Lock metadata:** nonce, pid, timestamp, command.

**Verify/commit:**

```bash
node --test tests/ids.test.js tests/run-lock.test.js tests/state-machine.test.js tests/state-store.test.js
npm test
git diff --check
git add src/ids.js src/run-lock.js src/state-machine.js src/state-store.js src/cli.js \
  tests/ids.test.js tests/run-lock.test.js tests/state-machine.test.js tests/state-store.test.js
git commit -m "feat(factory): serialize lifecycle and turn dispatch"
```

---

## Task 4 — Pinned Git identity, worktrees, outbox transport, artifact correlation

**Create:**
- `src/git.js`
- `src/artifacts.js`
- `tests/git.test.js`
- `tests/artifacts.test.js`

**Interfaces:**
- `resolveBaseSha(repo, baseRef, runner)`
- `createTaskWorktree({ repo, baseSha, branch, path }, runner)`
- `createReviewWorktree({ repo, commit, path }, runner)`
- `getOutboxPath(worktree, turnId, role)`
- `ingestResult({ source, destination, expected })`
- `assertCorrelation(artifact, expected)`
- `listCommittedPaths(repo, baseSha, commit, runner)`
- `assertNoOutboxCommitted(repo, commit, runner)`

**Critical rule:** do not edit Git ignore metadata.

**RED tests with real temp Git repo:**
1. pin A from `main`; advance `main` to B; run still uses A.
2. worker result outbox is untracked; `.git/info/exclude` content unchanged.
3. committed outbox path is rejected.
4. stale run/task/turn IDs rejected.
5. reviewer result commit mismatch rejected.
6. arbiter artifact schema correlated.

**Worker ordering contract:** implementation commit first; result file after commit.

**Verify/commit:**

```bash
node --test tests/git.test.js tests/artifacts.test.js
npm test
git diff --check
git add src/git.js src/artifacts.js tests/git.test.js tests/artifacts.test.js
git commit -m "feat(factory): pin git state and correlate outbox artifacts"
```

---

## Task 5 — Safe verification policy + allowed-path audit + controller Git checks

**Create:**
- `src/command-runner.js`
- `src/verification-policy.js`
- `src/verifier.js`
- `tests/verification-policy.test.js`
- `tests/verifier.test.js`

**Allowed task verification kinds:**

```text
npm-script
pnpm-script
yarn-script
node-test
node-check
```

No generic `command`/`args` arbitrary process execution in task contracts.

**Interfaces:**
- `compileVerificationCommand(check, context) -> { command, args }`
- `assertAllowedPaths(changedPaths, allowedPrefixes)`
- `verifyWorker({ run, task, turn, reportedCommit }, deps)`

**RED tests:**
1. `rm`, `bash`, `npx`, `curl`, package installation, migrations, arbitrary binaries cannot be represented/accepted.
2. validated repo script compiles to expected argv.
3. task with passing tests but change to forbidden `package.json` fails path audit.
4. normalized traversal path fails.
5. outbox committed in tree fails.
6. worker reports tests PASS but controller-run test exits 1 -> verification FAIL.
7. controller runs `git diff --check base..commit`; committed whitespace error fails even when worktree clean.
8. only exact worker result outbox may remain untracked at worker-verification time; any other unexpected status fails.
9. all verification evidence is bound to exact commit.

**Controller Git invariants are hard-coded controller logic**, not model-supplied checks.

**Verify/commit:**

```bash
node --test tests/verification-policy.test.js tests/verifier.test.js tests/git.test.js
npm test
git diff --check
git add src/command-runner.js src/verification-policy.js src/verifier.js \
  tests/verification-policy.test.js tests/verifier.test.js
git commit -m "feat(factory): enforce safe scoped verification"
```

---

## Task 6 — Herdr wrapper and fresh concrete specialist launches

**Create:**
- `src/herdr.js`
- `src/turn-launcher.js`
- `tests/herdr.test.js`
- `tests/turn-launcher.test.js`

**Interfaces:**
- `createHerdrClient(runner)`
- `launchFreshTurn({ run, role, gearName, cwd, prompt, resultPath }, deps)`

**RED tests:**
- parse synthetic Herdr JSON IDs rather than predict pane IDs.
- blocked fails immediately.
- unknown is never completion.
- working target settles before prompt.
- timeout/stall returns inspect-required state, no blind resend.
- WORK_DEFAULT and WORK_STRONG produce distinct fresh `agent start` calls with different argv.
- ORCH_ESCALATE_1 arbiter is a fresh Codex process, not Luna relabel.
- launch record persists exact gear, argv, role, Herdr IDs.

**Concurrency precondition:** `launchFreshTurn` may only be invoked after controller has already persisted matching `active_turn` under lock.

**Verify/commit:**

```bash
node --test tests/herdr.test.js tests/turn-launcher.test.js
npm test
git diff --check
git add src/herdr.js src/turn-launcher.js tests/herdr.test.js tests/turn-launcher.test.js
git commit -m "feat(factory): launch fresh specialists per claimed turn"
```

---

## Task 7 — Run preparation and reviewer full immutability

**Create:**
- `src/prepare-run.js`
- `src/review-guard.js`
- `tests/prepare-run.test.js`
- `tests/review-guard.test.js`

**Modify:** `src/cli.js`

**Preparation:**
1. lock run.
2. validate READY.
3. pin `base_sha`.
4. create task branch/worktree from base SHA.
5. persist exact resource ownership in `run.json`.
6. do **not** launch specialists.
7. no Git ignore mutation.

**Review guard:**
- create disposable detached review worktree at verified commit.
- snapshot `git status --porcelain=v1 --untracked-files=all` and HEAD before review.
- after review, accept exactly the expected review-result outbox as the only state delta.
- any other untracked path, tracked change, rename, delete, or HEAD change fails immutability.

**RED tests:**
- preparation stores base ref + SHA and owned worktree path.
- no `agent start` during prepare.
- preexisting source-repo dirt is not reset/stashed/cleaned.
- reviewer creates `notes.tmp` -> PASS rejected.
- reviewer modifies tracked file -> rejected.
- reviewer only writes exact outbox -> immutability passes.

**Verify/commit:**

```bash
node --test tests/prepare-run.test.js tests/review-guard.test.js
npm test
git diff --check
git add src/prepare-run.js src/review-guard.js src/cli.js \
  tests/prepare-run.test.js tests/review-guard.test.js
git commit -m "feat(factory): prepare pinned runs and guard reviewer immutability"
```

---

## Task 8 — Controller operations, real dispatch leases, repair/escalation, CLI reachability

**Create:**
- `src/controller.js`
- `tests/controller.test.js`

**Modify:**
- `src/cli.js`
- `src/state-machine.js`
- `src/state-store.js`
- `src/artifacts.js`

**Controller operations:**

```text
authorizeExecute
cancel
prepareRun
dispatchWorker
verifyWorker
dispatchReviewer
verifyReview
dispatchArbiter
recordRepair
status
cleanup
```

**RED tests:**
1. happy path to DONE with distinct worker/reviewer turns.
2. double `dispatch-worker` while first active launches exactly one agent.
3. double reviewer dispatch launches exactly one reviewer.
4. stale result cannot clear current `active_turn`.
5. first material FAIL -> repair pending.
6. second material FAIL -> fresh ORCH_ESCALATE_1 arbiter, then WORK_STRONG worker.
7. third material FAIL -> replan; fourth automatic dispatch impossible.
8. reviewer PASS cannot produce DONE if verification stale.
9. CLI has every high-level operation and no raw transition command.

**CLI examples:**

```text
mighty-factory authorize-execute --task task.json --classification classification.json --config factory.config.json
mighty-factory prepare-run --run <id>
mighty-factory dispatch-worker --run <id>
mighty-factory verify-worker --run <id> --turn <id>
mighty-factory dispatch-reviewer --run <id>
mighty-factory verify-review --run <id> --turn <id>
mighty-factory dispatch-arbiter --run <id>
mighty-factory record-repair --run <id> --file repair.json
mighty-factory cancel --run <id>
mighty-factory status --run <id>
```

**Verify/commit:**

```bash
node --test tests/controller.test.js tests/run-lock.test.js tests/state-machine.test.js
npm test
git diff --check
git add src/controller.js src/cli.js src/state-machine.js src/state-store.js src/artifacts.js \
  tests/controller.test.js
git commit -m "feat(factory): enforce leased worker review escalation loop"
```

---

## Task 9 — Doctor, prompts, orchestrator skill, bounded cleanup

**Create:**
- `src/doctor.js`
- `src/cleanup.js`
- `prompts/worker.md`
- `prompts/reviewer.md`
- `prompts/arbiter.md`
- `skills/mighty-factory-orchestrator/SKILL.md`
- `tests/doctor.test.js`
- `tests/cleanup.test.js`
- `tests/contracts.test.js`

**Modify:** `src/cli.js`

**Doctor RED tests:**
- Node/Git/Herdr checks.
- six gears resolved.
- adapter concrete argv.
- state root writable.
- run-lock primitive works in disposable directory.
- worktree can host outbox without ignore-metadata mutation.
- safe verification policy accepts safe fixture/rejects unsafe fixture.
- provider introspection unavailable -> `configured-not-provider-validated`.

**Cleanup RED tests:**
- removes exact ingested turn outbox directory only.
- removes exact disposable review/arbiter worktree recorded as owned.
- never removes unrecorded worktree/path.
- idempotent when resource already gone.
- terminal status reports remaining owned resources.
- task branch/worktree retained unless explicit cleanup authority requests task-worktree removal.

**Contract tests:**
- worker: commit before result write; only task worktree mutation; no merge/deploy; exact outbox.
- reviewer: separate read-only review worktree; no extra untracked files; no repair.
- arbiter: no code mutation; correlated decision only.
- orchestrator: `/execute`, `/cancel`, no shadow lifecycle, no inferred DONE, no generic transition.

**Verify/commit:**

```bash
node --test tests/doctor.test.js tests/cleanup.test.js tests/contracts.test.js
npm test
git diff --check
git add src/doctor.js src/cleanup.js src/cli.js prompts/worker.md prompts/reviewer.md prompts/arbiter.md \
  skills/mighty-factory-orchestrator/SKILL.md tests/doctor.test.js tests/cleanup.test.js tests/contracts.test.js
git commit -m "feat(factory): add readiness contracts and owned cleanup"
```

---

## Task 10 — E2E regressions, README, acceptance matrix

**Create:**
- `README.md`
- `tests/e2e-controller.test.js`

**Modify:** `package.json`

**E2E happy path:**

```text
valid task/classification
/execute authorization
base SHA pin
prepare task worktree
atomic worker turn claim
WORK_DEFAULT fresh launch
worker commit then result outbox
allowed-path + Git + safe repo-check verification PASS
atomic reviewer claim
separate review worktree exact commit
REVIEW_DEFAULT PASS with only result outbox delta
DONE
```

**Required E2E regressions:**

```text
duplicate worker dispatch -> one launch only
stale worker turn rejected
moving base_ref does not move base_sha
forbidden changed path fails even if tests pass
committed outbox fails
unsafe verification command rejected before execution
committed whitespace error caught by base..commit diff-check
reviewer arbitrary untracked file invalidates PASS
second material failure launches actual arbiter + WORK_STRONG argv
third material failure stops at REPLAN_REQUIRED
cleanup cannot remove unowned path
main branch unchanged
```

**README:** prerequisites, concrete gear configuration, exact `/execute`, safe verification kinds, outbox semantics, concurrency/active turn behavior, review isolation, escalation, cleanup, no merge/deploy.

**Package scripts:**

```json
{
  "scripts": {
    "test": "node --test tests/*.test.js",
    "test:e2e": "node --test tests/e2e-controller.test.js",
    "doctor": "node bin/mighty-factory.js doctor"
  }
}
```

**Final local matrix:**

```bash
cd incubator/mighty-factory
npm test
npm run test:e2e
git diff --check
node bin/mighty-factory.js help
node bin/mighty-factory.js doctor --config ./factory.config.json
```

**Stage/commit:**

```bash
git add README.md package.json tests/e2e-controller.test.js
git commit -m "docs(factory): complete review-3 v0.1 acceptance gate"
```

---

# Review gate after every task

After each Task 1–10:

1. focused test command exits 0,
2. `npm test` exits 0,
3. `git diff --check` exits 0,
4. inspect changed files,
5. explicitly `git add` only task files,
6. commit,
7. request independent code review before proceeding.

Do not batch tasks.

# Final spec-to-code checklist

Implementation cannot be called complete until the same HEAD proves:

```text
exact /execute boundary
no public generic transition
run locking + active_turn prevents duplicate specialists
base_sha immutable
allowed_paths enforced against committed diff
outbox never committed and no ignore metadata modified
safe structured verification only
controller-owned base..commit diff-check
fresh exact gear launch per turn
reviewer full tracked + untracked immutability
stale evidence invalidation
three-failure cap
CLI reaches every required controller operation
cleanup only Factory-owned resources
DONE only for same independently verified/reviewed commit
no implicit merge/deploy
```

# HERDR_RUNTIME_QUALIFIED gate

After unit/integration completion, run one disposable provider-backed smoke test on the user's Mac inside Herdr.

It must demonstrate:

- PLAN launches no specialist,
- `/execute` validates and pins base SHA,
- concurrent duplicate worker dispatch is prevented,
- WORK_DEFAULT launches configured concrete args,
- forbidden-path implementation is rejected,
- safe verification commands run independently,
- reviewer receives exact verified commit in separate review worktree,
- arbitrary reviewer untracked mutation invalidates review,
- forced second failure launches actual `ORCH_ESCALATE_1` then `WORK_STRONG`,
- third failure stops,
- cleanup affects only recorded Factory resources,
- main remains unchanged.

Without this smoke run, report `UNIT_INTEGRATION_COMPLETE` at most, not `HERDR_RUNTIME_QUALIFIED`.
