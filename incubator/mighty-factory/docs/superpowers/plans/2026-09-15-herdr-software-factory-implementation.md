# Mighty Factory v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dependency-free local Node.js controller that lets a Luna-Max Codex foreman run bounded fresh worker/reviewer/arbiter turns through Herdr with real model/effort gear activation, pinned Git identity, durable correlated handoffs, independent verification, and no implicit merge/deploy authority.

**Architecture:** The conversational Codex agent owns planning and judgment. The Mighty Factory controller owns authority, lifecycle state, exact gear activation, turn correlation, Git worktrees, Herdr process launch, artifact ingestion, verification, escalation limits, and DONE eligibility. Worker/reviewer/arbiter specialists are fresh per turn so a gear change actually launches a different configured model/effort instead of merely changing a label.

**Tech Stack:** Node.js >= 20, ECMAScript modules, built-in `node:test`, `fs`, `path`, `child_process`, `crypto`, and native Git. No runtime dependencies in v0.1.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-15-herdr-software-factory-design.md`

## Global Constraints

- Work only inside `incubator/mighty-factory/` on branch `incubator/mighty-factory-v0`.
- Do not modify Mighty Router mainline behavior or `universal-agent-loop`.
- Use TDD for every behavior change: RED -> GREEN -> refactor.
- Node runtime remains dependency-free.
- PLAN is non-mutating; only exact `/execute` grants execution authority.
- Only exact `/cancel` cancels before the next mutation-capable transition.
- Resolve `base_ref` once to immutable `base_sha`; all verification/review uses `base_sha`.
- Every worker/reviewer/arbiter turn is fresh and records the exact launch gear/argv.
- All policy-reachable gears must have concrete `launch.resolved: true` launch specs.
- Never silently fall back to provider default model/effort for a named gear.
- Code-changing task contracts must contain authoritative verification commands.
- Terminal scrollback is diagnostic only.
- Worker/reviewer results use worktree-local outboxes and are ingested into external durable state.
- Reviewer uses a separate disposable review worktree pinned to the exact verified commit.
- Reviewer tracked-file mutation invalidates review.
- Worker-reported tests are informative only; controller-run verification is authoritative.
- No implicit merge, deploy, production mutation, credential mutation, billing action, permission approval, reset, stash, or clean of unrelated user state.
- Run all subprocesses with argv arrays; no user-controlled shell interpolation.

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
    route.js
    config.js
    command-runner.js
    provider-adapters/
      index.js
      codex.js
      cline.js
      antigravity.js
    state-machine.js
    state-store.js
    artifacts.js
    git.js
    verifier.js
    herdr.js
    turn-launcher.js
    prepare-run.js
    controller.js
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
    task-contract.test.js
    classify-schema.test.js
    route.test.js
    config.test.js
    provider-adapters.test.js
    ids.test.js
    state-machine.test.js
    state-store.test.js
    artifacts.test.js
    git.test.js
    verifier.test.js
    herdr.test.js
    turn-launcher.test.js
    prepare-run.test.js
    controller.test.js
    doctor.test.js
    contracts.test.js
    e2e-controller.test.js
```

---

## Task 1: Scaffold CLI, task-contract validation, and explicit command surface

**Files:**
- Create: `package.json`
- Create: `bin/mighty-factory.js`
- Create: `src/cli.js`
- Create: `src/errors.js`
- Create: `src/task-contract.js`
- Create: `src/classify-schema.js`
- Create: `tests/cli.test.js`
- Create: `tests/task-contract.test.js`
- Create: `tests/classify-schema.test.js`

**Interfaces:**
- `main(argv, io = { stdout: process.stdout, stderr: process.stderr }) -> Promise<number>`
- `validateTaskContract(value) -> normalizedContract`
- `validateClassification(value) -> normalizedClassification`
- Exit codes: `0` success, `1` operational failure, `2` usage error.

- [ ] **Step 1: Write failing CLI surface test**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const bin = path.join(root, 'bin', 'mighty-factory.js');

const required = [
  'doctor', 'print-config', 'route', 'prepare-run',
  'dispatch-worker', 'verify-worker',
  'dispatch-reviewer', 'verify-review',
  'dispatch-arbiter', 'record-repair', 'transition', 'status'
];

test('help exposes every controller operation used by the orchestrator skill', () => {
  const r = spawnSync(process.execPath, [bin, 'help'], { encoding: 'utf8' });
  assert.equal(r.status, 0);
  for (const command of required) assert.match(r.stdout, new RegExp(`mighty-factory ${command}`));
});

test('unknown command exits 2', () => {
  const r = spawnSync(process.execPath, [bin, 'wat'], { encoding: 'utf8' });
  assert.equal(r.status, 2);
});
```

- [ ] **Step 2: Write failing task-contract tests**

```js
import test from 'node:test';
import assert from 'node:assert/strict';
import { validateTaskContract } from '../src/task-contract.js';

const base = {
  schema_version: 1,
  summary: 'Add feature',
  target_repo: '/tmp/repo',
  base_ref: 'main',
  allowed_paths: ['src/', 'tests/'],
  allow_noop: false,
  verification: {
    policy: 'repo-checks-required',
    commands: [
      { command: 'npm', args: ['test'] },
      { command: 'git', args: ['diff', '--check'] }
    ]
  }
};

test('accepts code task with repo-specific verification', () => {
  assert.equal(validateTaskContract(base, { change_kind: 'feature' }).summary, 'Add feature');
});

test('rejects empty verification for code changes', () => {
  assert.throws(() => validateTaskContract({
    ...base,
    verification: { policy: 'repo-checks-required', commands: [] }
  }, { change_kind: 'feature' }), /verification/i);
});

test('rejects code task whose only check is git diff --check', () => {
  assert.throws(() => validateTaskContract({
    ...base,
    verification: { policy: 'repo-checks-required', commands: [
      { command: 'git', args: ['diff', '--check'] }
    ] }
  }, { change_kind: 'bugfix' }), /repository-specific/i);
});
```

- [ ] **Step 3: Write failing classification tests**

Validate the exact spec enums and `confidence` range 0..1. Reject missing/extra invalid values without coercion.

- [ ] **Step 4: Run RED**

```bash
cd incubator/mighty-factory
node --test tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
```

Expected: FAIL because modules do not exist.

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

`src/errors.js` exports `UsageError` and `OperationalError(code, message, details)`.

`src/cli.js` must use this literal default:

```js
export async function main(
  argv,
  io = { stdout: process.stdout, stderr: process.stderr }
) { /* command dispatch */ }
```

No bare undefined `stdout` or `stderr` identifiers.

Reserve all required command names immediately. Unimplemented reserved commands return `OperationalError('not_implemented', ...)`, not usage error.

- [ ] **Step 6: Verify GREEN and commit**

```bash
node --test tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
npm test
git diff --check
git add incubator/mighty-factory
git commit -m "feat(factory): scaffold command and task contracts"
```

---

## Task 2: Implement resolved gears, provider adapters, and deterministic routing

**Files:**
- Create: `factory.config.example.json`
- Create: `src/config.js`
- Create: `src/route.js`
- Create: `src/provider-adapters/index.js`
- Create: `src/provider-adapters/codex.js`
- Create: `src/provider-adapters/cline.js`
- Create: `src/provider-adapters/antigravity.js`
- Create: `tests/config.test.js`
- Create: `tests/route.test.js`
- Create: `tests/provider-adapters.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `loadConfig(path) -> validatedConfig`
- `routeTask({ classification, state, config }) -> { action, orchestratorGear, workerGear, reviewerGear }`
- `buildLaunchSpec(adapterName, gear, context) -> { herdrKind, argv, env, artifactTransport }`

Required reachable gears:

```text
ORCH_DEFAULT ORCH_ESCALATE_1 WORK_DEFAULT WORK_STRONG REVIEW_DEFAULT REVIEW_STRONG
```

- [ ] **Step 1: Write failing config tests**

Test rejection for:

```text
missing any reachable gear
launch.resolved !== true
empty model_args for reachable model-bearing gear
empty effort_args for reachable effort-bearing gear
ORCH_DEFAULT effort !== max
unknown provider_adapter
confidence_threshold outside 0..1
relative state_root after ~ expansion
```

Example valid gear fixture:

```js
{
  provider_adapter: 'codex',
  herdr_kind: 'codex',
  model_alias: 'luna',
  effort: 'max',
  launch: {
    resolved: true,
    model_args: ['--model', 'gpt-example-luna'],
    effort_args: ['--config', 'model_reasoning_effort=max'],
    extra_args: []
  }
}
```

- [ ] **Step 2: Write failing adapter test proving labels cannot lie**

```js
test('resolved gear emits concrete model and effort argv', () => {
  const spec = buildLaunchSpec('codex', gear, {});
  assert.deepEqual(spec.argv, [
    '--model', 'gpt-example-luna',
    '--config', 'model_reasoning_effort=max'
  ]);
});

test('unresolved gear fails closed', () => {
  assert.throws(() => buildLaunchSpec('codex', {
    ...gear, launch: { ...gear.launch, resolved: false }
  }, {}), /unresolved/i);
});
```

- [ ] **Step 3: Write failing route tests**

```js
const normal = {
  scope: 'normal', risk: 'medium', ambiguity: 'low',
  change_kind: 'feature', cross_cutting: false, confidence: 0.9
};

test('normal route selects default gears', () => {
  const r = routeTask({ classification: normal, state: { phase: 'READY', material_failures: 0, plan_confirmed: true }, config });
  assert.equal(r.workerGear, 'WORK_DEFAULT');
  assert.equal(r.reviewerGear, 'REVIEW_DEFAULT');
});

test('second material failure selects real strong worker and arbiter path', () => {
  const r = routeTask({ classification: normal, state: { phase: 'ESCALATION_PENDING', material_failures: 2, plan_confirmed: true }, config });
  assert.equal(r.orchestratorGear, 'ORCH_ESCALATE_1');
  assert.equal(r.workerGear, 'WORK_STRONG');
  assert.equal(r.action, 'require_arbiter');
});
```

- [ ] **Step 4: Run RED, implement, wire `route`/`print-config`, verify GREEN**

```bash
node --test tests/config.test.js tests/provider-adapters.test.js tests/route.test.js
npm test
git diff --check
git commit -am "feat(factory): add resolved gear routing"
```

The example config must use obviously synthetic provider IDs and explain that the user must replace them with locally confirmed CLI model IDs before `doctor` passes execution readiness.

---

## Task 3: Implement IDs, durable state, and bounded lifecycle

**Files:**
- Create: `src/ids.js`
- Create: `src/state-machine.js`
- Create: `src/state-store.js`
- Create: `tests/ids.test.js`
- Create: `tests/state-machine.test.js`
- Create: `tests/state-store.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `createId('run'|'task'|'turn') -> prefix_<32 hex>`
- `transition(state, event, payload) -> nextState`
- `createStateStore(root) -> { initRun, readRun, readState, writeState, appendEvent, turnDir }`

- [ ] **Step 1: Write failing state-machine tests**

```js
const base = {
  phase: 'PLAN', material_failures: 0,
  verification_stale: false, review_stale: false
};

test('PLAN requires valid explicit execute', () => {
  assert.equal(transition(base, 'human_execute', { contract_valid: true }).phase, 'READY');
  assert.throws(() => transition(base, 'human_execute', { contract_valid: false }), /illegal_transition/);
});

test('review failures are bounded', () => {
  const one = transition({ ...base, phase: 'VERIFYING_REVIEW' }, 'review_failed');
  const two = transition({ ...one, phase: 'VERIFYING_REVIEW' }, 'review_failed');
  const three = transition({ ...two, phase: 'VERIFYING_REVIEW' }, 'review_failed');
  assert.equal(one.phase, 'REPAIR_PENDING');
  assert.equal(two.phase, 'ESCALATION_PENDING');
  assert.equal(three.phase, 'REPLAN_REQUIRED');
});

test('repair dispatch invalidates old evidence', () => {
  const next = transition({ ...base, phase: 'REPAIR_PENDING', verification_stale: false, review_stale: false }, 'repair_ticket_accepted');
  assert.equal(next.phase, 'WORKING');
  assert.equal(next.verification_stale, true);
  assert.equal(next.review_stale, true);
});
```

- [ ] **Step 2: Write atomic state-store tests using `fs.mkdtemp`**

Require `run.json`, `task.json`, `classification.json`, `state.json`, `events.jsonl`, and `turns/`. State writes use temp-file + rename.

- [ ] **Step 3: Run RED, implement exact legal transitions, wire `transition`/`status`, verify GREEN**

```bash
node --test tests/ids.test.js tests/state-machine.test.js tests/state-store.test.js
npm test
git diff --check
git commit -am "feat(factory): persist bounded controller state"
```

---

## Task 4: Implement pinned Git identity, outbox transport, and correlated artifacts

**Files:**
- Create: `src/git.js`
- Create: `src/artifacts.js`
- Create: `tests/git.test.js`
- Create: `tests/artifacts.test.js`

**Interfaces:**
- `resolveBaseSha(repo, baseRef, runner) -> sha`
- `createTaskWorktree({ repo, baseSha, branch, path }, runner)`
- `createReviewWorktree({ repo, commit, path }, runner)`
- `ensureOutboxExcluded(worktree, runner)`
- `getOutboxResultPath(worktree, turnId, role) -> absolute path`
- `ingestResult({ sourcePath, destinationPath, expected }) -> { artifact, sha256 }`
- `assertCorrelation(artifact, expected)`

- [ ] **Step 1: Write real-temp-repo test proving base ref is pinned**

Create `main` at commit A, call `resolveBaseSha`, advance `main` to B, and assert stored `baseSha === A` is still used for subsequent worktree creation and diff verification.

- [ ] **Step 2: Write outbox test using `git rev-parse --git-path info/exclude`**

Assert `.mighty-factory-outbox/` becomes locally ignored without modifying tracked `.gitignore`.

- [ ] **Step 3: Write correlation tests**

Accept only exact `schema_version`, `run_id`, `task_id`, `turn_id`, role, and expected commit. Reject stale turn IDs and mismatched commits.

- [ ] **Step 4: Implement worker/reviewer/arbiter schemas**

Worker `implemented` requires `commit`, `summary`, `reported_tests`, `known_limitations`.

Reviewer requires `reviewed_commit`, `PASS|FAIL`, findings, evidence, confidence.

Arbiter requires `decision`, `repair_strategy`, confidence.

- [ ] **Step 5: Run/commit**

```bash
node --test tests/git.test.js tests/artifacts.test.js
npm test
git diff --check
git commit -am "feat(factory): pin git identity and ingest outbox artifacts"
```

---

## Task 5: Implement authoritative verification from the task contract

**Files:**
- Create: `src/command-runner.js`
- Create: `src/verifier.js`
- Create: `tests/verifier.test.js`

**Interfaces:**
- `runCommand(command, args, options) -> { exitCode, stdout, stderr }`
- `verifyWorker({ run, task, turn, reportedCommit }, deps) -> verificationArtifact`

- [ ] **Step 1: Write failing test proving worker-reported PASS cannot satisfy verification**

Use a real temp Git repo and injected command runner. Worker result claims `npm test` passed; controller runner returns exit 1. Expected verification result is `fail`.

- [ ] **Step 2: Write failing test proving task.json commands are authoritative**

```js
const task = {
  verification: {
    policy: 'repo-checks-required',
    commands: [
      { command: 'npm', args: ['test'] },
      { command: 'git', args: ['diff', '--check'] }
    ]
  }
};
```

Assert both commands execute in the task worktree and exact exit codes are recorded.

- [ ] **Step 3: Implement verification**

Verification must check:

```text
reported commit exists
HEAD == reported commit
base_sha is ancestor
base-to-head diff nonempty unless allow_noop
worktree tracked/untracked policy
all authoritative task commands run independently
```

Persist at most 16 KiB stdout/stderr tails per command.

- [ ] **Step 4: Verify/commit**

```bash
node --test tests/verifier.test.js tests/git.test.js
npm test
git diff --check
git commit -am "feat(factory): verify exact worker commits independently"
```

---

## Task 6: Implement Herdr wrapper and fresh per-turn launch

**Files:**
- Create: `src/herdr.js`
- Create: `src/turn-launcher.js`
- Create: `tests/herdr.test.js`
- Create: `tests/turn-launcher.test.js`

**Interfaces:**
- `createHerdrClient(runner)` with `workspaceCreate`, `paneSplit`, `agentStart`, `agentGet`, `agentPrompt`, `agentWait`, `agentRead`.
- `launchFreshTurn({ role, gearName, cwd, prompt, resultPath, run }, deps) -> launchRecord`

- [ ] **Step 1: Write Herdr JSON parsing tests**

Fixtures are synthetic. Parse returned workspace/root pane/agent IDs. `blocked` throws immediately. `working` requires settle wait. `unknown` is not success.

- [ ] **Step 2: Write gear-activation regression test**

Launch worker turn 1 with `WORK_DEFAULT`, then worker turn 2 with `WORK_STRONG`.

Assert two distinct `agent start` calls contain the two distinct concrete launch argv arrays and distinct agent names/turn IDs. This test exists specifically to prevent “gear label changed but process did not.”

- [ ] **Step 3: Write arbiter launch test**

When `ORCH_ESCALATE_1` is selected, assert a fresh Codex process is launched with that gear's concrete argv. It must not reuse or relabel the human-facing Luna session.

- [ ] **Step 4: Implement fresh-turn naming**

Use deterministic names derived from run/turn, e.g.:

```text
mf-worker-<runSuffix>-<turnSuffix>
mf-reviewer-<runSuffix>-<turnSuffix>
mf-arbiter-<runSuffix>-<turnSuffix>
```

Create a fresh Herdr workspace/pane rooted at the supplied cwd for each turn. Persist actual gear + argv in `turns/<turn_id>/launch.json`.

- [ ] **Step 5: Handle timeout/stall safely**

On timeout/stall, inspect expected result path and agent status. Never blindly resend unless no result exists and duplicate-turn safety is proven.

- [ ] **Step 6: Verify/commit**

```bash
node --test tests/herdr.test.js tests/turn-launcher.test.js
npm test
git diff --check
git commit -am "feat(factory): launch fresh Herdr agents per gear turn"
```

---

## Task 7: Implement run preparation and separate review worktrees

**Files:**
- Create: `src/prepare-run.js`
- Create: `tests/prepare-run.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `prepareRun({ task, classification, config }, deps) -> runRecord`
- Preparation creates task worktree but **does not** prelaunch worker/reviewer models.

- [ ] **Step 1: Write failing preparation test**

Assert:

```text
base_ref resolved once to base_sha
task worktree created from base_sha
outbox ignored locally
run.json stores base_ref + base_sha + worktree path
no agent start occurs during preparation
state ends WORKING-ready only after provisioning metadata is durable
```

Use a real temp Git repo plus fake Herdr client.

- [ ] **Step 2: Implement native Git worktree creation**

Use argv-array Git commands:

```text
git -C <repo> rev-parse <base_ref>^{commit}
git -C <repo> worktree add -b <task_branch> <task_path> <base_sha>
```

For reviewer later:

```text
git -C <repo> worktree add --detach <review_path> <verified_commit>
```

This avoids depending on undocumented Herdr worktree argv while Herdr still owns agent workspaces/panes/processes.

- [ ] **Step 3: Wire `prepare-run` CLI and verify/commit**

```bash
node --test tests/prepare-run.test.js
npm test
git diff --check
git commit -am "feat(factory): prepare pinned isolated task runs"
```

---

## Task 8: Implement controller dispatch, review, repair, and real escalation

**Files:**
- Create: `src/controller.js`
- Create: `tests/controller.test.js`
- Modify: `src/cli.js`
- Modify: `src/state-machine.js`

**Interfaces:**
- `createController(deps)` with:
  - `prepareRun`
  - `dispatchWorker`
  - `verifyWorker`
  - `dispatchReviewer`
  - `verifyReview`
  - `dispatchArbiter`
  - `recordRepair`
  - `transition`
  - `status`

- [ ] **Step 1: Write happy-path controller test**

Scenario:

```text
PLAN -> /execute -> READY
prepare -> task worktree pinned at base_sha
fresh WORK_DEFAULT worker -> commit C1 -> correlated outbox
controller verification C1 passes
separate review worktree pinned C1
fresh REVIEW_DEFAULT reviewer -> PASS C1
tracked review worktree unchanged
DONE
```

Assert worker and reviewer have distinct turn IDs and launch records.

- [ ] **Step 2: Write stale-artifact test**

An old turn result with the correct run/task but previous `turn_id` cannot advance state.

- [ ] **Step 3: Write reviewer-mutation test**

Reviewer may write designated ignored outbox only. Any tracked file change or HEAD change rejects PASS and prevents DONE.

- [ ] **Step 4: Write real escalation test**

Sequence two material review failures. Assert:

```text
state == ESCALATION_PENDING
controller launches fresh ORCH_ESCALATE_1 arbiter
arbiter result is correlated and ingested
next worker launch uses WORK_STRONG concrete argv
old WORK_DEFAULT agent is not reused as the strong turn
```

Third material failure -> `REPLAN_REQUIRED`; a fourth automatic dispatch throws.

- [ ] **Step 5: Implement CLI commands that were previously missing**

Exact commands:

```text
mighty-factory dispatch-worker --run <id>
mighty-factory verify-worker --run <id> --turn <id>
mighty-factory dispatch-reviewer --run <id>
mighty-factory verify-review --run <id> --turn <id>
mighty-factory dispatch-arbiter --run <id>
mighty-factory record-repair --run <id> --file <repair.json>
```

Each prints exactly one structured JSON object on success.

- [ ] **Step 6: Verify/commit**

```bash
node --test tests/controller.test.js tests/state-machine.test.js
npm test
git diff --check
git commit -am "feat(factory): enforce dispatch review and escalation loop"
```

---

## Task 9: Add doctor and agent contracts

**Files:**
- Create: `src/doctor.js`
- Create: `tests/doctor.test.js`
- Create: `prompts/worker.md`
- Create: `prompts/reviewer.md`
- Create: `prompts/arbiter.md`
- Create: `skills/mighty-factory-orchestrator/SKILL.md`
- Create: `tests/contracts.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `runDoctor({ configPath, env }, deps) -> { ok, checks[] }`

- [ ] **Step 1: Write doctor tests**

Require checks for:

```text
Node >= 20
Git executable
Herdr executable/server
config parse
all six reachable gears exist
all six launch.resolved true
adapter can build concrete nonempty model/effort argv for all gears
state root controller-writable
outbox can be prepared in disposable Git worktree
```

If provider model introspection is unavailable, check message must say `configured-not-provider-validated`, never `validated`.

- [ ] **Step 2: Write static contract tests**

Worker prompt must contain `RUN_ID`, `TASK_ID`, `TURN_ID`, `EXPECTED_RESULT_PATH`, exact worktree boundary, commit requirement, and no merge/deploy.

Reviewer prompt must contain exact `BASE_SHA`, `VERIFIED_COMMIT`, separate review-worktree read-only tracked-file rule, PASS/FAIL artifact, and no repair.

Arbiter prompt must contain exact escalation question, prior evidence references, correlated result, and no code mutation.

Orchestrator skill must contain exact `/execute`, `/cancel`, controller owns lifecycle, fresh-turn gear activation, and never infer DONE.

- [ ] **Step 3: Implement doctor and contracts, wire `doctor`, verify/commit**

```bash
node --test tests/doctor.test.js tests/contracts.test.js
npm test
git diff --check
git commit -am "feat(factory): add readiness doctor and role contracts"
```

---

## Task 10: End-to-end fixture loop, README, and runtime qualification gate

**Files:**
- Create: `README.md`
- Create: `tests/e2e-controller.test.js`
- Modify: `package.json`

- [ ] **Step 1: Write failing E2E happy-path test**

Use real temporary Git repo/state plus fake Herdr provider processes. Exercise:

```text
valid task + classification
human_execute
base_sha pin
prepare task worktree
WORK_DEFAULT launch args recorded
worker C1 outbox ingested
controller task verification commands execute and pass
review worktree detached at C1
REVIEW_DEFAULT launch
review PASS C1 ingested
review tracked state unchanged
DONE
```

- [ ] **Step 2: Add E2E regression scenarios**

Same file must prove:

```text
stale turn rejected
moving base_ref after prepare does not alter base_sha
empty code-task verification rejected before execute
unresolved gear rejected before launch
second review failure launches ORCH_ESCALATE_1 then WORK_STRONG with different argv
reviewer tracked mutation blocks DONE
third review failure stops at REPLAN_REQUIRED
```

- [ ] **Step 3: Write README**

Document:

```text
what Factory does / does not do
Node/Git/Herdr prerequisites
how to copy example config
how to fill exact installed provider model + effort args
why unresolved gears fail closed
PLAN and exact /execute
fresh per-turn specialist model behavior
worker outbox -> controller verification -> separate reviewer worktree
real escalation via arbiter + strong worker
three-failure cap
state artifact location
no automatic merge/deploy
```

Include a Mermaid architecture diagram.

- [ ] **Step 4: Package scripts**

```json
{
  "scripts": {
    "test": "node --test tests/*.test.js",
    "test:e2e": "node --test tests/e2e-controller.test.js",
    "doctor": "node bin/mighty-factory.js doctor"
  }
}
```

- [ ] **Step 5: Run full verification matrix**

```bash
cd incubator/mighty-factory
npm test
npm run test:e2e
git diff --check
node bin/mighty-factory.js help
```

Expected: all exit 0.

- [ ] **Step 6: Self-review against canonical spec**

Explicitly verify every item:

```text
exact /execute
valid task contract required
base_sha pinned
six reachable gears required + resolved
fresh worker/reviewer/arbiter launch per turn
real ORCH_ESCALATE_1 and WORK_STRONG activation
outbox ingestion
separate review worktree
correlation IDs
independent task-command verification
reviewer tracked immutability
stale-evidence invalidation
three-failure cap
no hidden CLI controller method unreachable by the skill
DONE same verified/reviewed commit only
no implicit merge/deploy
```

Any missing item blocks completion.

- [ ] **Step 7: Commit**

```bash
git add incubator/mighty-factory
git commit -m "docs(factory): complete v0.1 operator workflow and e2e gate"
```

---

## Execution and Review Gates

Execute Tasks 1-10 in order. After each task:

1. run focused tests and observe GREEN,
2. run `npm test`,
3. run `git diff --check`,
4. inspect changed files,
5. commit only that task,
6. request a fresh independent code review before starting the next task.

Do not batch tasks together.

## Final Local Acceptance Gate

Before claiming code-complete at one implementation HEAD:

```bash
cd incubator/mighty-factory
npm test
npm run test:e2e
git diff --check
node bin/mighty-factory.js help
node bin/mighty-factory.js doctor --config ./factory.config.json
```

No completion claim without fresh output from all applicable commands.

## Provider-Backed HERDR_RUNTIME_QUALIFIED Gate

Unit/integration completion is not runtime qualification.

On the user's Mac inside Herdr, use a disposable repository and a harmless one-file task. Fresh evidence must prove:

```text
PLAN does not spawn specialists
/execute pins base_sha and prepares isolated task worktree
WORK_DEFAULT actually launches the configured default worker model/effort
worker result arrives through outbox and is correlated
controller independently reruns task verification commands
reviewer runs in separate worktree on exact verified commit
REVIEW_DEFAULT/REVIEW_STRONG launch args match selected gear
reviewer does not change tracked files
forced two-failure scenario launches actual ORCH_ESCALATE_1 arbiter
next worker turn launches actual WORK_STRONG argv, not the old default agent
third failure stops at REPLAN_REQUIRED
main branch remains unchanged
```

If this provider-backed smoke run is skipped, report `UNIT_INTEGRATION_COMPLETE` at most; do not claim `HERDR_RUNTIME_QUALIFIED`.
