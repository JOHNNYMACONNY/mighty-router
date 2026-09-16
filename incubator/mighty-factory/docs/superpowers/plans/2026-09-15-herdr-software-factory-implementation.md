# Mighty Factory v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dependency-free local Node.js controller that lets a Codex orchestrator run a bounded Herdr worker/reviewer loop with deterministic routing, durable state, unique turn correlation, independent verification, and no implicit merge/deploy authority.

**Architecture:** The conversational Codex agent owns planning and judgment; the Mighty Factory controller owns lifecycle state, correlation IDs, routing, Herdr provisioning, artifact validation, Git verification, retry limits, and completion eligibility. Herdr remains the terminal/process transport. Antigravity is the default worker role, Cline is the default reviewer role, and provider/model/effort details are isolated behind configurable launch adapters.

**Tech Stack:** Node.js >= 20, ECMAScript modules, built-in `node:test`, built-in `fs`, `path`, `child_process`, `crypto`; no runtime dependencies in v0.1.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-15-herdr-software-factory-design.md`

## Global Constraints

- Work only inside `incubator/mighty-factory/` on branch `incubator/mighty-factory-v0` until the project is deliberately extracted.
- Do not modify `mighty-router` mainline behavior or `universal-agent-loop`.
- Node runtime must remain dependency-free in v0.1.
- Use `node:test` and TDD for every behavior change.
- PLAN mode is non-mutating; only exact `/execute` grants execution authority in v0.1.
- `/cancel` prevents the next mutation-capable transition.
- Controller code, not model memory, owns lifecycle transitions, retry counts, stale-evidence invalidation, and DONE eligibility.
- Terminal scrollback is diagnostic only; structured handoffs live under the configured run-state root.
- Worker and reviewer results must echo controller-generated `run_id`, `task_id`, and `turn_id`.
- Reviewer is logically read-only; detected reviewer mutation invalidates the review.
- Worker-reported tests are informative only; controller-run verification commands are authoritative.
- No implicit merge to main, deploy, production mutation, credential mutation, billing action, or permission-dialog approval.
- Herdr creation commands return JSON; parse returned IDs rather than predicting workspace/pane IDs.
- Do not intentionally prompt a Herdr agent while it is `working`; `blocked` and `unknown` never count as successful completion.
- A timeout or `agent_prompt_stalled` does not prove input was not delivered; inspect state/artifacts before any retry.

---

## File Structure

Create the following focused units:

```text
incubator/mighty-factory/
  README.md                         user-facing setup and workflow
  package.json                      Node/ESM metadata and scripts
  factory.config.example.json       editable gear/provider/verification config
  bin/
    mighty-factory.js               CLI entrypoint only
  src/
    cli.js                          argv parsing and command dispatch
    errors.js                       typed operational errors / exit mapping
    ids.js                          run/task/turn ID generation
    classify-schema.js              task-classification validation
    route.js                        deterministic gear routing
    state-machine.js                legal lifecycle transitions
    state-store.js                  atomic durable state read/write
    artifacts.js                    request/result schemas and artifact IO
    config.js                       config loading and validation
    command-runner.js               injectable subprocess primitive
    provider-adapters/
      index.js                      adapter registry
      codex.js                      Codex launch-spec construction
      cline.js                      Cline launch-spec construction
      antigravity.js                Antigravity launch-spec construction
    herdr.js                        Herdr CLI wrapper + response parsing
    prepare-run.js                  worktree/workspace/pane/agent provisioning
    git-verify.js                   Git identity / ancestry / cleanliness checks
    verifier.js                     authoritative verification command execution
    controller.js                   orchestration-state operations used by CLI/skill
    doctor.js                       non-mutating environment validation
  prompts/
    worker.md                       bounded worker contract
    reviewer.md                     adversarial read-only review contract
  skills/
    mighty-factory-orchestrator/
      SKILL.md                      PLAN/EXECUTE integration contract
  tests/
    cli.test.js
    ids.test.js
    classify-schema.test.js
    route.test.js
    state-machine.test.js
    state-store.test.js
    artifacts.test.js
    config.test.js
    provider-adapters.test.js
    herdr.test.js
    prepare-run.test.js
    git-verify.test.js
    verifier.test.js
    controller.test.js
    doctor.test.js
    fixtures/
      herdr/
        workspace-create.json
        pane-split.json
        agent-idle.json
        agent-working.json
        agent-blocked.json
```

---

### Task 1: Scaffold the executable package and CLI boundary

**Files:**
- Create: `incubator/mighty-factory/package.json`
- Create: `incubator/mighty-factory/bin/mighty-factory.js`
- Create: `incubator/mighty-factory/src/cli.js`
- Create: `incubator/mighty-factory/src/errors.js`
- Create: `incubator/mighty-factory/tests/cli.test.js`

**Interfaces:**
- Produces: `main(argv, io) -> Promise<number>` in `src/cli.js`.
- Produces: CLI commands `help`, `doctor`, `print-config`, `route`, `prepare-run`, `transition`, `verify-worker`, `verify-review`, `status` as recognized command names; non-help commands may initially return a deterministic “not implemented” operational error until their task lands.
- Produces: process exit codes `0` success, `1` operational failure, `2` CLI usage error.

- [ ] **Step 1: Write the failing CLI smoke test**

```js
// tests/cli.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const bin = path.join(root, 'bin', 'mighty-factory.js');

test('help prints the v0.1 command surface', () => {
  const result = spawnSync(process.execPath, [bin, 'help'], { encoding: 'utf8' });
  assert.equal(result.status, 0);
  assert.match(result.stdout, /mighty-factory doctor/);
  assert.match(result.stdout, /mighty-factory prepare-run/);
  assert.match(result.stdout, /mighty-factory transition/);
  assert.match(result.stdout, /mighty-factory verify-worker/);
});

test('unknown command exits with usage error', () => {
  const result = spawnSync(process.execPath, [bin, 'wat'], { encoding: 'utf8' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Unknown command: wat/);
});
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```bash
cd incubator/mighty-factory
node --test tests/cli.test.js
```

Expected: FAIL because `bin/mighty-factory.js` does not exist.

- [ ] **Step 3: Add minimal package metadata and CLI implementation**

`package.json`:

```json
{
  "name": "mighty-factory",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "bin": {
    "mighty-factory": "./bin/mighty-factory.js"
  },
  "engines": {
    "node": ">=20"
  },
  "scripts": {
    "test": "node --test tests/*.test.js"
  }
}
```

`src/errors.js`:

```js
export class UsageError extends Error {
  constructor(message) {
    super(message);
    this.name = 'UsageError';
  }
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

`src/cli.js` must expose `main(argv, io = { stdout, stderr })`, print a fixed usage block for `help`, throw/handle `UsageError` for unknown commands, and reserve all v0.1 command names.

`bin/mighty-factory.js` must be a thin executable wrapper with a shebang, call `main(process.argv.slice(2))`, and set `process.exitCode` from the returned integer.

- [ ] **Step 4: Run the focused test and full suite**

```bash
node --test tests/cli.test.js
npm test
```

Expected: PASS, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add incubator/mighty-factory/package.json \
        incubator/mighty-factory/bin/mighty-factory.js \
        incubator/mighty-factory/src/cli.js \
        incubator/mighty-factory/src/errors.js \
        incubator/mighty-factory/tests/cli.test.js
git commit -m "feat(factory): scaffold deterministic CLI"
```

---

### Task 2: Add classification validation and deterministic gear routing

**Files:**
- Create: `incubator/mighty-factory/src/classify-schema.js`
- Create: `incubator/mighty-factory/src/route.js`
- Create: `incubator/mighty-factory/tests/classify-schema.test.js`
- Create: `incubator/mighty-factory/tests/route.test.js`
- Modify: `incubator/mighty-factory/src/cli.js`

**Interfaces:**
- Produces: `validateClassification(value) -> normalizedClassification` or throws `OperationalError('invalid_classification', ...)`.
- Produces: `routeTask({ classification, state, config }) -> { orchestratorGear, workerGear, reviewerGear, action }`.
- `action` is one of `plan_only | execute | require_plan | require_clarification | replan`.

- [ ] **Step 1: Write failing classification tests**

```js
// tests/classify-schema.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { validateClassification } from '../src/classify-schema.js';

test('accepts the v0.1 classification contract', () => {
  const value = validateClassification({
    scope: 'normal',
    risk: 'medium',
    ambiguity: 'low',
    change_kind: 'feature',
    cross_cutting: false,
    confidence: 0.89
  });
  assert.equal(value.scope, 'normal');
  assert.equal(value.confidence, 0.89);
});

test('rejects confidence outside 0..1', () => {
  assert.throws(() => validateClassification({
    scope: 'normal', risk: 'medium', ambiguity: 'low',
    change_kind: 'feature', cross_cutting: false, confidence: 1.2
  }), /confidence/);
});
```

- [ ] **Step 2: Write failing route tests**

```js
// tests/route.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { routeTask } from '../src/route.js';

const config = { confidence_threshold: 0.75 };
const normal = {
  scope: 'normal', risk: 'medium', ambiguity: 'low',
  change_kind: 'feature', cross_cutting: false, confidence: 0.9
};

test('normal implementation uses default gears', () => {
  assert.deepEqual(routeTask({ classification: normal, state: { phase: 'READY', material_failures: 0 }, config }), {
    orchestratorGear: 'ORCH_DEFAULT',
    workerGear: 'WORK_DEFAULT',
    reviewerGear: 'REVIEW_DEFAULT',
    action: 'execute'
  });
});

test('high risk forces strong review', () => {
  const result = routeTask({ classification: { ...normal, risk: 'high' }, state: { phase: 'READY', material_failures: 0 }, config });
  assert.equal(result.reviewerGear, 'REVIEW_STRONG');
});

test('low confidence blocks mutation', () => {
  const result = routeTask({ classification: { ...normal, confidence: 0.5 }, state: { phase: 'READY', material_failures: 0 }, config });
  assert.equal(result.action, 'require_clarification');
});

test('third material failure requires replan', () => {
  const result = routeTask({ classification: normal, state: { phase: 'REPLAN_REQUIRED', material_failures: 3 }, config });
  assert.equal(result.action, 'replan');
});
```

- [ ] **Step 3: Run both files and confirm RED**

```bash
node --test tests/classify-schema.test.js tests/route.test.js
```

Expected: FAIL because modules are absent.

- [ ] **Step 4: Implement minimal validators and routing rules**

`validateClassification` must allow only:

```text
scope: tiny | normal | broad | architectural
risk: low | medium | high
ambiguity: low | medium | high
change_kind: question | docs | bugfix | feature | refactor | migration | security
cross_cutting: boolean
confidence: finite number 0..1
```

`routeTask` rules, in order:

```text
phase PLAN -> plan_only
phase REPLAN_REQUIRED -> replan
confidence < threshold OR ambiguity high -> require_clarification
scope broad/architectural AND state.plan_confirmed !== true -> require_plan
otherwise defaults: ORCH_DEFAULT / WORK_DEFAULT / REVIEW_DEFAULT / execute
risk high -> REVIEW_STRONG
material_failures >= 2 -> WORK_STRONG plus ORCH_ESCALATE_1 if config exposes both
```

Do not add probabilistic routing or token-price logic.

- [ ] **Step 5: Wire `mighty-factory route` to JSON input**

CLI syntax:

```bash
mighty-factory route --classification '<json>' --state '<json>' --config <path>
```

It prints exactly one JSON object to stdout and no prose on success.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/classify-schema.test.js tests/route.test.js tests/cli.test.js
npm test
git add incubator/mighty-factory/src/classify-schema.js \
        incubator/mighty-factory/src/route.js \
        incubator/mighty-factory/src/cli.js \
        incubator/mighty-factory/tests/classify-schema.test.js \
        incubator/mighty-factory/tests/route.test.js
git commit -m "feat(factory): add deterministic task routing"
```

---

### Task 3: Implement IDs, durable state, and the legal lifecycle state machine

**Files:**
- Create: `incubator/mighty-factory/src/ids.js`
- Create: `incubator/mighty-factory/src/state-machine.js`
- Create: `incubator/mighty-factory/src/state-store.js`
- Create: `incubator/mighty-factory/tests/ids.test.js`
- Create: `incubator/mighty-factory/tests/state-machine.test.js`
- Create: `incubator/mighty-factory/tests/state-store.test.js`
- Modify: `incubator/mighty-factory/src/cli.js`

**Interfaces:**
- Produces: `createId(prefix) -> string`, restricted to prefixes `run`, `task`, `turn`.
- Produces: `transition(state, event, payload = {}) -> nextState`; illegal transitions throw `OperationalError('illegal_transition', ...)`.
- Produces: `createStateStore(root)` with `initRun`, `readState`, `writeState`, `appendEvent`.
- State writes are atomic using temp-file + rename.

- [ ] **Step 1: Write failing ID and state-machine tests**

```js
// tests/ids.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { createId } from '../src/ids.js';

test('creates opaque role-prefixed IDs', () => {
  assert.match(createId('run'), /^run_[0-9a-f]{32}$/);
  assert.match(createId('task'), /^task_[0-9a-f]{32}$/);
  assert.match(createId('turn'), /^turn_[0-9a-f]{32}$/);
});
```

```js
// tests/state-machine.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { transition } from '../src/state-machine.js';

const base = {
  phase: 'PLAN', material_failures: 0, verification_stale: false,
  review_stale: false, cancelled: false
};

test('only explicit execute moves PLAN to READY', () => {
  const next = transition(base, 'human_execute', { task_contract_valid: true });
  assert.equal(next.phase, 'READY');
});

test('review failure progression is bounded', () => {
  const one = transition({ ...base, phase: 'VERIFYING_REVIEW' }, 'review_failed');
  assert.equal(one.phase, 'REPAIR_PENDING');
  assert.equal(one.material_failures, 1);

  const two = transition({ ...one, phase: 'VERIFYING_REVIEW' }, 'review_failed');
  assert.equal(two.phase, 'ESCALATION_PENDING');
  assert.equal(two.material_failures, 2);

  const three = transition({ ...two, phase: 'VERIFYING_REVIEW' }, 'review_failed');
  assert.equal(three.phase, 'REPLAN_REQUIRED');
  assert.equal(three.material_failures, 3);
});

test('illegal transitions fail closed', () => {
  assert.throws(() => transition(base, 'review_passed'), /illegal_transition/);
});
```

- [ ] **Step 2: Write failing atomic-store test**

Use `fs.mkdtemp` under `os.tmpdir()`. Assert that `initRun` creates `run.json`, `state.json`, `events.jsonl`, and `turns/`, and that `writeState` round-trips exact JSON.

- [ ] **Step 3: Run focused tests and confirm RED**

```bash
node --test tests/ids.test.js tests/state-machine.test.js tests/state-store.test.js
```

- [ ] **Step 4: Implement the state machine exactly from the approved spec**

Supported phases:

```text
PLAN READY PREPARING WORKING VERIFYING_WORK REVIEWING VERIFYING_REVIEW
REPAIR_PENDING ESCALATION_PENDING REPLAN_REQUIRED BLOCKED DONE CANCELLED
```

Required events:

```text
human_execute prepare provisioned worker_artifact_valid worker_verification_passed
worker_verification_failed review_artifact_valid review_passed review_failed
repair_ticket_accepted escalation_selected hard_blocker human_cancel
```

Any mutation after prior verification must set `verification_stale: true` and `review_stale: true` until fresh evidence is recorded.

- [ ] **Step 5: Implement durable state store**

Directory contract:

```text
<root>/<run_id>/run.json
<root>/<run_id>/task.json
<root>/<run_id>/classification.json
<root>/<run_id>/state.json
<root>/<run_id>/events.jsonl
<root>/<run_id>/turns/
```

`appendEvent` writes one JSON object per line with controller timestamp, previous phase, event, and resulting phase.

- [ ] **Step 6: Wire `transition` and `status` CLI commands**

Examples:

```bash
mighty-factory transition --run run_abcd --event review_failed
mighty-factory status --run run_abcd
```

`transition` loads current state, applies one legal transition, atomically persists it, appends one event, and prints the new state as JSON.

- [ ] **Step 7: Verify and commit**

```bash
node --test tests/ids.test.js tests/state-machine.test.js tests/state-store.test.js tests/cli.test.js
npm test
git add incubator/mighty-factory/src/ids.js \
        incubator/mighty-factory/src/state-machine.js \
        incubator/mighty-factory/src/state-store.js \
        incubator/mighty-factory/src/cli.js \
        incubator/mighty-factory/tests/ids.test.js \
        incubator/mighty-factory/tests/state-machine.test.js \
        incubator/mighty-factory/tests/state-store.test.js
git commit -m "feat(factory): persist bounded lifecycle state"
```

---

### Task 4: Add durable request/result artifacts and correlation validation

**Files:**
- Create: `incubator/mighty-factory/src/artifacts.js`
- Create: `incubator/mighty-factory/tests/artifacts.test.js`
- Modify: `incubator/mighty-factory/src/state-store.js`

**Interfaces:**
- Produces: `writeTurnRequest(store, ids, request)`.
- Produces: `readWorkerResult(path, expected) -> result`.
- Produces: `readReviewResult(path, expected) -> result`.
- Produces: `assertCorrelation(artifact, expected)`.
- `expected` includes exact `schema_version`, `run_id`, `task_id`, `turn_id`, and when applicable expected commit.

- [ ] **Step 1: Write failing artifact tests**

Test all of the following independently:

```text
valid worker artifact accepted
wrong run_id rejected
wrong turn_id rejected
worker status must be implemented or blocked
implemented worker requires commit
blocked worker requires blocker
valid reviewer PASS accepted only for expected reviewed_commit
reviewer FAIL requires at least one material finding
unknown schema_version rejected
```

Use exact fixtures written to a temp directory rather than mocks.

- [ ] **Step 2: Run test and confirm RED**

```bash
node --test tests/artifacts.test.js
```

- [ ] **Step 3: Implement strict schemas without coercion**

Worker required fields for `implemented`:

```js
{
  schema_version: 1,
  run_id: String,
  task_id: String,
  turn_id: String,
  role: 'worker',
  status: 'implemented',
  commit: String,
  summary: String,
  reported_tests: Array,
  known_limitations: Array
}
```

Reviewer required fields:

```js
{
  schema_version: 1,
  run_id: String,
  task_id: String,
  turn_id: String,
  role: 'reviewer',
  reviewed_commit: String,
  verdict: 'PASS' | 'FAIL',
  findings: Array,
  evidence_checked: Array,
  confidence: Number
}
```

Never rewrite stale IDs or substitute the active IDs into a malformed artifact.

- [ ] **Step 4: Add atomic result-write helper for controller-owned artifacts**

Controller-generated request/verification artifacts use temp-file + rename. Agent-written result files are only read after they exist and parse as complete JSON.

- [ ] **Step 5: Verify and commit**

```bash
node --test tests/artifacts.test.js tests/state-store.test.js
npm test
git add incubator/mighty-factory/src/artifacts.js \
        incubator/mighty-factory/src/state-store.js \
        incubator/mighty-factory/tests/artifacts.test.js
git commit -m "feat(factory): add correlated durable handoffs"
```

---

### Task 5: Add configuration and provider launch adapters

**Files:**
- Create: `incubator/mighty-factory/factory.config.example.json`
- Create: `incubator/mighty-factory/src/config.js`
- Create: `incubator/mighty-factory/src/provider-adapters/index.js`
- Create: `incubator/mighty-factory/src/provider-adapters/codex.js`
- Create: `incubator/mighty-factory/src/provider-adapters/cline.js`
- Create: `incubator/mighty-factory/src/provider-adapters/antigravity.js`
- Create: `incubator/mighty-factory/tests/config.test.js`
- Create: `incubator/mighty-factory/tests/provider-adapters.test.js`
- Modify: `incubator/mighty-factory/src/cli.js`

**Interfaces:**
- Produces: `loadConfig(path) -> validatedConfig`.
- Produces: `buildLaunchSpec(adapterName, gear, context) -> { herdrKind, argv, env }`.
- Routing code never emits provider CLI flags.

- [ ] **Step 1: Write failing config tests**

Test that config rejects:

```text
missing ORCH_DEFAULT / WORK_DEFAULT / REVIEW_DEFAULT / REVIEW_STRONG
unknown provider_adapter
non-max ORCH_DEFAULT effort
confidence_threshold outside 0..1
non-array verification.commands
relative state_root after expansion rules are applied
```

- [ ] **Step 2: Write failing provider-adapter tests**

Use explicit adapter-owned config mappings rather than hard-coding current provider model names into routing logic. Example test input:

```js
const gear = {
  provider_adapter: 'codex',
  herdr_kind: 'codex',
  model_alias: 'luna',
  effort: 'max',
  launch: {
    model_args: ['--model', 'gpt-example-luna'],
    effort_args: ['--config', 'model_reasoning_effort=max']
  }
};
```

Expected:

```js
{
  herdrKind: 'codex',
  argv: ['--model', 'gpt-example-luna', '--config', 'model_reasoning_effort=max'],
  env: {}
}
```

Equivalent Cline and Antigravity tests use their own `launch.model_args` and `launch.effort_args`. This deliberately avoids asserting undocumented provider flags in controller code.

- [ ] **Step 3: Run tests and confirm RED**

```bash
node --test tests/config.test.js tests/provider-adapters.test.js
```

- [ ] **Step 4: Implement config validation and adapter registry**

`factory.config.example.json` must include:

```json
{
  "state_root": "~/.local/state/mighty-factory/runs",
  "confidence_threshold": 0.75,
  "gears": {
    "ORCH_DEFAULT": {
      "provider_adapter": "codex",
      "herdr_kind": "codex",
      "model_alias": "luna",
      "effort": "max",
      "launch": { "model_args": [], "effort_args": [] }
    },
    "WORK_DEFAULT": {
      "provider_adapter": "antigravity",
      "herdr_kind": "agy",
      "model_alias": "flash",
      "effort": "high",
      "launch": { "model_args": [], "effort_args": [] }
    },
    "WORK_STRONG": {
      "provider_adapter": "antigravity",
      "herdr_kind": "agy",
      "model_alias": "strong",
      "effort": "high",
      "launch": { "model_args": [], "effort_args": [] }
    },
    "REVIEW_DEFAULT": {
      "provider_adapter": "cline",
      "herdr_kind": "cline",
      "model_alias": "review-default",
      "effort": "high",
      "launch": { "model_args": [], "effort_args": [] }
    },
    "REVIEW_STRONG": {
      "provider_adapter": "cline",
      "herdr_kind": "cline",
      "model_alias": "review-strong",
      "effort": "high",
      "launch": { "model_args": [], "effort_args": [] }
    }
  },
  "verification": {
    "commands": []
  }
}
```

The example intentionally leaves raw provider launch args empty until the user confirms exact CLI flags on the local installed versions.

- [ ] **Step 5: Wire `print-config` to emit resolved validated JSON**

```bash
mighty-factory print-config --config ./factory.config.json
```

Must never print secrets from inherited environment.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/config.test.js tests/provider-adapters.test.js tests/route.test.js
npm test
git add incubator/mighty-factory/factory.config.example.json \
        incubator/mighty-factory/src/config.js \
        incubator/mighty-factory/src/provider-adapters \
        incubator/mighty-factory/src/cli.js \
        incubator/mighty-factory/tests/config.test.js \
        incubator/mighty-factory/tests/provider-adapters.test.js
git commit -m "feat(factory): add configurable provider gears"
```

---

### Task 6: Add Git identity checks and authoritative verification execution

**Files:**
- Create: `incubator/mighty-factory/src/command-runner.js`
- Create: `incubator/mighty-factory/src/git-verify.js`
- Create: `incubator/mighty-factory/src/verifier.js`
- Create: `incubator/mighty-factory/tests/git-verify.test.js`
- Create: `incubator/mighty-factory/tests/verifier.test.js`

**Interfaces:**
- Produces: `runCommand(command, args, options) -> { exitCode, stdout, stderr }` without shell interpolation by default.
- Produces: `verifyGitIdentity({ repo, base, reportedCommit, allowNoop }, runner) -> evidence`.
- Produces: `runVerificationCommands({ cwd, commands }, runner) -> commandEvidence[]`.
- Produces: `verifyWorkerCommit(...) -> verificationArtifact` bound to exact commit SHA.

- [ ] **Step 1: Write failing Git verification tests using a real temp Git repo**

Create a temp repo with `git init`, configure synthetic local username/email, make base commit, make child commit, then assert:

```text
reported commit exists
HEAD must equal reported commit
base must be ancestor of reported commit
base-to-head diff must be non-empty unless allowNoop true
clean-worktree policy is observable
wrong commit fails
unrelated commit fails ancestry
```

Do not mock Git semantics.

- [ ] **Step 2: Write failing verifier tests with an injected runner**

Example:

```js
test('authoritative verification records real exit codes and fails closed', async () => {
  const calls = [];
  const runner = async (command, args, options) => {
    calls.push({ command, args, cwd: options.cwd });
    return command === 'npm'
      ? { exitCode: 0, stdout: 'ok', stderr: '' }
      : { exitCode: 1, stdout: '', stderr: 'bad' };
  };

  const result = await runVerificationCommands({
    cwd: '/repo',
    commands: [
      { command: 'npm', args: ['test'] },
      { command: 'node', args: ['--check', 'src/a.js'] }
    ]
  }, runner);

  assert.equal(result[0].exit_code, 0);
  assert.equal(result[1].exit_code, 1);
});
```

- [ ] **Step 3: Run tests and confirm RED**

```bash
node --test tests/git-verify.test.js tests/verifier.test.js
```

- [ ] **Step 4: Implement subprocess and Git verification**

`command-runner.js` uses `spawn`/`spawnSync` argument arrays, never concatenated user-controlled shell strings.

Verification artifact must contain:

```js
{
  schema_version: 1,
  run_id,
  task_id,
  turn_id,
  verified_commit,
  git: {
    commit_exists: true,
    head_matches: true,
    base_is_ancestor: true,
    diff_nonempty: true,
    worktree_clean: true
  },
  commands: [
    { command: 'npm', args: ['test'], exit_code: 0, stdout_tail: '...', stderr_tail: '' }
  ],
  result: 'pass' | 'fail'
}
```

Cap stored stdout/stderr tails to a deterministic maximum such as 16 KiB each to avoid unbounded state files.

- [ ] **Step 5: Ensure mutation makes old evidence stale**

Controller/state-machine integration must clear active verification/review references or set stale flags before the next worker repair turn.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/git-verify.test.js tests/verifier.test.js tests/state-machine.test.js
npm test
git add incubator/mighty-factory/src/command-runner.js \
        incubator/mighty-factory/src/git-verify.js \
        incubator/mighty-factory/src/verifier.js \
        incubator/mighty-factory/tests/git-verify.test.js \
        incubator/mighty-factory/tests/verifier.test.js
git commit -m "feat(factory): independently verify worker evidence"
```

---

### Task 7: Wrap Herdr safely and provision isolated runs

**Files:**
- Create: `incubator/mighty-factory/src/herdr.js`
- Create: `incubator/mighty-factory/src/prepare-run.js`
- Create: `incubator/mighty-factory/tests/herdr.test.js`
- Create: `incubator/mighty-factory/tests/prepare-run.test.js`
- Create: `incubator/mighty-factory/tests/fixtures/herdr/workspace-create.json`
- Create: `incubator/mighty-factory/tests/fixtures/herdr/pane-split.json`
- Create: `incubator/mighty-factory/tests/fixtures/herdr/agent-idle.json`
- Create: `incubator/mighty-factory/tests/fixtures/herdr/agent-working.json`
- Create: `incubator/mighty-factory/tests/fixtures/herdr/agent-blocked.json`

**Interfaces:**
- Produces `createHerdrClient(runner)` with methods `workspaceCreate`, `worktreeCreate`, `paneSplit`, `agentStart`, `agentGet`, `agentPrompt`, `agentWait`, `agentRead`.
- Produces `awaitSettledAgent(client, target, timeoutMs)` returning only `idle` or `done`; `blocked` throws immediately; `unknown` is never success.
- Produces `prepareRun({ repo, baseRef, branchName, gearSpecs, run }, deps) -> provisioningRecord`.

- [ ] **Step 1: Capture fixture shapes from current Herdr documentation**

Use the documented response locations exactly:

```text
workspace create -> .result.workspace, .result.tab, .result.root_pane
pane split -> .result.pane
successful agent start/prompt/wait -> .result.agent
```

Fixture files contain synthetic IDs only, for example `w1`, `w1:t1`, `w1:p1`, never local machine secrets.

- [ ] **Step 2: Write failing Herdr wrapper tests**

Cover:

```text
JSON success parsing
nonzero exit with JSON stderr becomes OperationalError
workspace root pane ID comes from returned JSON
pane split ID comes from returned JSON
working agent causes wait before prompt
blocked agent rejects without prompt
unknown agent cannot satisfy settled precondition
prompt timeout/stall is returned distinctly so caller can inspect before retry
```

Use injected runner responses; do not require Herdr in unit tests.

- [ ] **Step 3: Run tests and confirm RED**

```bash
node --test tests/herdr.test.js tests/prepare-run.test.js
```

- [ ] **Step 4: Implement Herdr CLI calls using argument arrays**

Representative calls:

```text
herdr workspace create --cwd <path> --label <label> --no-focus
herdr pane split <pane> --direction right --no-focus
herdr agent get <target>
herdr agent start <name> --kind <kind> --pane <pane> -- <argv...>
herdr agent prompt <name> <text> --wait --until idle --until done --timeout <ms>
herdr agent wait <name> --until idle --until done --timeout <ms>
herdr agent read <name> --source recent-unwrapped --lines 120
```

For worktree creation, use the currently installed Herdr CLI syntax discovered via `herdr worktree create --help` during implementation and lock that exact argv shape in a unit test before production code calls it. This discovery step is read-only and must be committed as the concrete tested argv shape, not left dynamic at runtime.

- [ ] **Step 5: Implement `prepareRun` provisioning sequence**

Exact order:

```text
inspect repo/base safety
create task branch/worktree through Herdr
capture returned workspace/root pane/worktree path
split reviewer pane from returned root pane
start worker in root pane with WORK gear launch spec
start reviewer in reviewer pane with REVIEW gear launch spec
persist all authoritative returned IDs/paths in run.json
transition PREPARING -> WORKING only after both agents are input-ready
```

Do not predict pane IDs and do not create a worker/reviewer in the user's original repo pane.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/herdr.test.js tests/prepare-run.test.js
npm test
git add incubator/mighty-factory/src/herdr.js \
        incubator/mighty-factory/src/prepare-run.js \
        incubator/mighty-factory/tests/herdr.test.js \
        incubator/mighty-factory/tests/prepare-run.test.js \
        incubator/mighty-factory/tests/fixtures/herdr
git commit -m "feat(factory): provision isolated Herdr runs"
```

---

### Task 8: Build controller operations for worker dispatch, review, repair, and completion

**Files:**
- Create: `incubator/mighty-factory/src/controller.js`
- Create: `incubator/mighty-factory/tests/controller.test.js`
- Modify: `incubator/mighty-factory/src/cli.js`
- Modify: `incubator/mighty-factory/src/artifacts.js`
- Modify: `incubator/mighty-factory/src/state-machine.js`

**Interfaces:**
- Produces: `createController(deps)` with operations:
  - `prepareRun`
  - `dispatchWorker`
  - `verifyWorker`
  - `dispatchReviewer`
  - `verifyReview`
  - `recordRepairTicket`
  - `status`
- Each dispatch creates a fresh `turn_id` and `request.json` before prompting.
- Completion is only possible after controller verification and reviewer PASS reference the same exact commit.

- [ ] **Step 1: Write failing controller happy-path test with fake Herdr and real temp state**

Scenario:

```text
PLAN -> human_execute -> READY
prepare -> PREPARING -> provisioned -> WORKING
worker turn artifact references commit C1
verify C1 -> REVIEWING
reviewer PASS references C1 and did not mutate target
controller -> DONE
```

Assert that two different `turn_id` values were created for worker and reviewer and that DONE stores the exact verified/reviewed commit.

- [ ] **Step 2: Write failing stale-turn regression test**

Create an old worker result with correct run/task but previous `turn_id`; assert it cannot advance `WORKING`.

- [ ] **Step 3: Write failing review-mutation test**

Simulate reviewer PASS followed by changed HEAD/status/diff identity. Assert review is rejected and DONE is impossible.

- [ ] **Step 4: Write failing repair/escalation tests**

Assert:

```text
first material review FAIL -> REPAIR_PENDING -> new worker turn
repair mutation marks verification/review stale
second material review FAIL -> ESCALATION_PENDING
third material review FAIL -> REPLAN_REQUIRED
no fourth automatic worker dispatch occurs
```

- [ ] **Step 5: Run test and confirm RED**

```bash
node --test tests/controller.test.js
```

- [ ] **Step 6: Implement controller methods as composition only**

`controller.js` must call existing units; it must not duplicate routing, state-machine, artifact, Git, or Herdr logic.

Worker prompt payload must include:

```text
RUN_ID
TASK_ID
TURN_ID
EXPECTED_RESULT_PATH
TASK_CONTRACT_PATH
WORKTREE_PATH
```

Reviewer prompt payload must include:

```text
RUN_ID
TASK_ID
TURN_ID
EXPECTED_RESULT_PATH
VERIFIED_COMMIT
BASE_REF
WORKER_VERIFICATION_PATH
```

On `agent_prompt_stalled`/timeout, controller checks expected artifact and current agent state before any retry. If duplicate-turn safety cannot be proven, transition to `BLOCKED`.

- [ ] **Step 7: Wire CLI commands to controller**

Required commands:

```text
prepare-run
verify-worker
verify-review
status
```

CLI prints structured JSON and uses operational error codes on failure.

- [ ] **Step 8: Verify and commit**

```bash
node --test tests/controller.test.js tests/artifacts.test.js tests/state-machine.test.js
npm test
git add incubator/mighty-factory/src/controller.js \
        incubator/mighty-factory/src/cli.js \
        incubator/mighty-factory/src/artifacts.js \
        incubator/mighty-factory/src/state-machine.js \
        incubator/mighty-factory/tests/controller.test.js
git commit -m "feat(factory): enforce worker-review controller loop"
```

---

### Task 9: Add non-mutating doctor checks

**Files:**
- Create: `incubator/mighty-factory/src/doctor.js`
- Create: `incubator/mighty-factory/tests/doctor.test.js`
- Modify: `incubator/mighty-factory/src/cli.js`

**Interfaces:**
- Produces: `runDoctor({ configPath, env }, deps) -> { ok, checks[] }`.
- Every check contains `{ name, ok, message }`.
- Doctor never installs tools, logs in providers, changes config, or launches agents.

- [ ] **Step 1: Write failing doctor tests**

Cover:

```text
Node >= 20 check
config parses
required gears/adapters validate
Git executable exists
Herdr executable exists
Herdr server can answer a non-mutating agent list/get-style command
HERDR_ENV=1 requirement can be enforced by config/context
state_root parent is writable
invalid provider launch spec is reported, not silently ignored
```

Use injected command runner and temp filesystem.

- [ ] **Step 2: Run and confirm RED**

```bash
node --test tests/doctor.test.js
```

- [ ] **Step 3: Implement doctor with no side effects**

Doctor output example:

```json
{
  "ok": false,
  "checks": [
    { "name": "node", "ok": true, "message": "Node 20+" },
    { "name": "herdr", "ok": false, "message": "herdr executable not found on PATH" }
  ]
}
```

Never claim a raw model ID is valid unless a provider exposes a supported non-mutating confirmation mechanism; v0.1 may report such aliases as “configured, not provider-validated”.

- [ ] **Step 4: Wire `mighty-factory doctor` and verify**

```bash
node --test tests/doctor.test.js tests/cli.test.js
npm test
```

- [ ] **Step 5: Commit**

```bash
git add incubator/mighty-factory/src/doctor.js \
        incubator/mighty-factory/src/cli.js \
        incubator/mighty-factory/tests/doctor.test.js
git commit -m "feat(factory): add non-mutating environment doctor"
```

---

### Task 10: Add the worker/reviewer contracts and orchestrator skill

**Files:**
- Create: `incubator/mighty-factory/prompts/worker.md`
- Create: `incubator/mighty-factory/prompts/reviewer.md`
- Create: `incubator/mighty-factory/skills/mighty-factory-orchestrator/SKILL.md`
- Create: `incubator/mighty-factory/tests/contracts.test.js`

**Interfaces:**
- Worker contract may mutate only the task worktree and must write exactly one correlated worker result artifact.
- Reviewer contract is read-only and must write exactly one correlated review artifact.
- Orchestrator skill remains in PLAN until exact `/execute`; it asks controller for legal next action instead of maintaining a shadow lifecycle.

- [ ] **Step 1: Write failing static contract tests**

`tests/contracts.test.js` must read the Markdown files and assert required phrases/contracts exist, including:

```text
worker: RUN_ID, TASK_ID, TURN_ID, EXPECTED_RESULT_PATH, do not merge, do not deploy
reviewer: reviewed_commit, read-only, do not modify files, PASS/FAIL, evidence
orchestrator: exact /execute, exact /cancel, controller owns state, never infer DONE
```

- [ ] **Step 2: Run and confirm RED**

```bash
node --test tests/contracts.test.js
```

- [ ] **Step 3: Write worker contract**

Worker instructions must require:

```text
operate only in supplied worktree
implement only supplied task contract
run requested local checks as useful evidence
commit the implementation
write worker-result.json atomically when possible
report blocked instead of fabricating completion
never merge/deploy/change credentials
never alter run/task/turn IDs
```

- [ ] **Step 4: Write reviewer contract**

Reviewer instructions must require:

```text
review exact verified commit/base-to-head diff
inspect controller verification artifact
remain read-only
seek material defects, regressions, missing tests, authority violations
PASS only when no material finding remains
FAIL findings include severity/location/problem/required_fix
write correlated review-result.json
never repair the code directly
```

- [ ] **Step 5: Write orchestrator skill**

Skill flow:

```text
PLAN conversation
-> produce task contract + classification + authoritative verification commands
-> wait for exact /execute
-> invoke controller route/prepare-run
-> follow controller-reported legal next action
-> convert reviewer findings to bounded repair ticket only when controller requests it
-> use escalation gear only when controller enters ESCALATION_PENDING
-> never say complete until controller state is DONE
```

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/contracts.test.js
npm test
git add incubator/mighty-factory/prompts \
        incubator/mighty-factory/skills \
        incubator/mighty-factory/tests/contracts.test.js
git commit -m "feat(factory): define agent role contracts"
```

---

### Task 11: Write README, run end-to-end fixture test, and validate v0.1 completion gates

**Files:**
- Create: `incubator/mighty-factory/README.md`
- Create: `incubator/mighty-factory/tests/e2e-controller.test.js`
- Modify: `incubator/mighty-factory/package.json`

**Interfaces:**
- E2E test runs controller logic against a fake Herdr runner and a real temporary Git repository/state directory.
- README documents manual model/provider config rather than pretending provider catalogs are auto-discovered.

- [ ] **Step 1: Write failing end-to-end test**

The test must exercise this complete sequence without real provider usage:

```text
create temp Git repo/base commit
initialize PLAN run
exact human_execute event
route defaults
fake Herdr returns worktree/pane/idle-agent JSON
worker result for C1
controller Git + command verification passes for C1
review PASS for C1
reviewer immutability check passes
state becomes DONE
```

Then run a second scenario where a stale worker artifact uses the previous `turn_id`; assert it is rejected and cannot reach REVIEWING/DONE.

- [ ] **Step 2: Run and confirm RED**

```bash
node --test tests/e2e-controller.test.js
```

- [ ] **Step 3: Add README with exact operator workflow**

README sections:

```text
What Mighty Factory is
What it deliberately does not do
Prerequisites: Node 20+, Git, Herdr, Codex/Cline/Antigravity configured separately
Copy factory.config.example.json -> factory.config.json
Fill provider launch args from each installed CLI's current help/model picker
Run doctor
PLAN mode
Exact /execute boundary
Worker -> controller verification -> reviewer loop
Repair/escalation limits
Where durable run artifacts live
No automatic merge/deploy
Troubleshooting blocked/unknown/stalled agents
```

Include a Mermaid diagram equivalent to the approved architecture.

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

- [ ] **Step 5: Run the full verification matrix**

```bash
cd incubator/mighty-factory
npm test
npm run test:e2e
node bin/mighty-factory.js help
node bin/mighty-factory.js route \
  --classification '{"scope":"normal","risk":"medium","ambiguity":"low","change_kind":"feature","cross_cutting":false,"confidence":0.9}' \
  --state '{"phase":"READY","material_failures":0,"plan_confirmed":true}' \
  --config ./factory.config.example.json
```

Expected:

```text
all tests: 0 failures
E2E: happy path DONE and stale-turn regression rejected
help: exit 0
route: JSON selecting ORCH_DEFAULT / WORK_DEFAULT / REVIEW_DEFAULT / execute
```

- [ ] **Step 6: Perform spec-to-plan self-review before claiming v0.1 implemented**

Check each approved spec gate explicitly:

```text
exact /execute boundary
controller-generated run/task/turn IDs
durable artifacts outside target repo
deterministic state transitions
bounded three-failure policy
provider adapter isolation
Herdr pane/worktree provisioning
independent Git/test verification
reviewer immutability detection
stale evidence invalidation
no implicit merge/deploy
DONE only for same verified/reviewed commit
```

Any missing gate blocks completion.

- [ ] **Step 7: Commit**

```bash
git add incubator/mighty-factory/README.md \
        incubator/mighty-factory/package.json \
        incubator/mighty-factory/tests/e2e-controller.test.js
git commit -m "docs(factory): complete v0.1 operator workflow"
```

---

## Execution Order and Review Gates

Execute Tasks 1 through 11 in order. After each task:

1. run that task's focused tests,
2. run `npm test`,
3. inspect `git diff --check`,
4. commit only the task's files,
5. request a fresh code review before beginning the next task.

Do not combine tasks to save time. The task boundaries are intentionally chosen so a reviewer can reject one subsystem without invalidating unrelated work.

## Final Acceptance Gate

Before calling the implementation complete, collect fresh evidence for all of the following in the same implementation HEAD:

```bash
cd incubator/mighty-factory
npm test
npm run test:e2e
git diff --check
node bin/mighty-factory.js help
```

Additionally, on the user's Mac inside Herdr, run:

```bash
node bin/mighty-factory.js doctor --config ./factory.config.json
```

Then perform one provider-backed smoke run on a disposable test repository with a harmless one-file task. The provider-backed smoke run must prove:

```text
PLAN does not spawn agents
/execute provisions an isolated worktree
worker result is correlated to its turn
controller independently verifies the exact commit
reviewer receives and reviews that exact commit
reviewer does not mutate the repo
controller reports DONE only after matching verification + PASS
main branch remains unchanged
```

A skipped provider-backed smoke run means the code may be unit/integration complete, but it is not yet `HERDR_RUNTIME_QUALIFIED`.
