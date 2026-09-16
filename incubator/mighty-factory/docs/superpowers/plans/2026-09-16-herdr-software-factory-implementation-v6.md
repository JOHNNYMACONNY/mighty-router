# Mighty Factory v0.1 Implementation Plan — Review 6

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the canonical Review-6 Mighty Factory as a dependency-free Node.js controller around Herdr with immutable authorization inputs, pinned Git identity, crash-resumable resource preparation and prompt-safe specialist dispatch, settled-turn archival, safe explicit abandonment, exact gear activation, trusted-repository verification, independent reviewer clones, bounded escalation, and owned-resource cleanup.

**Architecture:** The conversational Luna-Max Codex session owns planning and judgment. At `/execute`, the controller freezes config, task, classification, canonical repository identity, and base commit into byte-digested snapshots. The controller then owns all run state, resource reconciliation, specialist leases, prompt ambiguity, turn settlement/archive, verification, review, recovery, cancellation, abandonment, cleanup, and DONE. Workers use one task worktree, reviewers use independent clones, and arbiters use evidence-only bundles.

**Tech Stack:** Node.js >= 20, ESM, built-in `node:test`, `fs`, `path`, `os`, `crypto`, `child_process`; native Git; Herdr CLI; no runtime npm dependencies.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-16-herdr-software-factory-design-v6.md`

## Global Constraints

- Work only under `incubator/mighty-factory/` on branch `incubator/mighty-factory-v0`.
- Do not modify Mighty Router mainline behavior or `universal-agent-loop`.
- TDD every behavior: observe RED before production implementation, then GREEN.
- PLAN is non-mutating; only exact `/execute` authorizes execution.
- v0.1 accepts only `execution_trust: "trusted-local-repository"`; it is not an untrusted-code sandbox.
- No public generic `transition` command.
- Authorization freezes config/task/classification/canonical repo/base SHA into immutable byte-digested run inputs.
- Later run commands never reread mutable config/task/classification files for decisions.
- Every state mutation uses a per-run lock.
- Lock recovery verifies nonce plus process-start identity, not PID alone.
- Every external resource has deterministic intended identity persisted before external mutation.
- Every specialist has deterministic turn/workspace/agent identity persisted before launch.
- Prompt bytes/digest and `prompt_attempted` are persisted before prompt delivery.
- Ambiguous prompt delivery is never blindly retried.
- Result artifact does not finish a turn; specialist must settle, turn must archive, then active lease clears.
- `abandon-turn` never retries; it terminates one unrecoverable active turn safely and cancels the run.
- Worker verification runs only from archived settled worker evidence.
- Reviewer verdict application runs only from archived settled reviewer evidence.
- Pin `base_sha` at authorization, not preparation.
- Enforce `allowed_paths` against `base_sha..<reported_commit>`.
- Never modify Git ignore metadata for Factory outboxes.
- Verification command forms are structured and script-name allowlisted.
- Verification subprocess environment is sanitized.
- Recheck worker worktree status after repository checks.
- Reviewer clone provides Git/repository metadata isolation only.
- Cleanup refuses active-turn resources and never force-removes dirty worktrees by default.
- Explicitly stage new files; never rely on `git commit -am` for newly created files.
- No implicit merge, deploy, production mutation, credential change, billing action, package installation, or permission approval.

---

## File Structure

```text
incubator/mighty-factory/
  README.md
  package.json
  factory.config.example.json
  bin/
    mighty-factory.js
  src/
    cli.js
    errors.js
    ids.js
    canonical-json.js
    authorization.js
    task-contract.js
    classify-schema.js
    config.js
    route.js
    environment.js
    provider-adapters/
      index.js
      codex.js
      cline.js
      antigravity.js
    run-lock.js
    process-identity.js
    state-machine.js
    state-store.js
    turn-archive.js
    git.js
    resource-plan.js
    artifacts.js
    verification-policy.js
    verifier.js
    herdr.js
    turn-launcher.js
    recovery.js
    prepare-run.js
    review-clone.js
    review-guard.js
    arbiter-bundle.js
    controller.js
    cleanup.js
    doctor.js
  prompts/
    worker.md
    reviewer.md
    arbiter.md
  skills/
    mighty-factory-orchestrator/
      SKILL.md
  tests/
    cli.test.js
    canonical-json.test.js
    authorization.test.js
    task-contract.test.js
    classify-schema.test.js
    config.test.js
    route.test.js
    environment.test.js
    provider-adapters.test.js
    run-lock.test.js
    process-identity.test.js
    state-machine.test.js
    state-store.test.js
    turn-archive.test.js
    git.test.js
    resource-plan.test.js
    artifacts.test.js
    verification-policy.test.js
    verifier.test.js
    herdr.test.js
    turn-launcher.test.js
    recovery.test.js
    prepare-run.test.js
    review-clone.test.js
    review-guard.test.js
    arbiter-bundle.test.js
    controller.test.js
    cleanup.test.js
    doctor.test.js
    contracts.test.js
    e2e-controller.test.js
```

---

### Task 1: Package scaffold, CLI authority surface, task/classification schemas

**Files:**
- Create: `package.json`
- Create: `bin/mighty-factory.js`
- Create: `src/cli.js`
- Create: `src/errors.js`
- Create: `src/task-contract.js`
- Create: `src/classify-schema.js`
- Test: `tests/cli.test.js`
- Test: `tests/task-contract.test.js`
- Test: `tests/classify-schema.test.js`

**Interfaces:**
- Produces: `main(argv, io = { stdout: process.stdout, stderr: process.stderr }) -> Promise<number>`.
- Produces: `validateTaskContract(value, classification) -> normalizedTask`.
- Produces: `validateClassification(value) -> normalizedClassification`.

- [ ] **Step 1: Write failing CLI surface tests**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const bin = path.resolve('bin/mighty-factory.js');
const required = [
  'doctor','print-config','route','authorize-execute','cancel','recover-run','abandon-turn',
  'prepare-run','dispatch-worker','verify-worker','dispatch-reviewer','verify-review',
  'dispatch-arbiter','record-repair','status','cleanup'
];

test('help has high-level commands and no transition', () => {
  const r = spawnSync(process.execPath, [bin, 'help'], { encoding: 'utf8' });
  assert.equal(r.status, 0);
  for (const cmd of required) assert.match(r.stdout, new RegExp(`mighty-factory ${cmd}`));
  assert.doesNotMatch(r.stdout, /mighty-factory transition/);
});
```

- [ ] **Step 2: Write failing task-contract tests**

Use a valid code task with `execution_trust: 'trusted-local-repository'`, non-empty `allowed_paths`, and at least one verification check. Reject unsupported trust, empty allowed paths, empty code-task verification, absolute/traversal allowed paths, and malformed check objects.

```js
test('rejects traversal allowed path', () => {
  assert.throws(() => validateTaskContract({ ...valid, allowed_paths: ['../x'] }, classification), /path/);
});
```

- [ ] **Step 3: Write classification tests**

Require exact enums, boolean `cross_cutting`, finite numeric confidence in `[0,1]`, and no string coercion.

- [ ] **Step 4: Run RED**

```bash
cd incubator/mighty-factory
node --test tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
```

Expected: FAIL because implementation does not exist.

- [ ] **Step 5: Implement minimal scaffold**

`package.json`:

```json
{
  "name": "mighty-factory",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "bin": { "mighty-factory": "./bin/mighty-factory.js" },
  "engines": { "node": ">=20" },
  "scripts": { "test": "node --test tests/*.test.js" }
}
```

Reserve all public commands. Unimplemented reserved commands produce operational error exit `1`, unknown command usage error exit `2`.

- [ ] **Step 6: Verify GREEN and commit**

```bash
node --test tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
npm test
git diff --check
git add package.json bin/mighty-factory.js src/cli.js src/errors.js \
  src/task-contract.js src/classify-schema.js \
  tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
git commit -m "feat(factory): scaffold authority contracts"
```

---

### Task 2: Canonical snapshot bytes and immutable authorization manifest

**Files:**
- Create: `factory.config.example.json`
- Create: `src/canonical-json.js`
- Create: `src/config.js`
- Create: `src/authorization.js`
- Create: `src/environment.js`
- Create: `src/route.js`
- Create: `src/provider-adapters/index.js`
- Create: `src/provider-adapters/codex.js`
- Create: `src/provider-adapters/cline.js`
- Create: `src/provider-adapters/antigravity.js`
- Test: `tests/canonical-json.test.js`
- Test: `tests/config.test.js`
- Test: `tests/authorization.test.js`
- Test: `tests/environment.test.js`
- Test: `tests/route.test.js`
- Test: `tests/provider-adapters.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `canonicalJsonBytes(value) -> Buffer`.
- `sha256Bytes(bytes) -> 'sha256:<hex>'`.
- `writeSnapshotFile(path, value) -> { digest }` using atomic temp+rename.
- `readVerifiedSnapshot(path, expectedDigest) -> parsedValue`, hashing exact file bytes before parse.
- `loadConfig(path) -> validatedConfig`.
- `authorizeInputs({ taskPath, classificationPath, configPath }, deps) -> runManifest`.
- `buildSanitizedEnv(sourceEnv, allowedNames, fixed) -> env`.
- `routeTask({ classification, state, configSnapshot }) -> route`.

- [ ] **Step 1: Write canonical JSON RED tests**

```js
test('object insertion order does not change canonical bytes', () => {
  const a = { z: 1, a: { y: 2, x: 3 } };
  const b = { a: { x: 3, y: 2 }, z: 1 };
  assert.deepEqual(canonicalJsonBytes(a), canonicalJsonBytes(b));
});

test('array order remains significant', () => {
  assert.notDeepEqual(canonicalJsonBytes({ a:[1,2] }), canonicalJsonBytes({ a:[2,1] }));
});
```

Also require one trailing newline, recursive key sorting, rejection of non-finite numbers and non-JSON values.

- [ ] **Step 2: Write authorization RED tests for immutable inputs**

Create temp Git repo at commit A and mutable config/task/classification files. Authorization must:

```text
realpath target repo
git rev-parse --show-toplevel -> same canonical root
resolve base_ref -> A immediately
write config.snapshot.json
write task.snapshot.json containing canonical repo + base_sha A
write classification.snapshot.json
hash exact written bytes
persist three digests in run.json
```

Then mutate live config/task/classification and advance `main` to B. `readVerifiedSnapshot` must still yield original values and base SHA A.

- [ ] **Step 3: Write byte-tampering RED test**

After authorization, modify one byte in `task.snapshot.json` without changing `run.json`. Any run input load must reject digest mismatch before parsing/using it.

- [ ] **Step 4: Write config/gear/environment RED tests**

Require specialist gears:

```text
ORCH_ESCALATE_1 WORK_DEFAULT WORK_STRONG REVIEW_DEFAULT REVIEW_STRONG
```

Every specialist gear must resolve concrete model/effort argv. `foreman_expected` is configuration-only and separate. Environment sanitizer must strip `SUPER_SECRET_TOKEN` unless explicitly allowed by name.

- [ ] **Step 5: Implement authorization and route on pinned snapshots**

Later run operations receive only run ID and read snapshots by digest. They do not accept mutable config/task/classification paths.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/canonical-json.test.js tests/config.test.js tests/authorization.test.js \
  tests/environment.test.js tests/route.test.js tests/provider-adapters.test.js
npm test
git diff --check
git add factory.config.example.json src/canonical-json.js src/config.js src/authorization.js \
  src/environment.js src/route.js src/provider-adapters/index.js \
  src/provider-adapters/codex.js src/provider-adapters/cline.js src/provider-adapters/antigravity.js \
  src/cli.js tests/canonical-json.test.js tests/config.test.js tests/authorization.test.js \
  tests/environment.test.js tests/route.test.js tests/provider-adapters.test.js
git commit -m "feat(factory): freeze authorization inputs"
```

---

### Task 3: Locks, process identity, lifecycle, active-turn lease, turn archive

**Files:**
- Create: `src/ids.js`
- Create: `src/process-identity.js`
- Create: `src/run-lock.js`
- Create: `src/state-machine.js`
- Create: `src/state-store.js`
- Create: `src/turn-archive.js`
- Test: `tests/process-identity.test.js`
- Test: `tests/run-lock.test.js`
- Test: `tests/state-machine.test.js`
- Test: `tests/state-store.test.js`
- Test: `tests/turn-archive.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `getProcessIdentity(pid, runner) -> { alive, startToken, supported }`.
- `withRunLock(runDir, command, fn, deps)`.
- `recoverDeadRunLock(runDir, { expectedNonce }, deps)`.
- internal `transitionInternal(state, event, payload)`.
- `archiveTurn({ runDir, activeTurn, resultDigest, settlement, status }) -> archiveRecord`.
- `clearArchivedActiveTurn(state, archiveRecord) -> nextState`.

- [ ] **Step 1: Write process identity RED tests**

Inject probe fixtures:

```text
PID absent -> alive false
PID present + same start token -> same live process
PID present + different start token -> PID reused
probe unsupported -> supported false
```

- [ ] **Step 2: Write lock recovery RED tests**

Lock stores nonce, PID, process start token, controller instance ID. Require:

```text
wrong nonce -> reject
same live PID+start token -> reject
absent PID -> recover allowed
same PID different start token -> recover allowed as reused PID
unsupported/ambiguous start identity -> reject with manual recovery instructions
```

No force-clear CLI.

- [ ] **Step 3: Write lifecycle/cancellation RED tests**

States include PLAN/READY/PREPARING/WORKING/VERIFYING_WORK/REVIEWING/VERIFYING_REVIEW/REPAIR_PENDING/ESCALATION_PENDING/REPLAN_REQUIRED/BLOCKED/DONE/CANCELLED.

Require active turn stages:

```text
claimed workspace_ready agent_started prompt_attempted result_seen settling
```

Cancel with no active turn -> CANCELLED. Cancel with active turn -> `cancel_requested=true` and phase unchanged.

- [ ] **Step 4: Write turn archive RED tests**

```js
test('active turn cannot clear without archive', () => {
  assert.throws(() => clearArchivedActiveTurn(stateWithActiveTurn, null), /archive/);
});

test('archive captures settlement and exact turn identity', async () => {
  const record = await archiveTurn({ /* fixture */ });
  assert.equal(record.turn_id, 'turn_1');
  assert.equal(record.status, 'completed');
  assert.equal(record.settlement.state, 'done');
});
```

Mismatched turn archive cannot clear active lease.

- [ ] **Step 5: Implement atomic state/archive writes**

State updates and archive writes use temp+rename. Events record old/new revision and phase.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/process-identity.test.js tests/run-lock.test.js tests/state-machine.test.js \
  tests/state-store.test.js tests/turn-archive.test.js
npm test
git diff --check
git add src/ids.js src/process-identity.js src/run-lock.js src/state-machine.js src/state-store.js \
  src/turn-archive.js src/cli.js tests/process-identity.test.js tests/run-lock.test.js \
  tests/state-machine.test.js tests/state-store.test.js tests/turn-archive.test.js
git commit -m "feat(factory): persist recoverable leases and archives"
```

---

### Task 4: Git primitives and crash-safe task resource reconciliation

**Files:**
- Create: `src/git.js`
- Create: `src/resource-plan.js`
- Create: `src/artifacts.js`
- Test: `tests/git.test.js`
- Test: `tests/resource-plan.test.js`
- Test: `tests/artifacts.test.js`

**Interfaces:**
- `inspectWorktrees(repo, runner) -> records` using `git worktree list --porcelain`.
- `makeTaskResourcePlan({ runId, tempRoot, baseSha })`.
- `reconcileTaskWorktree(plan, canonicalRepo, runner)`.
- `listCommittedPaths(repo, baseSha, commit, runner)`.
- `assertNoOutboxCommitted(repo, commit, runner)`.
- correlated artifact validators/ingestion.

- [ ] **Step 1: Write task resource RED tests for every matrix case**

Use real temp Git repo:

```text
path absent + branch absent -> create -b once
path absent + expected branch exists at base and unattached -> attach existing branch to recorded path
path absent + expected branch attached elsewhere -> BLOCKED
path absent + expected branch incompatible before worker -> BLOCKED
recorded path exact worktree/branch -> adopt
recorded path exists non-worktree -> BLOCKED
retry never allocates alternate branch/path
```

For the branch-created crash fixture, create branch manually at base SHA without worktree, then reconcile and assert command uses `git worktree add <path> <branch>` rather than `-b`.

- [ ] **Step 2: Write pinned-base tests**

Authorization fixture pins A, branch `main` advances to B before preparation, and task worktree still starts at A.

- [ ] **Step 3: Write artifact/outbox tests**

Git ignore metadata remains byte-identical. Committed outbox is rejected. Wrong run/task/turn IDs are rejected.

- [ ] **Step 4: Implement argv-only Git operations**

No shell strings and no destructive reset/stash/clean.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/git.test.js tests/resource-plan.test.js tests/artifacts.test.js
npm test
git diff --check
git add src/git.js src/resource-plan.js src/artifacts.js \
  tests/git.test.js tests/resource-plan.test.js tests/artifacts.test.js
git commit -m "feat(factory): reconcile pinned task resources"
```

---

### Task 5: Trusted verification policy and post-check checkout integrity

**Files:**
- Create: `src/command-runner.js`
- Create: `src/verification-policy.js`
- Create: `src/verifier.js`
- Test: `tests/verification-policy.test.js`
- Test: `tests/verifier.test.js`

**Interfaces:**
- `runCommand(command, args, { cwd, env })` without shell interpolation.
- `compileVerificationCommand(check, configSnapshot, repoRoot)`.
- `verifyWorker({ runManifest, taskSnapshot, archivedTurn, configSnapshot }, deps)`.

- [ ] **Step 1: Write policy RED tests**

Accept only `npm-script`, `pnpm-script`, `yarn-script`, `node-test`, `node-check` with pinned allowlists and safe relative paths. Reject arbitrary binaries/shells/install/migration/deploy forms.

- [ ] **Step 2: Write settled-archive precondition test**

```js
test('verification refuses a still-active or unarchived worker turn', async () => {
  await assert.rejects(
    () => verifyWorker({ ...fixture, archivedTurn: null }, deps),
    /archived settled worker turn/
  );
});
```

- [ ] **Step 3: Write verification RED matrix**

Prove:

```text
snapshot digest mismatch -> FAIL before commands
worker self-report PASS + controller check fail -> FAIL
forbidden committed path -> FAIL
committed outbox -> FAIL
diff --check fail -> FAIL
unexpected initial dirty path -> FAIL
sanitized env excludes synthetic secret
repo check exit 0 but creates generated.tmp -> FAIL final status
repo check modifies tracked file -> FAIL final status
exact expected worker outbox only -> allowed
verification artifact binds commit + three input digests + archived turn ID
```

- [ ] **Step 4: Implement exact ordering and output caps**

Order:

```text
verify snapshot bytes/digests
load archived settled turn
correlation
commit/HEAD/ancestry
changed paths/outbox
diff hygiene
initial status
repo checks
final status
evidence
```

Store at most 16 KiB stdout/stderr tail per command.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/verification-policy.test.js tests/verifier.test.js tests/environment.test.js tests/git.test.js
npm test
git diff --check
git add src/command-runner.js src/verification-policy.js src/verifier.js \
  tests/verification-policy.test.js tests/verifier.test.js
git commit -m "feat(factory): verify settled scoped commits"
```

---

### Task 6: Herdr wrapper, prompt-safe dispatch, settlement, recovery, abandonment

**Files:**
- Create: `src/herdr.js`
- Create: `src/turn-launcher.js`
- Create: `src/recovery.js`
- Test: `tests/herdr.test.js`
- Test: `tests/turn-launcher.test.js`
- Test: `tests/recovery.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `createHerdrClient(runner)` with current required workspace/agent primitives.
- `buildTurnPrompt(request) -> exact string`.
- `reconcileTurnLaunch(...) -> launchReport`.
- `settleAndArchiveTurn({ runId, expectedTurnId }, deps) -> archiveRecord`.
- `abandonActiveTurn({ runId, turnId }, deps) -> report`.
- `recoverRun({ runId, lockNonce }, deps)`.

- [ ] **Step 1: Write Herdr parsing RED tests**

Synthetic fixtures supply returned IDs. `blocked` is blocker, `unknown` not success, prompt timeout/stall becomes inspect-required.

- [ ] **Step 2: Write prompt ambiguity RED tests**

```js
test('prompt attempt is persisted before external prompt call', async () => {
  // fake state store records prompt_attempted
  // fake herdr.agentPrompt asserts persisted state before returning
});

test('ambiguous prior prompt attempt is never blindly resent', async () => {
  // agentPrompt threw after recording one call
  // retry cannot prove non-delivery
  // assert agentPrompt call count remains 1 and run becomes BLOCKED
});
```

Definite non-delivery evidence may resend only the exact persisted prompt under the same turn and bounded once.

- [ ] **Step 3: Write settlement RED tests**

```text
result exists + agent still working -> active turn remains, no archive, no verification
result exists + agent reaches idle/done -> final role snapshot captured -> archive written -> active turn cleared
agent unknown/blocked/settlement timeout -> BLOCKED, lease retained
reviewer writes PASS then modifies clone before settling -> post-settlement integrity sees modification
```

- [ ] **Step 4: Write abandon-turn RED tests**

```text
wrong turn ID -> reject
active ambiguous turn + workspace closes -> archive status abandoned, active_turn null, phase CANCELLED
abandon never calls agentPrompt
workspace close ambiguous/fails -> remain BLOCKED with active lease
worker task checkout is preserved
```

- [ ] **Step 5: Write stale-lock recovery RED tests**

Recovery reconciles existing turn/resource/prompt stage after nonce/process-identity validation; it never replaces turn ID or clears ambiguous prompt automatically.

- [ ] **Step 6: Verify concrete gear transitions**

WORK_DEFAULT and WORK_STRONG launch different exact pinned argv. Arbiter launches fresh ORCH_ESCALATE_1.

- [ ] **Step 7: Verify and commit**

```bash
node --test tests/herdr.test.js tests/turn-launcher.test.js tests/recovery.test.js tests/turn-archive.test.js
npm test
git diff --check
git add src/herdr.js src/turn-launcher.js src/recovery.js src/cli.js \
  tests/herdr.test.js tests/turn-launcher.test.js tests/recovery.test.js
git commit -m "feat(factory): settle or abandon prompt-safe turns"
```

---

### Task 7: Run preparation, crash-safe reviewer clone, review guard, arbiter bundle

**Files:**
- Create: `src/prepare-run.js`
- Create: `src/review-clone.js`
- Create: `src/review-guard.js`
- Create: `src/arbiter-bundle.js`
- Test: `tests/prepare-run.test.js`
- Test: `tests/review-clone.test.js`
- Test: `tests/review-guard.test.js`
- Test: `tests/arbiter-bundle.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `prepareRun({ runId }, deps)` reading only verified snapshots.
- `makeOwnedParentPlan(...)` / exact ownership marker.
- `reconcileReviewClone(plan, canonicalRepo, verifiedCommit, runner)`.
- `assertReviewCloneIntegrity(before, after, expectedOutbox)`.
- `reconcileArbiterBundle(plan, evidence)`.

- [ ] **Step 1: Write run preparation RED tests**

Preparation refuses any snapshot digest mismatch, uses already-pinned base SHA, persists deterministic task resource before Git mutation, and reconciles branch-only crash case.

- [ ] **Step 2: Write reviewer parent-marker-before-clone RED test**

Fake runner asserts `.mighty-factory-owner.json` exists in deterministic parent **before** the first `git clone` call.

Real temp repo cases:

```text
parent absent -> create+mark, clone into parent/repo
owned parent + repo absent -> resume exact clone path
owned parent + exact clone -> adopt
parent missing/wrong marker -> BLOCKED
partial/incompatible repo -> BLOCKED, no alternate path
```

Assert no origin and Git common dir internal to clone.

- [ ] **Step 3: Write reviewer post-settlement integrity tests**

The role-specific final snapshot consumed by turn settlement catches tracked edits, untracked notes, rename/delete, or HEAD movement after result creation.

- [ ] **Step 4: Write arbiter parent-marker-before-population RED test**

Owned parent marker exists before bundle writes. Exact complete bundle manifest/digests may be adopted. Missing/wrong marker or partial/mismatched bundle -> BLOCKED. Bundle excludes target repo/worktree/remotes/secrets/.git.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/prepare-run.test.js tests/review-clone.test.js tests/review-guard.test.js tests/arbiter-bundle.test.js
npm test
git diff --check
git add src/prepare-run.js src/review-clone.js src/review-guard.js src/arbiter-bundle.js src/cli.js \
  tests/prepare-run.test.js tests/review-clone.test.js tests/review-guard.test.js tests/arbiter-bundle.test.js
git commit -m "feat(factory): reconcile owned review resources"
```

---

### Task 8: Controller integration, settled-turn transitions, cancellation, repair/escalation

**Files:**
- Create: `src/controller.js`
- Test: `tests/controller.test.js`
- Modify: `src/cli.js`
- Modify: `src/state-machine.js`
- Modify: `src/state-store.js`
- Modify: `src/authorization.js`
- Modify: `src/recovery.js`
- Modify: `src/artifacts.js`

**Interfaces:**
- `createController(deps)` exposes `authorizeExecute`, `cancel`, `recoverRun`, `abandonTurn`, `prepareRun`, `dispatchWorker`, `verifyWorker`, `dispatchReviewer`, `verifyReview`, `dispatchArbiter`, `recordRepair`, `status`, `cleanup`.

- [ ] **Step 1: Write authorization immutability RED test**

Authorize at config/task/classification/base A. Mutate all live files and branch to B. Every later controller operation must still use pinned snapshot values and A. Tampered snapshot byte must block operation.

- [ ] **Step 2: Write happy-path RED test with turn archives**

```text
PLAN -> authorize -> READY
prepare pinned A
worker claimed/launched/prompted
worker result appears but agent still working -> no verification
worker settles -> archive worker -> clear lease -> VERIFYING_WORK
verify exact commit
review clone provision
review result appears but reviewer still working -> no verdict
reviewer settles -> archive reviewer -> clear lease -> VERIFYING_REVIEW
PASS + integrity -> DONE
```

- [ ] **Step 3: Write cancellation/abandon RED tests**

Cancel before active turn -> CANCELLED. Cancel during active turn -> current turn settles/archives, then CANCELLED before next operation. Ambiguous BLOCKED prompt turn can be abandoned; run becomes CANCELLED and checkout remains.

- [ ] **Step 4: Write escalation RED test**

Review FAIL #1 -> repair pending. FAIL #2 -> isolated settled arbiter archive then WORK_STRONG. FAIL #3 -> REPLAN_REQUIRED. No decision consumes still-active specialist evidence.

- [ ] **Step 5: Wire CLI including abandon-turn**

```text
mighty-factory authorize-execute --task task.json --classification classification.json --config factory.config.json
mighty-factory cancel --run <id>
mighty-factory recover-run --run <id> --lock-nonce <nonce>
mighty-factory abandon-turn --run <id> --turn <id>
mighty-factory prepare-run --run <id>
mighty-factory dispatch-worker --run <id>
mighty-factory verify-worker --run <id> --turn <archived-turn-id>
mighty-factory dispatch-reviewer --run <id>
mighty-factory verify-review --run <id> --turn <archived-turn-id>
mighty-factory dispatch-arbiter --run <id>
mighty-factory record-repair --run <id> --file repair.json
mighty-factory status --run <id>
```

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/controller.test.js tests/authorization.test.js tests/recovery.test.js \
  tests/run-lock.test.js tests/state-machine.test.js tests/turn-archive.test.js
npm test
git diff --check
git add src/controller.js src/cli.js src/state-machine.js src/state-store.js src/authorization.js \
  src/recovery.js src/artifacts.js tests/controller.test.js
git commit -m "feat(factory): enforce immutable settled orchestration"
```

---

### Task 9: Cleanup, doctor, prompts, orchestrator skill

**Files:**
- Create: `src/cleanup.js`
- Create: `src/doctor.js`
- Create: `prompts/worker.md`
- Create: `prompts/reviewer.md`
- Create: `prompts/arbiter.md`
- Create: `skills/mighty-factory-orchestrator/SKILL.md`
- Test: `tests/cleanup.test.js`
- Test: `tests/doctor.test.js`
- Test: `tests/contracts.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `cleanupRun({ runId, removeTaskWorktree = false }, deps)`.
- `runDoctor({ configPath, env }, deps)`.

- [ ] **Step 1: Write cleanup RED tests**

Require:

```text
active-turn workspace/path -> resource_in_use, no mutation
archived settled turn workspace -> exact workspace close allowed
abandoned turn task checkout retained by default
owned reviewer/arbiter parents require exact marker nonce
wrong/unowned path never deleted
missing already-cleaned resource is idempotent
explicit task worktree removal uses native git worktree remove without --force
dirty refusal reported, not overridden
branch retained
```

- [ ] **Step 2: Write doctor RED tests**

Check Node/Git/Herdr, resolved specialist gears, canonical serializer determinism, state/temp roots, process-start identity probe status, trust warning, environment secret stripping, verification policy fixtures, review clone independence, required workspace close primitive, and foreman configured-vs-verified status.

- [ ] **Step 3: Write contract RED tests**

Worker prompt: exact IDs/worktree/outbox, commit-before-result, no merge/deploy, remain quiescent after final result until controller observes settlement.

Reviewer prompt: Git-metadata isolation wording only, no source repo mutation, exact commit/outbox, remain quiescent after result.

Arbiter prompt: evidence bundle only, no target checkout, remain quiescent after result.

Orchestrator skill: exact `/execute`, `/cancel`, explicit `recover-run` and `abandon-turn`, never edit pinned snapshots, never infer DONE.

- [ ] **Step 4: Verify and commit**

```bash
node --test tests/cleanup.test.js tests/doctor.test.js tests/contracts.test.js
npm test
git diff --check
git add src/cleanup.js src/doctor.js src/cli.js prompts/worker.md prompts/reviewer.md prompts/arbiter.md \
  skills/mighty-factory-orchestrator/SKILL.md tests/cleanup.test.js tests/doctor.test.js tests/contracts.test.js
git commit -m "feat(factory): add recoverable cleanup and contracts"
```

---

### Task 10: E2E regression matrix, README, qualification gates

**Files:**
- Create: `README.md`
- Create: `tests/e2e-controller.test.js`
- Modify: `package.json`

- [ ] **Step 1: Write E2E happy path**

Use real temp Git repo/state/temp directories plus fake Herdr:

```text
trusted task/classification/config
/execute canonicalizes repo and pins base A
three immutable snapshot byte digests
prepare deterministic task resource
WORK_DEFAULT turn
prompt_attempted before prompt
worker result while working does not finish turn
worker settles -> archive -> lease clear
verification passes exact commit
review owned parent marked before clone
independent clone no origin
review result while working does not apply
reviewer settles -> archive -> lease clear
PASS -> DONE
```

- [ ] **Step 2: Add full regression cases**

Same file must prove:

```text
live config/task/classification mutation after /execute does not alter run
base branch moving after /execute does not alter base_sha
snapshot-byte tampering blocks operation
canonical snapshot key ordering is stable
branch created but worktree missing reconciles same recorded branch/path
branch attached elsewhere blocks
review parent marker exists before clone; crash resumes exact parent/repo
arbiter parent marker exists before bundle; crash resumes exact bundle
prompt ambiguity never blindly resends
human abandon-turn never prompts and cancels run while preserving checkout
result-before-agent-settlement keeps active lease
settlement timeout/unknown blocks with lease retained
settled archived worker is required before verification
verification command dirt causes FAIL
reviewer PASS before settlement is not applied
post-result reviewer mutation before settlement invalidates PASS
stale lock same PID different process-start token is recoverable as PID reuse
stale lock ambiguous identity fails closed
cleanup refuses active resources and handles archived resources only
forbidden path/outbox/unsafe verification forms fail
second review failure launches settled arbiter + WORK_STRONG
third failure stops
foreman status configured vs independently verified is truthful
main branch unchanged
```

- [ ] **Step 3: Write README sections**

Document:

```text
What Mighty Factory is
Trusted-local-repository security model
Immutable authorization: config/task/classification/canonical repo/base SHA
Canonical byte digests and tamper detection
PLAN and exact /execute
Cancellation semantics
Crash recovery and PID/start-token stale-lock checks
Prompt ambiguity and abandon-turn
Deterministic resource reconciliation including branch-only crash case
Turn settlement/archive before verification/verdicts
Task worktree + worker outbox
Independent reviewer clone: Git-metadata isolation only
Arbiter evidence bundle
Real escalation and three-failure cap
Owned cleanup and active-turn guard
No automatic merge/deploy
UNIT_INTEGRATION_COMPLETE vs HERDR_RUNTIME_QUALIFIED
```

- [ ] **Step 4: Add package scripts**

```json
{
  "scripts": {
    "test": "node --test tests/*.test.js",
    "test:e2e": "node --test tests/e2e-controller.test.js",
    "doctor": "node bin/mighty-factory.js doctor"
  }
}
```

- [ ] **Step 5: Run final local matrix**

```bash
cd incubator/mighty-factory
npm test
npm run test:e2e
git diff --check
node bin/mighty-factory.js help
node bin/mighty-factory.js doctor --config ./factory.config.json
```

- [ ] **Step 6: Self-review spec coverage at the same HEAD**

Verify explicitly:

```text
three immutable snapshot digests
canonical target repo + base SHA pinned at authorization
exact-byte digest validation
run lock PID + process-start identity
branch-only task-resource crash recovery
owned parent marker before reviewer/arbiter external mutation
prompt_attempted ambiguity rule
settlement before archive/lease release
archive required before verification/verdict application
abandon-turn safe terminal path
post-verification checkout status
allowed paths/outbox/safe verification policy
review clone isolation wording
cleanup active-turn guard
three-failure cap
DONE only with no active turn and exact archived verified/reviewed commit
no implicit merge/deploy
```

- [ ] **Step 7: Commit**

```bash
git add README.md package.json tests/e2e-controller.test.js
git commit -m "docs(factory): complete review-6 v0.1 acceptance gate"
```

---

## Review Gate After Every Task

After each Task 1–10:

1. run focused tests and observe GREEN,
2. run `npm test`,
3. run `git diff --check`,
4. inspect changed files and `git status --short`,
5. explicitly stage only the task files,
6. commit,
7. request a fresh independent review before starting the next task.

Do not batch tasks.

## Final Acceptance Labels

### `UNIT_INTEGRATION_COMPLETE`

May be reported only after the full local matrix passes at one HEAD, including immutable-input tamper cases, branch-only resource recovery, PID reuse, prompt ambiguity, settlement/archive, abandon-turn, verification post-status, review isolation, cleanup guard, and escalation cases.

### `HERDR_RUNTIME_QUALIFIED`

Requires a disposable provider-backed run on the user's Mac inside Herdr proving:

```text
PLAN launches no specialist
/execute pins config/task/classification/canonical repo/base SHA
live source files and base branch can change without changing active run
snapshot tamper is detected
interruption after task branch creation reconciles exact branch/path
WORK_DEFAULT starts with exact pinned args
interruption around prompt delivery never blindly redelivers
ambiguous active turn can be abandoned without retry
worker result does not release lease until agent settles
settled worker archive precedes verification
verification dirt blocks PASS
review parent ownership exists before clone creation
reviewer result does not apply until reviewer settles
reviewer post-result mutation before settlement is caught
arbiter owned parent precedes bundle population
PID reuse is distinguished from live stale-lock owner
second failure launches actual ORCH_ESCALATE_1 then WORK_STRONG
third failure stops
cleanup refuses active-turn resources and does not force-remove dirty worktrees
main remains unchanged
```

Without that provider-backed smoke run, do not claim runtime qualification.
