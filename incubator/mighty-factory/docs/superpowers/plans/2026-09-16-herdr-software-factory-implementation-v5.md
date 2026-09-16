# Mighty Factory v0.1 Implementation Plan — Review 5

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the canonical Review-5 Mighty Factory as a dependency-free Node.js controller around Herdr with trusted-repository execution, immutable run configuration, crash-resumable resource preparation and specialist dispatch, prompt-delivery ambiguity protection, exact gear activation, pinned Git identity, safe structured verification, independent reviewer clones, bounded escalation, and owned-resource cleanup.

**Architecture:** The conversational Luna-Max Codex session owns planning and judgment. The controller owns state, immutable run policy, locking, resource reconciliation, launch identity, prompt delivery safety, Git verification, artifact correlation, cancellation, cleanup, and DONE. Workers operate in one task worktree, reviewers operate in independent temporary clones with `origin` removed, and arbiters operate only on copied evidence bundles. v0.1 deliberately does not claim to sandbox untrusted repository code.

**Tech Stack:** Node.js >= 20, ESM, built-in `node:test`, `fs`, `path`, `os`, `crypto`, `child_process`; native Git; Herdr CLI; no runtime npm dependencies.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-16-herdr-software-factory-design-v5.md`

## Global Constraints

- Work only under `incubator/mighty-factory/` on branch `incubator/mighty-factory-v0`.
- Do not modify Mighty Router mainline behavior or `universal-agent-loop`.
- TDD every behavior: observe RED before production implementation, then GREEN.
- PLAN is non-mutating; only exact `/execute` authorizes execution.
- v0.1 accepts only `execution_trust: "trusted-local-repository"`; it is not an untrusted-code sandbox.
- No public generic lifecycle `transition` command.
- Every state-changing operation uses a per-run lock.
- Authorization persists immutable non-secret `config.snapshot.json` + digest; later run commands never reread mutable operator policy for decisions.
- Every prepared resource has deterministic intended identity persisted before external creation.
- Every specialist turn has deterministic persisted launch identity before Herdr mutation.
- Prompt payload/digest and `prompt_attempted` are persisted before prompt delivery.
- Ambiguous prompt delivery is never blindly retried.
- Repeated dispatch/recovery reconciles the same active turn; it never allocates a second turn while one exists.
- Cancellation during an active turn sets `cancel_requested`; it does not erase the claimed turn.
- Pin `base_ref` once to `base_sha`.
- Enforce `allowed_paths` against `base_sha..<reported_commit>`.
- Never modify `.git/info/exclude` or tracked `.gitignore` for Factory outboxes.
- Worker commits implementation before writing its outbox result.
- Verification task commands are structured and script-name allowlisted; no arbitrary executable argv.
- Verification subprocess environment is sanitized and does not inherit unapproved secret variables.
- Recheck worker worktree state after all repository verification commands.
- `git diff --check base..commit` is whitespace/diff hygiene only, not syntax validation.
- Reviewer uses an independent `git clone --no-local` with `origin` removed, not a linked worktree.
- Reviewer isolation means repository/Git-metadata isolation only.
- Arbiter receives an evidence bundle, not a target checkout.
- Cleanup refuses resources referenced by nonterminal `active_turn`.
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
    config-snapshot.js
    route.js
    environment.js
    run-lock.js
    state-machine.js
    state-store.js
    git.js
    resource-plan.js
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
    config-snapshot.test.js
    route.test.js
    environment.test.js
    provider-adapters.test.js
    ids.test.js
    run-lock.test.js
    state-machine.test.js
    state-store.test.js
    git.test.js
    resource-plan.test.js
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

- [ ] **Step 1: Write failing CLI surface tests**

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

test('help exposes high-level controller commands and no raw transition', () => {
  const r = spawnSync(process.execPath, [bin, 'help'], { encoding: 'utf8' });
  assert.equal(r.status, 0);
  for (const name of required) assert.match(r.stdout, new RegExp(`mighty-factory ${name}`));
  assert.doesNotMatch(r.stdout, /mighty-factory transition/);
});

test('unknown command exits with usage error', () => {
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

test('accepts exact trusted repository mode', () => {
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

Create `tests/classify-schema.test.js` covering exact spec enums, boolean `cross_cutting`, finite numeric confidence in `0..1`, and rejection of coercion such as string confidence.

- [ ] **Step 4: Run RED**

```bash
cd incubator/mighty-factory
node --test tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
```

Expected: FAIL because package/modules do not exist.

- [ ] **Step 5: Implement minimal package and CLI**

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

`src/errors.js`:

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

Reserve all public command names. Commands not implemented yet return `OperationalError('not_implemented', ...)`, not a usage error.

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

### Task 2: Config, immutable run snapshot, environment policy, concrete gears

**Files:**
- Create: `factory.config.example.json`
- Create: `src/config.js`
- Create: `src/config-snapshot.js`
- Create: `src/environment.js`
- Create: `src/route.js`
- Create: `src/provider-adapters/index.js`
- Create: `src/provider-adapters/codex.js`
- Create: `src/provider-adapters/cline.js`
- Create: `src/provider-adapters/antigravity.js`
- Test: `tests/config.test.js`
- Test: `tests/config-snapshot.test.js`
- Test: `tests/environment.test.js`
- Test: `tests/route.test.js`
- Test: `tests/provider-adapters.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `loadConfig(path) -> validatedConfig`.
- `buildRunConfigSnapshot(config) -> snapshot`.
- `digestRunConfigSnapshot(snapshot) -> sha256 hex`.
- `writeRunConfigSnapshot(runDir, snapshot) -> { path, digest }`.
- `readPinnedRunConfig(runDir, expectedDigest) -> snapshot`.
- `buildSanitizedEnv(sourceEnv, allowedNames, fixed) -> env`.
- `routeTask({ classification, state, snapshot }) -> route`.
- `buildLaunchSpec(adapterName, gear, context) -> { herdrKind, argv, envNames, artifactTransport }`.

Specialist gears required:

```text
ORCH_ESCALATE_1 WORK_DEFAULT WORK_STRONG REVIEW_DEFAULT REVIEW_STRONG
```

Foreman config is separate:

```json
{
  "foreman_expected": {
    "provider": "codex",
    "model_alias": "luna",
    "effort": "max"
  }
}
```

- [ ] **Step 1: Write failing config tests**

Reject missing specialist gear, unresolved launch, empty model/effort args, unknown adapter, invalid confidence threshold, relative state/temp roots after expansion, and unsafe default allowed scripts such as deploy/publish/migrate/install.

- [ ] **Step 2: Write failing snapshot immutability test**

```js
// tests/config-snapshot.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { buildRunConfigSnapshot, digestRunConfigSnapshot } from '../src/config-snapshot.js';

test('snapshot excludes secret values and is stable after live config mutation', () => {
  const config = {
    confidence_threshold: 0.75,
    state_root: '/state', temp_root: '/tmp/factory',
    verification: { allowed_scripts: ['test'], env_allowlist: ['PATH'] },
    provider_env_allowlist: { codex: ['OPENAI_API_KEY'] },
    foreman_expected: { provider: 'codex', model_alias: 'luna', effort: 'max' },
    gears: { WORK_DEFAULT: { provider_adapter: 'antigravity', herdr_kind: 'agy', model_alias: 'x', effort: 'high', launch: { resolved: true, model_args: ['--model','x'], effort_args: ['--effort','high'], extra_args: [] } } }
  };
  const snap = buildRunConfigSnapshot(config);
  const digest = digestRunConfigSnapshot(snap);
  config.confidence_threshold = 0.1;
  assert.equal(snap.confidence_threshold, 0.75);
  assert.equal(digestRunConfigSnapshot(snap), digest);
  assert.equal(JSON.stringify(snap).includes('OPENAI_API_KEY'), true); // name may be pinned
  assert.equal(JSON.stringify(snap).includes('secret-value'), false); // values are never present
});
```

Add a persistence test: write snapshot, alter mutable config file, read pinned snapshot by digest, and assert route-relevant values did not change.

- [ ] **Step 3: Write environment RED test**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { buildSanitizedEnv } from '../src/environment.js';

test('sanitized environment strips unapproved secret variables', () => {
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

- [ ] **Step 4: Write route and adapter RED tests**

Normal route uses default worker/reviewer. High risk selects `REVIEW_STRONG`. Second material failure returns `require_arbiter`, `ORCH_ESCALATE_1`, and `WORK_STRONG`. Adapters emit exact concrete argv from the snapshot and reject unresolved gear.

- [ ] **Step 5: Implement and wire `route` / `print-config`**

`print-config` may print allowed environment **names**, never values. Run commands after authorization use pinned snapshot only.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/config.test.js tests/config-snapshot.test.js tests/environment.test.js tests/route.test.js tests/provider-adapters.test.js
npm test
git diff --check
git add factory.config.example.json src/config.js src/config-snapshot.js src/environment.js src/route.js src/cli.js \
  src/provider-adapters/index.js src/provider-adapters/codex.js \
  src/provider-adapters/cline.js src/provider-adapters/antigravity.js \
  tests/config.test.js tests/config-snapshot.test.js tests/environment.test.js \
  tests/route.test.js tests/provider-adapters.test.js
git commit -m "feat(factory): pin run policy and concrete gears"
```

---

### Task 3: Durable state, locks, active-turn stages, cancellation, stale-lock recovery

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
- `createId('run'|'task'|'turn')`.
- `withRunLock(runDir, command, fn)`.
- `inspectRunLock(runDir)`.
- `recoverDeadRunLock(runDir, { expectedNonce, isPidAlive })`.
- internal `transitionInternal(state, event, payload)`; not CLI-exposed.
- `createStateStore(root)`.

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

Active turn stages:

```text
claimed workspace_ready agent_started prompt_attempted result_ingested
```

- [ ] **Step 1: Write lock RED tests**

Second exclusive acquisition -> `run_locked`; lock releases in `finally`; stale lock is not auto-removed; explicit recovery requires exact nonce + dead PID.

- [ ] **Step 2: Write lifecycle RED tests**

Require review-failure progression, evidence invalidation on repair, cancel-before-turn -> `CANCELLED`, cancel-with-active-turn -> `cancel_requested=true`, and new specialist claim rejected while cancel requested.

- [ ] **Step 3: Write active-turn/prompt-stage RED tests**

Persist and round-trip every stage. Require `prompt_digest` when stage is `prompt_attempted`. Mismatched turn ID cannot clear active turn. Revision increments on each durable state mutation.

- [ ] **Step 4: Implement atomic JSON writes and events**

Use temp-file + rename. `events.jsonl` records old/new revisions/phases and event/command.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/ids.test.js tests/run-lock.test.js tests/state-machine.test.js tests/state-store.test.js
npm test
git diff --check
git add src/ids.js src/run-lock.js src/state-machine.js src/state-store.js src/cli.js \
  tests/ids.test.js tests/run-lock.test.js tests/state-machine.test.js tests/state-store.test.js
git commit -m "feat(factory): persist recoverable lifecycle state"
```

---

### Task 4: Git primitives, deterministic resource plans, artifacts, outbox invariants

**Files:**
- Create: `src/git.js`
- Create: `src/resource-plan.js`
- Create: `src/artifacts.js`
- Test: `tests/git.test.js`
- Test: `tests/resource-plan.test.js`
- Test: `tests/artifacts.test.js`

**Interfaces:**
- `resolveBaseSha(repo, baseRef, runner) -> sha`.
- `makeTaskResourcePlan({ runId, tempRoot, baseSha }) -> { branch, worktreePath, stage:'intended' }`.
- `reconcileTaskWorktree(plan, repo, runner) -> resourceRecord`.
- `listCommittedPaths(repo, baseSha, commit, runner)`.
- `assertNoOutboxCommitted(repo, commit, runner)`.
- `getWorkerOutboxPath(worktree, turnId)`.
- `ingestResult({ source, destination, expected }) -> { artifact, sha256 }`.
- Worker/reviewer/arbiter artifact validators.

- [ ] **Step 1: Write base-pin RED test with real temp repo**

Resolve commit A from `main`, advance main to B, then assert task plan remains based on A.

- [ ] **Step 2: Write task-resource crash-reconciliation RED tests**

```text
intended path absent + branch absent -> create once
retry with exact recorded worktree/branch -> adopt, no second worktree
recorded path exists but is not Git worktree -> BLOCKED
recorded branch exists at incompatible commit -> BLOCKED
retry never allocates a new branch/path
```

- [ ] **Step 3: Write outbox RED tests**

Assert `.git/info/exclude` byte-identical before/after. Worker result remains untracked. Any commit containing `.mighty-factory-outbox/**` is rejected.

- [ ] **Step 4: Write artifact correlation RED tests**

Require exact schema/run/task/turn/role. Reviewer requires exact reviewed commit. Arbiter requires correlated decision. Wrong turn cannot be coerced into active one.

- [ ] **Step 5: Implement native Git commands with argv arrays**

```text
git -C <repo> rev-parse <base_ref>^{commit}
git -C <repo> worktree add -b <recorded_branch> <recorded_path> <base_sha>
```

No ignore metadata changes.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/git.test.js tests/resource-plan.test.js tests/artifacts.test.js
npm test
git diff --check
git add src/git.js src/resource-plan.js src/artifacts.js \
  tests/git.test.js tests/resource-plan.test.js tests/artifacts.test.js
git commit -m "feat(factory): reconcile pinned git resources"
```

---

### Task 5: Trusted verification policy, allowed paths, sanitized execution, post-check status

**Files:**
- Create: `src/command-runner.js`
- Create: `src/verification-policy.js`
- Create: `src/verifier.js`
- Test: `tests/verification-policy.test.js`
- Test: `tests/verifier.test.js`

**Interfaces:**
- `runCommand(command, args, { cwd, env }) -> { exitCode, stdout, stderr }` without shell interpolation.
- `compileVerificationCommand(check, snapshot, repoRoot) -> { command, args }`.
- `assertAllowedPaths(changedPaths, allowedPrefixes)`.
- `verifyWorker({ run, task, turn, reportedCommit, snapshot }, deps) -> verificationArtifact`.

- [ ] **Step 1: Write verification-policy RED tests**

Accept only exact supported kinds and allowed script names. Reject deploy/publish/migrate/install unless explicitly present in pinned snapshot, unknown kind, absolute/traversal node paths, shell representation, npx/package install/arbitrary binary forms.

- [ ] **Step 2: Write worker-verification RED tests**

Prove:

```text
worker-reported PASS + controller test exit 1 -> FAIL
passing tests + forbidden package.json change -> FAIL
committed outbox -> FAIL
unexpected notes.tmp before checks -> FAIL
exact worker result outbox only -> allowed temporary state
base..commit diff-check failure -> FAIL
SUPER_SECRET_TOKEN absent from verification env
verification command exits 0 but creates generated.tmp -> FAIL on final status recheck
verification command modifies tracked file -> FAIL on final status recheck
verified evidence binds exact commit and pinned config digest
```

- [ ] **Step 3: Implement exact verification order**

```text
correlation -> commit/HEAD/ancestry -> changed paths -> committed outbox -> diff check -> initial status -> repository checks -> final status -> evidence
```

Final status permits only exact expected worker-result outbox.

- [ ] **Step 4: Cap captured output**

Store at most 16 KiB stdout tail and 16 KiB stderr tail per command.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/verification-policy.test.js tests/verifier.test.js tests/git.test.js tests/environment.test.js
npm test
git diff --check
git add src/command-runner.js src/verification-policy.js src/verifier.js \
  tests/verification-policy.test.js tests/verifier.test.js
git commit -m "feat(factory): enforce trusted verification integrity"
```

---

### Task 6: Herdr wrapper, prompt-safe turn launcher, crash recovery

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
- `buildTurnPrompt(request) -> exact string`.
- `reconcileTurnLaunch({ run, activeTurn, gearName, cwd, request, resultPath }, deps) -> launchReport`.
- `recoverRun({ runId, lockNonce }, deps) -> recoveryReport`.

- [ ] **Step 1: Write Herdr parsing RED tests**

Synthetic current-doc fixtures must provide real returned IDs. `blocked` fails; `unknown` never equals completion; prompt timeout/stall yields `inspect_required`, not resend.

- [ ] **Step 2: Write deterministic launch identity RED test**

Same run/turn always produces same agent name and workspace label.

- [ ] **Step 3: Write launch crash reconciliation RED tests**

```text
claimed + no workspace -> create exact labelled workspace
matching one workspace -> adopt
matching agent exists -> no second agent start
multiple matching workspaces/agents -> BLOCKED
agent_started retry -> reuse same agent
```

- [ ] **Step 4: Write prompt ambiguity RED tests**

```js
// Conceptual assertions in tests/turn-launcher.test.js
// 1. request prompt bytes are persisted and hashed before herdr.agentPrompt is called
// 2. state becomes prompt_attempted before the call
// 3. crash/throw after agentPrompt call leaves prompt_attempted
// 4. retry with prompt_attempted + no proof of non-delivery never calls agentPrompt again
// 5. valid expected result -> ingest path returned
// 6. definitely-not-delivered evidence -> same persisted prompt may be sent once
// 7. ambiguous delivery + no result -> BLOCKED
```

Use a fake Herdr client whose `agentPrompt` records calls and then throws to simulate crash-after-delivery ambiguity.

- [ ] **Step 5: Write stale-lock recovery RED test**

Exact nonce + dead PID required. After lock recovery, reconcile existing active turn and prompt stage; never clear/replace it.

- [ ] **Step 6: Verify gear activation**

`WORK_DEFAULT` and later `WORK_STRONG` use distinct concrete argv and distinct turn IDs. Arbiter uses fresh `ORCH_ESCALATE_1`.

- [ ] **Step 7: Verify and commit**

```bash
node --test tests/herdr.test.js tests/turn-launcher.test.js tests/recovery.test.js
npm test
git diff --check
git add src/herdr.js src/turn-launcher.js src/recovery.js src/cli.js \
  tests/herdr.test.js tests/turn-launcher.test.js tests/recovery.test.js
git commit -m "feat(factory): reconcile prompt-safe specialist turns"
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
- `prepareRun({ runId }, deps) -> runRecord`, reading task/classification/pinned snapshot from durable run state.
- `makeReviewClonePlan({ runId, turnId, tempRoot, verifiedCommit, ownershipNonce })`.
- `reconcileReviewClone(plan, sourceRepo, runner) -> cloneRecord`.
- `snapshotReviewClone(path, runner) -> { head, status }`.
- `assertReviewCloneIntegrity(before, after, expectedOutbox)`.
- `makeArbiterBundlePlan(...)`.
- `reconcileArbiterBundle(plan, evidence) -> bundleRecord`.

- [ ] **Step 1: Write run-preparation RED tests**

Assert pinned config digest exists before preparation, intended task resource is persisted before Git mutation, retry adopts exact resource, no specialist is launched, and no ignore metadata changes occur.

- [ ] **Step 2: Write independent-clone crash-reconciliation RED tests**

Use real temp repo. Before clone, persist exact intended path + nonce. Test:

```text
absent path -> clone --no-local --no-checkout, detach commit, remove origin, marker ready
retry exact marker/commit/no-origin -> adopt same clone
path exists wrong marker -> BLOCKED
path exists wrong HEAD -> BLOCKED
retry never allocates alternate clone path
```

Assert `git rev-parse --git-common-dir` resolves inside clone and `git remote` is empty.

- [ ] **Step 3: Write review integrity RED tests**

Exact review-result outbox only passes; notes.tmp, tracked edit, rename/delete, or HEAD movement fails.

- [ ] **Step 4: Write arbiter-bundle reconciliation RED tests**

Persist intended path/nonce first. Bundle must contain sanitized evidence and no `target_repo`, task-worktree absolute path, `.git`, remote URL, or secrets. Retry adopts exact marked bundle; wrong marker/path contents block.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/prepare-run.test.js tests/review-clone.test.js tests/review-guard.test.js tests/arbiter-bundle.test.js
npm test
git diff --check
git add src/prepare-run.js src/review-clone.js src/review-guard.js src/arbiter-bundle.js src/cli.js \
  tests/prepare-run.test.js tests/review-clone.test.js tests/review-guard.test.js tests/arbiter-bundle.test.js
git commit -m "feat(factory): reconcile isolated run resources"
```

---

### Task 8: Controller operations, authorization snapshot, cancellation, dispatch/recovery, escalation

**Files:**
- Create: `src/controller.js`
- Test: `tests/controller.test.js`
- Modify: `src/cli.js`
- Modify: `src/state-machine.js`
- Modify: `src/state-store.js`
- Modify: `src/artifacts.js`
- Modify: `src/recovery.js`
- Modify: `src/config-snapshot.js`

**Interfaces:**
- `createController(deps)` produces `authorizeExecute`, `cancel`, `recoverRun`, `prepareRun`, `dispatchWorker`, `verifyWorker`, `dispatchReviewer`, `verifyReview`, `dispatchArbiter`, `recordRepair`, `status`, `cleanup`.

- [ ] **Step 1: Write authorization snapshot RED test**

Authorize using mutable config with threshold/gears A, persist run snapshot+digest, mutate original config to threshold/gears B, then assert every later controller route/launch still uses snapshot A.

- [ ] **Step 2: Write happy-path RED test**

Exercise PLAN -> authorize -> snapshot -> pinned worktree -> worker turn -> verification -> independent reviewer clone -> PASS -> DONE.

- [ ] **Step 3: Write duplicate/crash/prompt RED tests**

Assert two worker dispatches launch once; crash after claim resumes same turn; crash after agent start adopts agent; prompt-attempt ambiguity does not trigger resend; stale result cannot clear current turn.

- [ ] **Step 4: Write cancellation race RED tests**

Cancel before claim launches nothing. Cancel after active worker claim permits current turn completion but blocks verification/reviewer/new turn. Cancel during reviewer permits result ingestion but prevents DONE and transitions CANCELLED before further mutation.

- [ ] **Step 5: Write escalation RED test**

First material FAIL -> repair. Second -> isolated `ORCH_ESCALATE_1` arbiter -> next worker `WORK_STRONG`. Third -> `REPLAN_REQUIRED`; fourth automatic dispatch rejected.

- [ ] **Step 6: Wire all CLI commands**

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

- [ ] **Step 7: Verify and commit**

```bash
node --test tests/controller.test.js tests/config-snapshot.test.js tests/recovery.test.js tests/run-lock.test.js tests/state-machine.test.js
npm test
git diff --check
git add src/controller.js src/cli.js src/state-machine.js src/state-store.js src/artifacts.js src/recovery.js src/config-snapshot.js \
  tests/controller.test.js
git commit -m "feat(factory): enforce pinned recoverable orchestration"
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

Require exact recorded workspace close, no agent-stop assumption, exact ingested outbox deletion, marked reviewer/arbiter resource deletion only, wrong nonce/unowned path refusal, idempotent missing resource, task worktree retained by default, native non-force removal on explicit request, dirty worktree refusal, branch retained, and **active-turn resource refusal**:

```js
test('cleanup refuses workspace and filesystem resource owned by active turn', async () => {
  // state.active_turn references turn_1 and run records workspace/path for turn_1
  // cleanup returns resource_in_use for both and makes no close/delete calls
});
```

- [ ] **Step 2: Write doctor RED tests**

Check Node/Git/Herdr, specialist resolved gears, concrete argv, writable roots, lock primitive, trusted-repository warning, secret stripping, safe verification fixtures, review clone origin removal, cleanup lifecycle primitives, and foreman reporting:

```text
foreman expected contract present -> configured-session-contract
no introspection -> not current-session-verified
supported introspection exact match -> current-session-verified
```

- [ ] **Step 3: Write contract RED tests**

Worker: commit-before-result, exact task worktree, no merge/deploy, exact IDs/outbox.

Reviewer: wording must say repository/Git-metadata isolation only; must not claim filesystem/process/network isolation; receives no source repo path beyond its clone context.

Arbiter: only evidence bundle, no target checkout path.

Orchestrator: exact `/execute`, `/cancel`, explicit `recover-run`, no shadow lifecycle, no inferred DONE, and foreman identity reported as expected vs verified honestly.

- [ ] **Step 4: Verify and commit**

```bash
node --test tests/cleanup.test.js tests/doctor.test.js tests/contracts.test.js
npm test
git diff --check
git add src/cleanup.js src/doctor.js src/cli.js prompts/worker.md prompts/reviewer.md prompts/arbiter.md \
  skills/mighty-factory-orchestrator/SKILL.md tests/cleanup.test.js tests/doctor.test.js tests/contracts.test.js
git commit -m "feat(factory): add truthful readiness and owned cleanup"
```

---

### Task 10: E2E regressions, README, final acceptance matrix

**Files:**
- Create: `README.md`
- Create: `tests/e2e-controller.test.js`
- Modify: `package.json`

- [ ] **Step 1: Write E2E happy-path test**

Use real temporary Git repo/state/temp root plus fake Herdr execution:

```text
valid trusted task/classification
/execute authorization
immutable config snapshot + digest
base SHA pin
persisted task resource intent then worktree reconcile
atomic worker claim + deterministic identity
WORK_DEFAULT launch
prompt_attempted persisted before prompt
worker commit then result outbox
allowed-path + Git + sanitized trusted-repo verification
post-check worktree remains clean except outbox
independent review clone plan/reconcile, no origin
REVIEW_DEFAULT PASS exact commit
DONE
```

- [ ] **Step 2: Add required E2E regression scenarios**

Same file must prove:

```text
live config mutation after /execute does not change route/gear/policy
duplicate worker dispatch launches once
crash after claim resumes same turn ID
crash after agent start adopts same deterministic agent
crash/ambiguity after prompt attempt never blindly resends
wrong stale-lock nonce cannot recover
live lock PID cannot recover
cancel before claim launches nothing
cancel after claim starts no next step
moving base_ref does not move base_sha
crash during task worktree creation reconciles same recorded path/branch
forbidden changed path fails despite passing tests
committed outbox fails
unapproved script deploy fails before execution
synthetic SUPER_SECRET_TOKEN absent from verification env
verification command dirties checkout -> FAIL on final status
committed whitespace error caught by base..commit diff-check
review clone has no source common-dir sharing and no origin
crash during review clone prep reconciles same path or blocks mismatch
reviewer arbitrary untracked file invalidates PASS
arbiter bundle contains no target_repo/task worktree path
crash during arbiter bundle prep reconciles same marked bundle
second review failure launches ORCH_ESCALATE_1 then WORK_STRONG
third failure stops at REPLAN_REQUIRED
cleanup refuses active-turn workspace/path
cleanup cannot remove wrong-nonce/unowned resource
dirty task worktree not force-removed
foreman status distinguishes configured vs current-session-verified
main branch unchanged
```

- [ ] **Step 3: Write README**

Required sections:

```text
What Mighty Factory is
Security model: trusted local repositories only; not a sandbox
Prerequisites
Immutable run config snapshot behavior
Foreman expected contract vs verified current session
Concrete specialist gear configuration and provider env allowlists
Safe verification kinds and allowed script names
PLAN and exact /execute
Cancellation point-of-no-return semantics
Crash recovery and stale-lock nonce flow
Prompt delivery ambiguity policy
Crash-safe deterministic task/reviewer/arbiter resource reconciliation
Task worktree + worker outbox
Independent reviewer clone: Git-metadata isolation only
Arbiter evidence bundle
Real escalation and three-failure cap
Owned-resource cleanup + active-turn guard + no-force policy
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

Expected: applicable commands exit 0. Doctor may return documented readiness failure only when local provider gear IDs are not filled with real installed values.

- [ ] **Step 6: Self-review canonical spec coverage**

At the same HEAD verify:

```text
trusted-repository warning, no sandbox claim
exact /execute
immutable config snapshot digest
no public generic transition
run lock + staged active_turn
explicit stale-lock recovery
prompt_attempted persisted before prompt; ambiguous delivery not blindly resent
crash-resume same logical turn
cancel_requested semantics
base_sha immutable
crash-safe deterministic task/review/arbiter resource reconciliation
allowed_paths committed-diff audit
outbox not committed; no Git ignore mutation
safe script-name verification policy
sanitized verification env
controller base..commit diff hygiene
post-verification status recheck
fresh exact specialist gear launch per turn
independent reviewer clone; origin removed; only Git-metadata isolation claimed
arbiter evidence bundle only
three-failure cap
cleanup active-turn guard + owned resource checks
DONE same verified/reviewed commit only
foreman configured-vs-verified truthfulness
no implicit merge/deploy
```

- [ ] **Step 7: Commit**

```bash
git add README.md package.json tests/e2e-controller.test.js
git commit -m "docs(factory): complete review-5 v0.1 acceptance gate"
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

May be reported only after the full local matrix passes at one HEAD, including fake-Herdr config-snapshot, resource-reconciliation, prompt-ambiguity, crash/cancel/recovery, post-verification-status, cleanup-guard, and foreman-status cases.

### `HERDR_RUNTIME_QUALIFIED`

Requires a disposable provider-backed run on the user's Mac inside Herdr proving:

```text
PLAN launches no specialist
/execute validates trusted-repo contract, snapshots config, pins base SHA
live config mutation after authorization does not alter active run
forced interruption during task worktree creation reconciles same resource
WORK_DEFAULT starts with exact configured args
forced interruption after agent launch adopts same deterministic agent
forced interruption around prompt delivery does not blindly redeliver
active-turn cancellation starts no next step
worker result is independently verified
synthetic secret is absent from verification subprocess env
verification command dirt that checkout creates blocks PASS
reviewer uses independent clone with no origin
reviewer stray file invalidates PASS
arbiter runs only from evidence bundle
second failure launches actual ORCH_ESCALATE_1 then WORK_STRONG
third failure stops
cleanup refuses active-turn resources and does not force-remove dirty worktrees
foreman identity is reported as configured vs independently verified accurately
main remains unchanged
```

Without that provider-backed smoke run, do not claim runtime qualification.
