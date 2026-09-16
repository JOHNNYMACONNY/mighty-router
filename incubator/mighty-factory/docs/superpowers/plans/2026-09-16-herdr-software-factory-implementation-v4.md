# Mighty Factory v0.1 Implementation Plan — Review 4

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the canonical Review-4 Mighty Factory as a dependency-free Node.js controller around Herdr with trusted-repository execution, deterministic authority, crash-resumable single-turn dispatch, exact gear activation, pinned Git identity, safe structured verification, independent reviewer clones, bounded escalation, and owned-resource cleanup.

**Architecture:** The conversational Luna-Max Codex session owns planning and judgment. The controller owns state, locking, recovery, launch identity, Git verification, artifact correlation, cancellation, cleanup, and DONE. Workers operate in one task worktree, reviewers operate in independent temporary clones with `origin` removed, and arbiters operate only on copied evidence bundles. v0.1 deliberately does not claim to sandbox untrusted repository code.

**Tech Stack:** Node.js >= 20, ESM, built-in `node:test`, `fs`, `path`, `os`, `crypto`, `child_process`; native Git; Herdr CLI; no runtime npm dependencies.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-16-herdr-software-factory-design-v4.md`

## Global Constraints

- Work only under `incubator/mighty-factory/` on branch `incubator/mighty-factory-v0`.
- Do not modify Mighty Router mainline behavior or `universal-agent-loop`.
- TDD every behavior: observe RED before production implementation, then GREEN.
- PLAN is non-mutating; only exact `/execute` authorizes execution.
- v0.1 accepts only `execution_trust: "trusted-local-repository"`; it is not an untrusted-code sandbox.
- No public generic lifecycle `transition` command.
- Every state-changing operation uses a per-run lock.
- Every specialist turn has deterministic persisted launch identity before Herdr mutation.
- Repeated dispatch resumes/reconciles the same active turn; it never allocates a second turn while one exists.
- Cancellation during an active turn sets `cancel_requested`; it does not erase the claimed turn.
- Pin `base_ref` once to `base_sha`.
- Enforce `allowed_paths` against `base_sha..<reported_commit>`.
- Never modify `.git/info/exclude` or tracked `.gitignore` for Factory outboxes.
- Worker commits implementation before writing its outbox result.
- Verification task commands are structured and script-name allowlisted; no arbitrary executable argv.
- Verification subprocess environment is sanitized and does not inherit unapproved secret variables.
- `git diff --check base..commit` is whitespace/diff hygiene only, not syntax validation.
- Reviewer uses an independent `git clone --no-local` with `origin` removed, not a linked worktree.
- Arbiter receives an evidence bundle, not a target checkout.
- Cleanup closes exact owned Herdr workspaces and deletes only ownership-marked Factory temp resources.
- Never use force cleanup by default.
- Never use `git commit -am` for tasks creating files; explicitly stage each task's files.
- No implicit merge, deploy, production mutation, credential change, billing action, package installation, or permission-dialog approval.

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
    task-contract.js
    classify-schema.js
    config.js
    route.js
    environment.js
    run-lock.js
    state-machine.js
    state-store.js
    git.js
    artifacts.js
    verification-policy.js
    verifier.js
    herdr.js
    turn-launcher.js
    prepare-run.js
    review-clone.js
    review-guard.js
    arbiter-bundle.js
    controller.js
    recovery.js
    cleanup.js
    doctor.js
    provider-adapters/
      index.js
      codex.js
      cline.js
      antigravity.js
  prompts/
    worker.md
    reviewer.md
    arbiter.md
  skills/
    mighty-factory-orchestrator/
      SKILL.md
  tests/
    cli.test.js
    task-contract.test.js
    classify-schema.test.js
    config.test.js
    route.test.js
    environment.test.js
    provider-adapters.test.js
    ids.test.js
    run-lock.test.js
    state-machine.test.js
    state-store.test.js
    git.test.js
    artifacts.test.js
    verification-policy.test.js
    verifier.test.js
    herdr.test.js
    turn-launcher.test.js
    prepare-run.test.js
    review-clone.test.js
    review-guard.test.js
    arbiter-bundle.test.js
    recovery.test.js
    controller.test.js
    cleanup.test.js
    doctor.test.js
    contracts.test.js
    e2e-controller.test.js
```

---

### Task 1: Scaffold package, authority CLI, trust-aware task contract, classification

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
- Exit codes: `0` success, `1` operational error, `2` usage error.

- [ ] **Step 1: Write the failing CLI surface test**

```js
// tests/cli.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const bin = path.join(root, 'bin', 'mighty-factory.js');
const required = [
  'doctor', 'print-config', 'route', 'authorize-execute', 'cancel', 'recover-run',
  'prepare-run', 'dispatch-worker', 'verify-worker', 'dispatch-reviewer', 'verify-review',
  'dispatch-arbiter', 'record-repair', 'status', 'cleanup'
];

test('help exposes the complete high-level surface and no raw transition', () => {
  const r = spawnSync(process.execPath, [bin, 'help'], { encoding: 'utf8' });
  assert.equal(r.status, 0);
  for (const name of required) assert.match(r.stdout, new RegExp(`mighty-factory ${name}`));
  assert.doesNotMatch(r.stdout, /mighty-factory transition/);
});

test('unknown command is usage error', () => {
  const r = spawnSync(process.execPath, [bin, 'wat'], { encoding: 'utf8' });
  assert.equal(r.status, 2);
});
```

- [ ] **Step 2: Write failing task-contract tests**

```js
// tests/task-contract.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { validateTaskContract } from '../src/task-contract.js';

const classification = {
  scope: 'normal', risk: 'medium', ambiguity: 'low',
  change_kind: 'feature', cross_cutting: false, confidence: 0.9
};

const valid = {
  schema_version: 1,
  summary: 'Add bounded feature',
  target_repo: '/tmp/repo',
  base_ref: 'main',
  execution_trust: 'trusted-local-repository',
  allowed_paths: ['src/', 'tests/'],
  allow_noop: false,
  verification: {
    policy: 'trusted-repo-checks',
    commands: [{ kind: 'npm-script', script: 'test' }]
  }
};

test('accepts exact trusted-repository contract', () => {
  assert.equal(validateTaskContract(valid, classification).execution_trust, 'trusted-local-repository');
});

test('rejects unsupported trust mode', () => {
  assert.throws(() => validateTaskContract({ ...valid, execution_trust: 'sandboxed' }, classification), /execution_trust/);
});

test('rejects code task without allowed paths', () => {
  assert.throws(() => validateTaskContract({ ...valid, allowed_paths: [] }, classification), /allowed_paths/);
});

test('rejects traversal in allowed paths', () => {
  assert.throws(() => validateTaskContract({ ...valid, allowed_paths: ['../secrets'] }, classification), /path/);
});
```

- [ ] **Step 3: Write classification tests**

Test exact enum sets from the spec and require finite `confidence` in `0..1` without coercion.

- [ ] **Step 4: Run RED**

```bash
cd incubator/mighty-factory
node --test tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
```

Expected: FAIL because package/modules do not exist.

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

`src/errors.js` exports:

```js
export class UsageError extends Error {
  constructor(message) { super(message); this.name = 'UsageError'; }
}

export class OperationalError extends Error {
  constructor(code, message, details = undefined) {
    super(message);
    this.name = 'OperationalError';
    this.code = code;
    this.details = details;
  }
}
```

Reserve every public command immediately. Commands not implemented yet return `OperationalError('not_implemented', ...)`, not a usage error.

- [ ] **Step 6: Verify GREEN and commit**

```bash
node --test tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
npm test
git diff --check
git add package.json bin/mighty-factory.js src/cli.js src/errors.js \
  src/task-contract.js src/classify-schema.js \
  tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
git commit -m "feat(factory): scaffold trusted authority contracts"
```

---

### Task 2: Config, environment policy, concrete gears, adapters, deterministic route

**Files:**
- Create: `factory.config.example.json`
- Create: `src/config.js`
- Create: `src/environment.js`
- Create: `src/route.js`
- Create: `src/provider-adapters/index.js`
- Create: `src/provider-adapters/codex.js`
- Create: `src/provider-adapters/cline.js`
- Create: `src/provider-adapters/antigravity.js`
- Test: `tests/config.test.js`
- Test: `tests/environment.test.js`
- Test: `tests/route.test.js`
- Test: `tests/provider-adapters.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- Produces: `loadConfig(path) -> validatedConfig`.
- Produces: `buildSanitizedEnv(sourceEnv, allowedNames, fixed) -> env`.
- Produces: `routeTask({ classification, state, config }) -> route`.
- Produces: `buildLaunchSpec(adapterName, gear, context) -> { herdrKind, argv, envNames, artifactTransport }`.

Required gears:

```text
ORCH_DEFAULT ORCH_ESCALATE_1 WORK_DEFAULT WORK_STRONG REVIEW_DEFAULT REVIEW_STRONG
```

- [ ] **Step 1: Write failing config tests**

Require rejection for missing reachable gear, `launch.resolved !== true`, empty concrete model/effort args, unknown adapter, `ORCH_DEFAULT.effort !== 'max'`, invalid confidence threshold, non-absolute expanded state/temp roots, and verification allowed scripts containing `deploy`, `publish`, `migrate`, or `install` by default.

Example config shape:

```json
{
  "state_root": "~/.local/state/mighty-factory/runs",
  "temp_root": "~/.cache/mighty-factory",
  "confidence_threshold": 0.75,
  "verification": {
    "allowed_scripts": ["test", "lint", "typecheck", "check"],
    "env_allowlist": ["PATH", "HOME", "TMPDIR", "LANG", "LC_ALL", "TERM"]
  },
  "provider_env_allowlist": {
    "codex": [], "cline": [], "antigravity": []
  },
  "gears": {}
}
```

- [ ] **Step 2: Write environment RED test**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { buildSanitizedEnv } from '../src/environment.js';

test('verification environment strips unapproved secret variables', () => {
  const env = buildSanitizedEnv(
    { PATH: '/bin', HOME: '/home/a', SUPER_SECRET_TOKEN: 'nope' },
    ['PATH', 'HOME'],
    { CI: '1' }
  );
  assert.equal(env.PATH, '/bin');
  assert.equal(env.CI, '1');
  assert.equal('SUPER_SECRET_TOKEN' in env, false);
});
```

- [ ] **Step 3: Write route/adapter RED tests**

Normal route uses defaults; high risk selects `REVIEW_STRONG`; second material failure returns `require_arbiter`, `ORCH_ESCALATE_1`, and `WORK_STRONG`. Adapters must emit exact configured model/effort argv and reject unresolved gears.

- [ ] **Step 4: Implement and wire `route` / `print-config`**

`print-config` may print allowed environment **names**, never environment values or inherited secrets.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/config.test.js tests/environment.test.js tests/route.test.js tests/provider-adapters.test.js
npm test
git diff --check
git add factory.config.example.json src/config.js src/environment.js src/route.js src/cli.js \
  src/provider-adapters/index.js src/provider-adapters/codex.js \
  src/provider-adapters/cline.js src/provider-adapters/antigravity.js \
  tests/config.test.js tests/environment.test.js tests/route.test.js tests/provider-adapters.test.js
git commit -m "feat(factory): add concrete gears and sanitized environments"
```

---

### Task 3: Durable state, locks, active-turn stages, cancellation, stale-lock recovery primitive

**Files:**
- Create: `src/ids.js`
- Create: `src/run-lock.js`
- Create: `src/state-machine.js`
- Create: `src/state-store.js`
- Test: `tests/ids.test.js`
- Test: `tests/run-lock.test.js`
- Test: `tests/state-machine.test.js`
- Test: `tests/state-store.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- Produces: `createId('run'|'task'|'turn')`.
- Produces: `withRunLock(runDir, command, fn)`.
- Produces: `inspectRunLock(runDir)`.
- Produces: `recoverDeadRunLock(runDir, { expectedNonce, isPidAlive })`.
- Produces: internal `transitionInternal(state, event, payload)`; not CLI-exposed.
- Produces: `createStateStore(root)`.

Minimum state:

```json
{
  "revision": 0,
  "phase": "PLAN",
  "cancel_requested": false,
  "active_turn": null,
  "material_failures": 0,
  "verification_stale": false,
  "review_stale": false
}
```

Active turn:

```json
{
  "turn_id": "turn_...",
  "role": "worker",
  "stage": "claimed",
  "agent_name": "mf-worker-a1b2-c3d4",
  "workspace_label": "mighty-factory:turn_..."
}
```

- [ ] **Step 1: Write lock RED tests**

Test exclusive second acquisition -> `run_locked`, release in `finally`, and stale lock is not automatically removed.

Test explicit recovery:

```js
test('recovery requires matching nonce and dead pid', async () => {
  // create lock metadata with nonce n1 and pid 4242
  // wrong nonce rejects
  // live pid rejects
  // exact nonce + isPidAlive=false removes only that lock
});
```

- [ ] **Step 2: Write lifecycle RED tests**

Require:

```text
PLAN -> READY only through validated authorize event
repair invalidates verification/review evidence
review failure 1 -> REPAIR_PENDING
review failure 2 -> ESCALATION_PENDING
review failure 3 -> REPLAN_REQUIRED
cancel with no active turn -> CANCELLED
cancel with active turn -> cancel_requested=true, phase unchanged
new specialist claim forbidden while cancel_requested=true
```

- [ ] **Step 3: Write active-turn state-store tests**

Persist and round-trip every stage `claimed|workspace_ready|launched|result_ingested`; revision increments on every state mutation. A mismatched turn ID cannot clear the active turn.

- [ ] **Step 4: Implement atomic JSON state writes**

Use temp-file + rename. `events.jsonl` records old revision/phase, command/event, and resulting revision/phase.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/ids.test.js tests/run-lock.test.js tests/state-machine.test.js tests/state-store.test.js
npm test
git diff --check
git add src/ids.js src/run-lock.js src/state-machine.js src/state-store.js src/cli.js \
  tests/ids.test.js tests/run-lock.test.js tests/state-machine.test.js tests/state-store.test.js
git commit -m "feat(factory): persist recoverable turn leases"
```

---

### Task 4: Git primitives, pinned task worktree, correlated artifacts, outbox invariants

**Files:**
- Create: `src/git.js`
- Create: `src/artifacts.js`
- Test: `tests/git.test.js`
- Test: `tests/artifacts.test.js`

**Interfaces:**
- `resolveBaseSha(repo, baseRef, runner) -> sha`.
- `createTaskWorktree({ repo, baseSha, branch, path }, runner)`.
- `listCommittedPaths(repo, baseSha, commit, runner)`.
- `assertNoOutboxCommitted(repo, commit, runner)`.
- `getWorkerOutboxPath(worktree, turnId)`.
- `ingestResult({ source, destination, expected }) -> { artifact, sha256 }`.
- Worker/reviewer/arbiter artifact validators.

- [ ] **Step 1: Write real-temp-repo base pin test**

Create commit A on `main`, resolve it, advance `main` to B, create task worktree from stored A, assert task HEAD descends from A and the stored SHA did not move.

- [ ] **Step 2: Write outbox RED tests**

Assert `.git/info/exclude` remains byte-identical before/after Factory preparation. Worker result path is untracked. A commit containing `.mighty-factory-outbox/**` is rejected.

- [ ] **Step 3: Write artifact correlation RED tests**

Worker requires exact schema/run/task/turn/role and commit. Reviewer requires exact reviewed commit. Arbiter requires correlated decision/repair strategy. Wrong turn ID is rejected without coercion.

- [ ] **Step 4: Implement native Git worktree creation**

Use argv arrays only:

```text
git -C <repo> rev-parse <base_ref>^{commit}
git -C <repo> worktree add -b <task_branch> <task_path> <base_sha>
```

Do not alter ignore metadata.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/git.test.js tests/artifacts.test.js
npm test
git diff --check
git add src/git.js src/artifacts.js tests/git.test.js tests/artifacts.test.js
git commit -m "feat(factory): pin git state and correlate outbox artifacts"
```

---

### Task 5: Trusted-repository verification policy, allowed paths, sanitized execution

**Files:**
- Create: `src/command-runner.js`
- Create: `src/verification-policy.js`
- Create: `src/verifier.js`
- Test: `tests/verification-policy.test.js`
- Test: `tests/verifier.test.js`

**Interfaces:**
- `runCommand(command, args, { cwd, env }) -> { exitCode, stdout, stderr }` with no shell interpolation.
- `compileVerificationCommand(check, config, repoRoot) -> { command, args }`.
- `assertAllowedPaths(changedPaths, allowedPrefixes)`.
- `verifyWorker({ run, task, turn, reportedCommit, config }, deps) -> verificationArtifact`.

- [ ] **Step 1: Write verification-policy RED tests**

Exact accepted forms:

```js
{ kind: 'npm-script', script: 'test' }
{ kind: 'pnpm-script', script: 'lint' }
{ kind: 'yarn-script', script: 'typecheck' }
{ kind: 'node-test', paths: ['tests/foo.test.js'] }
{ kind: 'node-check', path: 'src/foo.js' }
```

Reject:

```text
script deploy/publish/migrate/install unless explicitly configured allowed
unknown kind
absolute path
../ traversal
shell command representation
npx/package install/migration arbitrary binary representation
```

- [ ] **Step 2: Write worker-verification RED tests**

Prove all cases:

```text
worker-reported PASS + controller test exit 1 -> FAIL
passing tests + changed package.json outside allowed_paths -> FAIL
committed outbox -> FAIL
unexpected untracked notes.tmp -> FAIL
exact worker result outbox only -> allowed temporary status
base..commit git diff --check failure -> FAIL
sanitized env excludes SUPER_SECRET_TOKEN
verified evidence contains exact reported commit
```

- [ ] **Step 3: Implement controller-owned Git invariants**

Always execute:

```text
git rev-parse <commit>^{commit}
git merge-base --is-ancestor <base_sha> <commit>
git diff --name-only <base_sha>..<commit>
git diff --check <base_sha>..<commit>
git status --porcelain=v1 --untracked-files=all
```

Do not describe `diff --check` as syntax validation.

- [ ] **Step 4: Cap captured output**

Persist at most 16 KiB stdout and 16 KiB stderr tail per verification command.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/verification-policy.test.js tests/verifier.test.js tests/git.test.js tests/environment.test.js
npm test
git diff --check
git add src/command-runner.js src/verification-policy.js src/verifier.js \
  tests/verification-policy.test.js tests/verifier.test.js
git commit -m "feat(factory): enforce trusted scoped verification"
```

---

### Task 6: Herdr wrapper and crash-resumable fresh-turn launcher

**Files:**
- Create: `src/herdr.js`
- Create: `src/turn-launcher.js`
- Create: `src/recovery.js`
- Test: `tests/herdr.test.js`
- Test: `tests/turn-launcher.test.js`
- Test: `tests/recovery.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `createHerdrClient(runner)` with `workspaceList`, `workspaceCreate`, `workspaceGet`, `workspaceClose`, `paneList`, `agentGet`, `agentStart`, `agentPrompt`, `agentWait`, `agentRead`.
- `reconcileTurnLaunch({ run, activeTurn, gearName, cwd, prompt, resultPath }, deps) -> launchRecord`.
- `recoverRun({ runId, lockNonce }, deps) -> recoveryReport`.

- [ ] **Step 1: Write Herdr parsing tests against synthetic current-doc shapes**

Require workspace create response IDs to come from returned JSON. No predicted IDs. `blocked` fails immediately, `unknown` is never completion, and prompt timeout/stall returns `inspect_required` rather than resending.

- [ ] **Step 2: Write deterministic launch identity RED test**

For a known turn ID, assert the exact same agent name/workspace label is produced on every retry:

```text
agent: mf-worker-<runSuffix>-<turnSuffix>
workspace label: mighty-factory:<turn_id>
```

- [ ] **Step 3: Write crash reconciliation RED tests**

Cover each case independently:

```text
claimed + no workspace/agent -> create workspace/start same turn
claimed + exactly one matching labelled workspace -> adopt it
matching agent already exists -> do not call agent start again
more than one matching workspace -> BLOCKED
launched + agent missing + expected result exists -> return ingest_result
launched + agent missing + no result -> BLOCKED
```

The test must assert repeated dispatch never allocates a new turn ID.

- [ ] **Step 4: Write stale-lock recovery RED test**

`recover-run` requires matching nonce and a dead PID. After lock recovery it immediately reconciles the existing active turn; it does not clear active_turn or allocate a replacement.

- [ ] **Step 5: Implement launch under the run lock only through Herdr acknowledgement**

Do not hold the run lock while waiting for the model to finish. Lock scope is claim -> workspace reconcile/create -> agent reconcile/start -> persist `stage=launched` -> release.

Then wait/inspect outside the lock. Result ingestion reacquires the lock.

- [ ] **Step 6: Verify exact gear activation**

Regression test launches `WORK_DEFAULT`, then after escalation a fresh `WORK_STRONG`; assert different concrete argv and different turn IDs. Arbiter uses a fresh `ORCH_ESCALATE_1` process.

- [ ] **Step 7: Verify and commit**

```bash
node --test tests/herdr.test.js tests/turn-launcher.test.js tests/recovery.test.js
npm test
git diff --check
git add src/herdr.js src/turn-launcher.js src/recovery.js src/cli.js \
  tests/herdr.test.js tests/turn-launcher.test.js tests/recovery.test.js
git commit -m "feat(factory): reconcile crash-safe specialist launches"
```

---

### Task 7: Run preparation, independent reviewer clone, review guard, arbiter bundle

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
- `prepareRun({ task, classification, config }, deps) -> runRecord`.
- `createReviewClone({ sourceRepo, verifiedCommit, path, ownership }, runner)`.
- `snapshotReviewClone(path, runner) -> { head, status }`.
- `assertReviewCloneIntegrity(before, after, expectedOutbox)`.
- `createArbiterBundle({ run, turn, evidence, path }) -> bundleRecord`.

- [ ] **Step 1: Write run-preparation RED test**

Assert:

```text
base_ref resolved once to base_sha
task worktree created from base_sha
run.json records exact owned task worktree
no agent launch occurs
no Git ignore metadata changes
```

- [ ] **Step 2: Write independent clone RED test**

Use a real temp repo:

```text
git clone --no-local --no-checkout <source> <clone>
git -C <clone> checkout --detach <verifiedCommit>
git -C <clone> remote remove origin
```

Assert clone's `git rev-parse --git-common-dir` resolves inside the clone rather than the source repository, `git remote` is empty, and HEAD equals exact verified commit.

- [ ] **Step 3: Write review integrity RED tests**

Before/after full porcelain status:

```text
exact review-result outbox only -> PASS integrity
notes.tmp -> FAIL
tracked edit -> FAIL
HEAD move/new commit -> FAIL
```

- [ ] **Step 4: Write arbiter bundle RED test**

The bundle contains copied JSON evidence and adjudication question but does **not** contain `target_repo`, task worktree path, `.git`, source remote, or mutable checkout. Expected write path is only the arbiter outbox.

- [ ] **Step 5: Add ownership markers**

Reviewer clone and arbiter bundle root each contain controller-owned metadata with `run_id`, `turn_id`, resource type, and random ownership nonce. Cleanup requires exact marker match.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/prepare-run.test.js tests/review-clone.test.js tests/review-guard.test.js tests/arbiter-bundle.test.js
npm test
git diff --check
git add src/prepare-run.js src/review-clone.js src/review-guard.js src/arbiter-bundle.js src/cli.js \
  tests/prepare-run.test.js tests/review-clone.test.js tests/review-guard.test.js tests/arbiter-bundle.test.js
git commit -m "feat(factory): isolate review and arbiter workspaces"
```

---

### Task 8: Controller operations, cancellation boundary, dispatch/recovery loop, real escalation

**Files:**
- Create: `src/controller.js`
- Test: `tests/controller.test.js`
- Modify: `src/cli.js`
- Modify: `src/state-machine.js`
- Modify: `src/state-store.js`
- Modify: `src/artifacts.js`
- Modify: `src/recovery.js`

**Interfaces:**
- `createController(deps)` produces:
  - `authorizeExecute`
  - `cancel`
  - `recoverRun`
  - `prepareRun`
  - `dispatchWorker`
  - `verifyWorker`
  - `dispatchReviewer`
  - `verifyReview`
  - `dispatchArbiter`
  - `recordRepair`
  - `status`
  - `cleanup`

- [ ] **Step 1: Write happy-path RED test**

Exercise:

```text
PLAN -> authorize /execute -> READY
prepare -> pinned task worktree
claim + launch WORK_DEFAULT
worker commit C1 + correlated result
independent controller verification C1
independent reviewer clone C1 with no origin
claim + launch REVIEW_DEFAULT
review PASS C1 + only exact outbox delta
DONE
```

- [ ] **Step 2: Write duplicate/crash RED tests**

Assert:

```text
two concurrent dispatch-worker attempts -> one active turn, one agent launch
crash after claim before launch -> recover/re-dispatch uses same turn ID
crash after agent start before launch persistence -> deterministic agent reconciliation adopts same agent
stale old result cannot clear current active turn
```

- [ ] **Step 3: Write cancellation race RED tests**

```text
cancel before turn claim -> CANCELLED, no agent
cancel after active worker claimed -> cancel_requested true; current turn may finish
when current result is ingested and cancel_requested true -> no verification/reviewer/next turn; transition CANCELLED
cancel during reviewer -> reviewer can finish; no DONE/new turn afterward; CANCELLED
```

- [ ] **Step 4: Write escalation RED test**

First review FAIL -> bounded repair. Second review FAIL -> isolated fresh `ORCH_ESCALATE_1` arbiter bundle/process -> next worker `WORK_STRONG`. Third FAIL -> `REPLAN_REQUIRED`; fourth dispatch rejected.

- [ ] **Step 5: Wire all public CLI commands**

```text
mighty-factory authorize-execute --task task.json --classification classification.json --config factory.config.json
mighty-factory cancel --run <id>
mighty-factory recover-run --run <id> --lock-nonce <nonce>
mighty-factory prepare-run --run <id>
mighty-factory dispatch-worker --run <id>
mighty-factory verify-worker --run <id> --turn <id>
mighty-factory dispatch-reviewer --run <id>
mighty-factory verify-review --run <id> --turn <id>
mighty-factory dispatch-arbiter --run <id>
mighty-factory record-repair --run <id> --file repair.json
mighty-factory status --run <id>
```

Every success writes one JSON object to stdout. Operational errors write structured error information to stderr and exit 1.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/controller.test.js tests/recovery.test.js tests/run-lock.test.js tests/state-machine.test.js
npm test
git diff --check
git add src/controller.js src/cli.js src/state-machine.js src/state-store.js src/artifacts.js src/recovery.js \
  tests/controller.test.js
git commit -m "feat(factory): enforce recoverable leased orchestration"
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
- `cleanupRun({ runId, removeTaskWorktree = false }, deps) -> cleanupReport`.
- `runDoctor({ configPath, env }, deps) -> { ok, checks[] }`.

- [ ] **Step 1: Write cleanup RED tests**

Require:

```text
close exact recorded Herdr workspace via workspace close
no generic agent-stop assumption
delete exact ingested outbox dir only
remove ownership-marked reviewer clone only after Herdr workspace close
remove ownership-marked arbiter bundle only after close
unrecorded path is never deleted
wrong ownership nonce is never deleted
idempotent missing resource is nonfatal
task worktree retained by default
task worktree explicit cleanup uses native git worktree remove without --force
dirty task worktree refusal is reported, not forced
branch remains
```

- [ ] **Step 2: Write doctor RED tests**

Check Node/Git/Herdr, six resolved gears, concrete adapter argv, writable state/temp roots, lock primitive, trusted-repository warning, synthetic secret stripped from verification env, safe verification fixtures, review clone `origin` removal, and availability of the Herdr workspace lifecycle operations used by cleanup.

If model introspection is unavailable, return `configured-not-provider-validated` rather than claiming model validity.

- [ ] **Step 3: Write contract RED tests**

Worker prompt requires commit-before-result, exact task worktree, no merge/deploy, exact IDs/outbox.

Reviewer prompt must **not** expose `target_repo` or task worktree path; it receives requirements, `BASE_SHA`, `VERIFIED_COMMIT`, verification evidence, independent clone cwd, read-only rule, and exact outbox.

Arbiter prompt receives only evidence-bundle paths/contents and adjudication question; no target checkout path.

Orchestrator skill requires exact `/execute`, `/cancel`, `recover-run` only for explicit stale-lock recovery, no shadow lifecycle, and no inferred DONE.

- [ ] **Step 4: Implement README-facing trust language in contracts**

Prompts/skill must state that v0.1 is trusted-repository automation, not a security sandbox.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/cleanup.test.js tests/doctor.test.js tests/contracts.test.js
npm test
git diff --check
git add src/cleanup.js src/doctor.js src/cli.js prompts/worker.md prompts/reviewer.md prompts/arbiter.md \
  skills/mighty-factory-orchestrator/SKILL.md tests/cleanup.test.js tests/doctor.test.js tests/contracts.test.js
git commit -m "feat(factory): add trusted readiness and owned cleanup"
```

---

### Task 10: E2E regressions, README, final acceptance matrix

**Files:**
- Create: `README.md`
- Create: `tests/e2e-controller.test.js`
- Modify: `package.json`

- [ ] **Step 1: Write E2E happy-path test**

Use a real temporary Git repo/state/temp root plus fake Herdr agent execution. Exercise:

```text
valid trusted task/classification
/execute authorization
base SHA pin
task worktree
atomic worker claim + deterministic identity
WORK_DEFAULT launch
worker commit then result outbox
allowed-path + Git + sanitized trusted-repo verification PASS
independent review clone --no-local, detached at C1, origin removed
atomic REVIEW_DEFAULT turn
review PASS exact C1 with only result outbox delta
DONE
```

- [ ] **Step 2: Add required E2E regression scenarios**

Same test file must prove:

```text
duplicate worker dispatch launches once
crash after claim resumes same turn ID
crash after agent start adopts same deterministic agent
wrong stale-lock nonce cannot recover
live lock PID cannot recover
cancel before claim launches nothing
cancel after claim finishes current turn but starts no next turn
moving base_ref does not move base_sha
forbidden changed path fails despite passing tests
committed outbox fails
unapproved package script deploy fails before execution
synthetic SUPER_SECRET_TOKEN absent from verification env
committed whitespace error caught by base..commit diff-check
review clone shares no Git common dir with source and has no origin
reviewer arbitrary untracked file invalidates PASS
arbiter bundle contains no target_repo/task worktree path
second review failure launches ORCH_ESCALATE_1 then WORK_STRONG concrete argv
third failure stops at REPLAN_REQUIRED
cleanup cannot remove wrong-nonce/unowned resource
dirty task worktree is not force-removed
main branch unchanged
```

- [ ] **Step 3: Write README**

Required sections:

```text
What Mighty Factory is
Security model: trusted local repositories only; not a sandbox
Prerequisites: Node 20+, Git, Herdr, configured provider CLIs
Concrete gear configuration and provider env allowlists
Safe verification kinds and allowed script names
PLAN and exact /execute
Cancellation point-of-no-return semantics
Crash recovery and recover-run stale-lock nonce flow
Task worktree + worker outbox
Independent reviewer clone with origin removed
Arbiter evidence bundle
Real escalation and three-failure cap
Owned-resource cleanup and no-force policy
Durable state locations
No automatic merge/deploy
Qualification levels
```

- [ ] **Step 4: Add scripts**

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

Expected: all applicable commands exit 0; doctor may return a documented readiness failure only when local provider gear IDs have not yet been filled with real installed values.

- [ ] **Step 6: Self-review canonical spec coverage**

At the same HEAD verify explicitly:

```text
trusted-repository warning, no sandbox claim
exact /execute
no generic transition
run lock + staged active_turn
explicit stale-lock recovery
crash-resume same logical turn
cancel_requested semantics
base_sha immutable
allowed_paths committed-diff audit
outbox not committed; no Git ignore mutation
safe script-name/verification policy
sanitized verification env
controller-owned base..commit diff hygiene
fresh exact gear launch per turn
independent reviewer clone; origin removed
arbiter evidence bundle only
reviewer tracked/untracked integrity
three-failure cap
owned cleanup using Herdr workspace close / safe native Git removal
DONE same verified/reviewed commit only
no implicit merge/deploy
```

- [ ] **Step 7: Commit**

```bash
git add README.md package.json tests/e2e-controller.test.js
git commit -m "docs(factory): complete review-4 v0.1 acceptance gate"
```

---

## Review Gate After Every Task

After each Task 1–10:

1. run the task's focused tests and observe GREEN,
2. run `npm test`,
3. run `git diff --check`,
4. inspect changed files and `git status --short`,
5. explicitly `git add` only that task's files,
6. commit,
7. request fresh independent code review before starting the next task.

Do not batch tasks.

## Final Acceptance Labels

### `UNIT_INTEGRATION_COMPLETE`

May be reported only after the full local matrix passes at one HEAD, including E2E fake-Herdr crash/cancel/recovery cases.

### `HERDR_RUNTIME_QUALIFIED`

Requires a disposable provider-backed run on the user's Mac inside Herdr proving:

```text
PLAN launches no specialist
/execute validates trusted-repo contract and pins base SHA
WORK_DEFAULT starts with exact configured args
forced controller interruption after claim resumes same logical turn
forced interruption after agent launch adopts same deterministic agent
active-turn cancellation starts no next turn
worker result is correlated and independently verified
synthetic secret is absent from verification subprocess env
reviewer uses independent clone with no origin
reviewer stray file invalidates PASS
arbiter runs only from evidence bundle
second failure launches actual ORCH_ESCALATE_1 then WORK_STRONG
third failure stops
cleanup closes exact Herdr workspace IDs and does not force-remove dirty worktrees
main remains unchanged
```

Without that provider-backed smoke run, do not claim runtime qualification.
