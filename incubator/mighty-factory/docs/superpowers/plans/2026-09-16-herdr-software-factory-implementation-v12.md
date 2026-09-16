# Mighty Factory v0.1 Implementation Plan — Review 12

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Review-12 Mighty Factory as a dependency-free Node.js controller around Herdr with immutable authorization inputs, deterministic lifecycle/routing, crash-safe owned resources, prompt-safe atomic turn finalization, protected shared Git state, byte-digested evidence, bounded verification subprocesses, independent review, escalation caps, and a final freshness gate.

**Architecture:** The existing Luna-Max Codex session is the human-facing foreman and owns planning/judgment. Exact `/execute` freezes config, task, classification, canonical source worktree, common Git dir, and base commit. The controller owns every later decision-bearing state transition. Worker turns operate in one native linked task worktree guarded against source-repository mutation. Reviewer turns use independent clones; arbiter turns use evidence-only bundles.

**Tech Stack:** Node.js >= 20, ESM, built-in `node:test`, `fs`, `path`, `os`, `crypto`, `child_process`; native Git; Herdr CLI; no runtime npm dependencies.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-16-herdr-software-factory-design-v12.md`

## Global Constraints

- Work only under `incubator/mighty-factory/` on branch `incubator/mighty-factory-v0`.
- Do not modify Mighty Router mainline behavior or `universal-agent-loop`.
- TDD every behavior: observe RED before production code, then GREEN.
- Exact `/execute`; PLAN is non-mutating.
- No public generic lifecycle `transition` command.
- Freeze config/task/classification/source/common-Git/base SHA at authorization.
- State/temp/source roots must not overlap in either containment direction.
- Every external Factory resource gets a byte-digested owner marker before mutation.
- Every state mutation uses a per-run lock with PID + process-start identity.
- Prompt attempt is persisted before delivery; ambiguous delivery is never blindly resent.
- Result artifact does not finish a turn: producer settles, stage becomes `finalizing`, archive is written/digested, exact outbox is removed, then one atomic state write clears the lease + changes phase.
- Completed archived turns pending transport cleanup cannot be abandoned.
- All external JSON/artifacts use descriptor-based no-follow reads; turn results <= 1 MiB.
- Protect source HEAD/status/refs/common config/hooks; only exact task branch may differ.
- Verification package lifecycle definitions must equal pinned base definitions.
- Verification subprocesses run with pinned timeouts, bounded output, and killable process groups.
- Decision evidence is canonical exact-byte SHA-256, including repair tickets.
- Repairable implementation failures may route to repair; integrity/authority violations BLOCK.
- Reviewer PASS cannot contain material/BLOCKER/IMPORTANT findings.
- Final freshness immediately precedes DONE.
- No implicit merge, push, deploy, production mutation, billing, credentials change, package installation, permission approval, reset/stash/clean, or force cleanup.

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
    config.js
    task-contract.js
    classify-schema.js
    authorization.js
    environment.js
    route.js
    provider-adapters/
      index.js
      codex.js
      cline.js
      antigravity.js
    process-identity.js
    run-lock.js
    state-machine.js
    state-store.js
    evidence.js
    turn-archive.js
    git.js
    resource-plan.js
    source-guard.js
    safe-file.js
    artifact-ingest.js
    verification-policy.js
    command-runner.js
    verifier.js
    herdr.js
    turn-launcher.js
    recovery.js
    review-clone.js
    review-guard.js
    review-verifier.js
    repair.js
    arbiter-bundle.js
    freshness.js
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
    task-contract.test.js
    classify-schema.test.js
    canonical-json.test.js
    config.test.js
    authorization.test.js
    environment.test.js
    route.test.js
    provider-adapters.test.js
    process-identity.test.js
    run-lock.test.js
    state-machine.test.js
    state-store.test.js
    evidence.test.js
    turn-archive.test.js
    git.test.js
    resource-plan.test.js
    source-guard.test.js
    safe-file.test.js
    artifact-ingest.test.js
    verification-policy.test.js
    command-runner.test.js
    verifier.test.js
    herdr.test.js
    turn-launcher.test.js
    recovery.test.js
    review-clone.test.js
    review-guard.test.js
    review-verifier.test.js
    repair.test.js
    arbiter-bundle.test.js
    freshness.test.js
    controller.test.js
    cleanup.test.js
    doctor.test.js
    contracts.test.js
    e2e-controller.test.js
```

---

### Task 1: Package scaffold, CLI surface, task/classification schemas

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
- Produces: `main(argv, io = { stdout: process.stdout, stderr: process.stderr }) -> Promise<number>`
- Produces: `validateTaskContract(value, classification) -> normalizedTask`
- Produces: `validateClassification(value) -> normalizedClassification`
- Exit codes: `0` success, `1` operational failure, `2` usage error.

- [ ] **Step 1: Write failing CLI surface test**

```js
// tests/cli.test.js
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

test('help exposes only high-level controller operations', () => {
  const r = spawnSync(process.execPath, [bin, 'help'], { encoding: 'utf8' });
  assert.equal(r.status, 0);
  for (const cmd of required) assert.match(r.stdout, new RegExp(`mighty-factory ${cmd}`));
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

test('accepts exact v0.1 trust contract', () => {
  assert.equal(validateTaskContract(valid, classification).execution_trust, 'trusted-local-repository');
});

test('rejects traversal allowed path', () => {
  assert.throws(() => validateTaskContract({ ...valid, allowed_paths: ['../x'] }, classification), /path/);
});

test('rejects code task without executable verification', () => {
  assert.throws(() => validateTaskContract({
    ...valid,
    verification: { policy: 'trusted-repo-checks', commands: [] }
  }, classification), /verification/);
});
```

- [ ] **Step 3: Write failing classification tests**

```js
// tests/classify-schema.test.js
import test from 'node:test';
import assert from 'node:assert/strict';
import { validateClassification } from '../src/classify-schema.js';

test('rejects string confidence coercion', () => {
  assert.throws(() => validateClassification({
    scope:'normal', risk:'low', ambiguity:'low', change_kind:'bugfix',
    cross_cutting:false, confidence:'0.9'
  }), /confidence/);
});
```

Cover every exact enum from the spec and `confidence` finite numeric `0..1`.

- [ ] **Step 4: Run RED**

```bash
cd incubator/mighty-factory
node --test tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
```

Expected: FAIL because implementation files do not yet exist.

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

Reserve every public command from the spec. Reserved-but-unimplemented command -> `OperationalError('not_implemented', ...)`, not usage error.

- [ ] **Step 6: Verify GREEN and commit**

```bash
node --test tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
npm test
git diff --check
git add package.json bin/mighty-factory.js src/cli.js src/errors.js src/task-contract.js src/classify-schema.js \
  tests/cli.test.js tests/task-contract.test.js tests/classify-schema.test.js
git commit -m "feat(factory): scaffold authority contracts"
```

---

### Task 2: Canonical snapshots, immutable authorization, roots, routing and concrete gears

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
- `canonicalJsonBytes(value) -> Buffer`
- `sha256Bytes(bytes) -> 'sha256:<hex>'`
- `writeSnapshotFile(path, value) -> Promise<{digest:string}>`
- `readVerifiedSnapshot(path, expectedDigest) -> Promise<object>`
- `loadConfig(path) -> validatedConfig`
- `authorizeInputs({taskPath,classificationPath,configPath}, deps) -> runManifest`
- `buildSanitizedEnv(sourceEnv, allowedNames, fixed) -> object`
- `routeTask({classification,state,configSnapshot}) -> route`
- `buildLaunchSpec(adapterName, gear, context) -> {herdrKind,argv,envNames}`

- [ ] **Step 1: Write canonical JSON RED tests**

```js
test('object insertion order does not affect exact bytes', () => {
  assert.deepEqual(
    canonicalJsonBytes({ z:1, a:{ y:2, x:3 } }),
    canonicalJsonBytes({ a:{ x:3, y:2 }, z:1 })
  );
});

test('array order remains significant', () => {
  assert.notDeepEqual(canonicalJsonBytes({a:[1,2]}), canonicalJsonBytes({a:[2,1]}));
});
```

Also require exactly one trailing newline and reject NaN/Infinity/undefined/function values.

- [ ] **Step 2: Write immutable authorization RED test**

Use a real temp Git repo:

```text
commit A on main
config/task/classification files
/execute authorization
assert config.snapshot/task.snapshot/classification.snapshot + run.json exist
assert task snapshot stores canonical repo/common Git/base SHA A
mutate live config/task/classification
advance main to commit B
read pinned snapshots by digest
assert values remain original and base SHA remains A
```

- [ ] **Step 3: Write tamper RED test**

Modify one byte in `task.snapshot.json`; `readVerifiedSnapshot()` must fail digest verification before JSON parse/use.

- [ ] **Step 4: Write root/common-Git RED tests**

Cover:

```text
non-bare repo accepted
bare repo rejected
source inside state root rejected
state root inside source rejected
temp/state containment rejected
symlinked existing ancestor overlap rejected
canonical git-common-dir persisted
deterministic task branch preexisting -> authorization rejected
```

- [ ] **Step 5: Write routing/gear RED tests**

```js
test('high risk forces strong reviewer', () => {
  const route = routeTask({
    classification:{scope:'normal',risk:'high',ambiguity:'low',change_kind:'security',cross_cutting:false,confidence:0.95},
    state:{material_review_failures:0},
    configSnapshot: fixtureConfig
  });
  assert.equal(route.reviewerGear, 'REVIEW_STRONG');
});
```

Also test default route, ambiguity/low-confidence rejection, second failure arbiter+WORK_STRONG, third failure REPLAN_REQUIRED.

- [ ] **Step 6: Write environment/adapter RED tests**

Sanitizer strips `SUPER_SECRET_TOKEN` unless allowlisted by name. Every specialist gear requires `launch.resolved:true` and exact model/effort argv. Foreman expectation is not treated as a Factory-launched gear.

- [ ] **Step 7: Implement and verify**

Run:

```bash
node --test tests/canonical-json.test.js tests/config.test.js tests/authorization.test.js \
  tests/environment.test.js tests/route.test.js tests/provider-adapters.test.js
npm test
git diff --check
```

- [ ] **Step 8: Commit**

```bash
git add factory.config.example.json src/canonical-json.js src/config.js src/authorization.js \
  src/environment.js src/route.js src/provider-adapters src/cli.js \
  tests/canonical-json.test.js tests/config.test.js tests/authorization.test.js \
  tests/environment.test.js tests/route.test.js tests/provider-adapters.test.js
git commit -m "feat(factory): freeze run authority inputs"
```

---

### Task 3: Locks, process identity, lifecycle, state and evidence store

**Files:**
- Create: `src/ids.js`
- Create: `src/process-identity.js`
- Create: `src/run-lock.js`
- Create: `src/state-machine.js`
- Create: `src/state-store.js`
- Create: `src/evidence.js`
- Create: `src/turn-archive.js`
- Test: `tests/process-identity.test.js`
- Test: `tests/run-lock.test.js`
- Test: `tests/state-machine.test.js`
- Test: `tests/state-store.test.js`
- Test: `tests/evidence.test.js`
- Test: `tests/turn-archive.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `createId(prefix)`
- `getProcessIdentity(pid, runner) -> {alive,startToken,supported}`
- `withRunLock(runDir, command, fn, deps)`
- `recoverDeadRunLock(runDir,{expectedNonce},deps)`
- internal `transitionInternal(state,event,payload)`
- `createStateStore(root)`
- `writeCanonicalEvidence(path,value) -> {digest}`
- `readVerifiedEvidence(path,digest) -> value`
- `archiveTurn(...) -> {record,digest}`

- [ ] **Step 1: Process identity RED tests**

Fixtures: PID absent; same PID/same token live; same PID/different token reused; unsupported probe ambiguous.

- [ ] **Step 2: Lock RED tests**

```text
second acquisition -> run_locked
release in finally
wrong nonce recovery rejects
live same identity rejects
absent/reused PID can recover
ambiguous identity rejects with manual recovery message
```

- [ ] **Step 3: Lifecycle RED tests**

Test every transition in the spec, cancellation with/without active turn, invalid raw event rejection, material failure progression, and stale evidence invalidation on repair.

- [ ] **Step 4: Evidence/archive RED tests**

```js
test('modified archive bytes fail later verification', async () => {
  const { digest } = await writeCanonicalEvidence(file, { turn_id:'turn_1', status:'completed' });
  await fs.appendFile(file, ' ');
  await assert.rejects(() => readVerifiedEvidence(file, digest), /digest/);
});
```

Require no active-turn lease clear without a matching archive digest.

- [ ] **Step 5: Implement atomic state/event writes**

State file writes use temp+fsync/rename where available. `events.jsonl` records old/new revision + phase + event/command.

- [ ] **Step 6: Verify and commit**

```bash
node --test tests/process-identity.test.js tests/run-lock.test.js tests/state-machine.test.js \
  tests/state-store.test.js tests/evidence.test.js tests/turn-archive.test.js
npm test
git diff --check
git add src/ids.js src/process-identity.js src/run-lock.js src/state-machine.js src/state-store.js \
  src/evidence.js src/turn-archive.js src/cli.js tests/process-identity.test.js tests/run-lock.test.js \
  tests/state-machine.test.js tests/state-store.test.js tests/evidence.test.js tests/turn-archive.test.js
git commit -m "feat(factory): persist deterministic lifecycle evidence"
```

---

### Task 4: Crash-safe task resource and protected common Git state

**Files:**
- Create: `src/git.js`
- Create: `src/resource-plan.js`
- Create: `src/source-guard.js`
- Test: `tests/git.test.js`
- Test: `tests/resource-plan.test.js`
- Test: `tests/source-guard.test.js`

**Interfaces:**
- `inspectWorktrees(repo, runner)`
- `makeTaskResourcePlan({runId,tempRoot,baseSha,branch})`
- `reconcileTaskWorktree(plan, canonicalRepo, runner)`
- `captureProtectedSourceBaseline({sourceRepo,gitCommonDir,taskBranch},deps) -> {record,digest}`
- `assertProtectedSourceUnchanged(baseline,{expectedTaskCommit},deps)`

- [ ] **Step 1: Owner-before-mutation RED test**

Use fake Git runner and assert `.mighty-factory-owner.json` exists/digest persisted before the first `git worktree add` invocation.

- [ ] **Step 2: Resource reconciliation RED matrix**

Use real temp repo:

```text
branch absent + path absent -> create -b once
branch exists at base and unattached -> attach exact branch/path without -b
branch attached elsewhere -> BLOCKED
branch incompatible -> BLOCKED
exact owned worktree -> adopt
wrong/tampered owner marker -> BLOCKED
path is non-worktree -> BLOCKED
retry never allocates alternate branch/path
```

- [ ] **Step 3: Linked source/common-Git RED test**

Create a source linked worktree fixture. Assert baseline resolves config/hooks from `git rev-parse --git-common-dir`, not `source/.git` assumptions.

- [ ] **Step 4: Protected baseline RED tests**

Baseline contains source HEAD/status, sorted protected refs excluding task branch, task branch OID separately, common config exact bytes, hooks digest.

Mutate each independently and require failure:

```text
source working tree file
source HEAD
main ref
another branch/tag/ref
new ref
common config
hook contents
```

Exact task branch moving to `expectedTaskCommit` is allowed.

- [ ] **Step 5: Implement/verify/commit**

```bash
node --test tests/git.test.js tests/resource-plan.test.js tests/source-guard.test.js
npm test
git diff --check
git add src/git.js src/resource-plan.js src/source-guard.js \
  tests/git.test.js tests/resource-plan.test.js tests/source-guard.test.js
git commit -m "feat(factory): reconcile and protect git resources"
```

---

### Task 5: Safe-file ingestion and bounded verification subprocesses

**Files:**
- Create: `src/safe-file.js`
- Create: `src/artifact-ingest.js`
- Create: `src/verification-policy.js`
- Create: `src/command-runner.js`
- Test: `tests/safe-file.test.js`
- Test: `tests/artifact-ingest.test.js`
- Test: `tests/verification-policy.test.js`
- Test: `tests/command-runner.test.js`

**Interfaces:**
- `readRegularFileNoFollow({root,path,maxBytes}) -> {bytes,stat}`
- `ingestJsonArtifact({ownedRoot,expectedPath,destination,maxBytes,expected}) -> {artifact,digest}`
- `compileVerificationCommand(check,configSnapshot,repoRoot)`
- `runBoundedCommand(command,args,{cwd,env,timeoutMs,graceMs})`

- [ ] **Step 1: Safe-file RED matrix**

Accept a normal file. Reject parent symlink, final symlink, directory, FIFO/special file where platform fixture supports it, >1MiB result, lexical path escape, changed inode/size during read.

Implementation requirement: inspect each component below trusted owned root; open final file with `O_NOFOLLOW`; `fstat` before/after; read via descriptor only.

- [ ] **Step 2: Artifact schema RED tests**

Wrong run/task/turn/role/commit, malformed UTF-8/JSON -> reject. Exact bytes digest returned and copied atomically.

- [ ] **Step 3: Verification-policy RED tests**

Accept only exact shapes from spec. Reject unknown kind, absolute/traversal node paths, arbitrary command/args, `npx`, package install, migration/deploy forms.

Package lifecycle equality test:

```text
base pretest/test/posttest == reported -> allowed
reported test changed -> reject before npm
reported pretest/posttest changed -> reject
```

- [ ] **Step 4: Bounded process-group RED tests**

Spawn a test child which spawns a long-lived grandchild. Timeout must kill the group and prove grandchild gone. Capture only final 16KiB stdout/stderr tails. Unsupported group-control path -> BLOCKED status, not success.

- [ ] **Step 5: Implement/verify/commit**

```bash
node --test tests/safe-file.test.js tests/artifact-ingest.test.js tests/verification-policy.test.js tests/command-runner.test.js
npm test
git diff --check
git add src/safe-file.js src/artifact-ingest.js src/verification-policy.js src/command-runner.js \
  tests/safe-file.test.js tests/artifact-ingest.test.js tests/verification-policy.test.js tests/command-runner.test.js
git commit -m "feat(factory): bound artifact and verification execution"
```

---

### Task 6: Herdr dispatch, prompt ambiguity, settlement and atomic finalization

**Files:**
- Create: `src/herdr.js`
- Create: `src/turn-launcher.js`
- Create: `src/recovery.js`
- Test: `tests/herdr.test.js`
- Test: `tests/turn-launcher.test.js`
- Test: `tests/recovery.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `createHerdrClient(runner)` with workspace/agent list/get/create/start/prompt/wait/read/close primitives required by v0.1.
- `reconcileTurnLaunch(...)`
- `settleAndFinalizeTurn({runId,expectedTurnId},deps)`
- `recoverRun({runId,lockNonce},deps)`
- `abandonActiveTurn({runId,turnId},deps)`

- [ ] **Step 1: Herdr parsing RED tests**

Use synthetic documented JSON shapes. Returned IDs must be parsed, never predicted. `blocked` != success; `unknown` != settled; timeout/stall -> inspect required.

- [ ] **Step 2: Deterministic launch RED tests**

Same turn -> same workspace label/agent name. Crash retry adopts matching workspace/agent and never starts duplicate.

- [ ] **Step 3: Prompt ambiguity RED tests**

Fake `agentPrompt` asserts `prompt_attempted` + prompt digest were durable before the call. Throw after recording one call. Retry with no proof of non-delivery must not call again. Definite non-delivery may call the same prompt one additional time only.

- [ ] **Step 4: Settlement RED tests**

Result exists while agent working -> active lease retained, no archive. Agent reaches settled state -> finalization begins.

- [ ] **Step 5: Atomic finalization crash-window RED tests**

Normal:

```text
ingest -> final snapshot -> archive+digest -> exact outbox deletion -> one atomic state write clears lease+changes phase
```

Crash fixtures:

```text
archive exists + outbox exists + active finalizing -> reuse archive, delete exact outbox, atomic transition
archive exists + outbox absent + active finalizing -> atomic transition only
archive digest mismatch -> BLOCKED
outbox deletion fails -> completed archive remains, active finalizing lease remains, BLOCKED
```

Assert `abandon-turn` rejects a turn with valid completed archive. Concurrent finalizers create one archive and one state transition.

- [ ] **Step 6: Cancellation RED test**

With `cancel_requested=true`, successful finalization's single atomic state write clears lease and goes directly `CANCELLED`, never `VERIFYING_WORK`/`VERIFYING_REVIEW`.

- [ ] **Step 7: Abandon RED tests**

Before completed archive: exact active turn + proven workspace close -> archive abandoned + atomic clear/CANCELLED; wrong turn or uncertain close -> reject/BLOCKED; no prompt resend.

- [ ] **Step 8: Verify and commit**

```bash
node --test tests/herdr.test.js tests/turn-launcher.test.js tests/recovery.test.js tests/turn-archive.test.js
npm test
git diff --check
git add src/herdr.js src/turn-launcher.js src/recovery.js src/cli.js \
  tests/herdr.test.js tests/turn-launcher.test.js tests/recovery.test.js
git commit -m "feat(factory): finalize prompt-safe specialist turns"
```

---

### Task 7: Worker verifier and failure taxonomy

**Files:**
- Create: `src/verifier.js`
- Test: `tests/verifier.test.js`

**Interface:**
- `verifyWorker({runManifest,taskSnapshot,configSnapshot,archivedTurn,protectedSourceBaseline},deps) -> {status:'pass'|'repairable_fail'|'integrity_block', artifact, digest}`

- [ ] **Step 1: RED archive/input preconditions**

Still-active/unfinalized/tampered archive or input snapshot digest mismatch -> integrity_block before commands.

- [ ] **Step 2: RED Git/scope matrix**

Fail integrity for wrong HEAD/branch, bad ancestry, forbidden changed path, committed outbox, protected source mismatch, unexpected task dirt.

- [ ] **Step 3: RED package lifecycle mutation**

Changing selected package script or pre/post hook relative to base -> integrity_block before package-manager execution.

- [ ] **Step 4: RED repository-command side effects**

```text
command exits 0 + creates dirt -> integrity_block
command exits 0 + clean new commit -> integrity_block
command exits 0 + reset HEAD -> integrity_block
command changes main/other ref/config/hooks/source checkout -> integrity_block
command timeout with proven group termination -> repairable_fail or failed check according to policy
cannot prove process group termination -> integrity_block
```

A plain test/typecheck nonzero with all integrity invariants intact -> `repairable_fail`.

- [ ] **Step 5: GREEN evidence**

PASS writes canonical verification artifact bound to run input digests, worker archive digest, verified commit, protected-source baseline digest, command exit/timing metadata.

- [ ] **Step 6: Verify/commit**

```bash
node --test tests/verifier.test.js tests/verification-policy.test.js tests/source-guard.test.js tests/command-runner.test.js
npm test
git diff --check
git add src/verifier.js tests/verifier.test.js
git commit -m "feat(factory): verify settled worker commits"
```

---

### Task 8: Reviewer clone, review verification, repair evidence, arbiter bundle

**Files:**
- Create: `src/review-clone.js`
- Create: `src/review-guard.js`
- Create: `src/review-verifier.js`
- Create: `src/repair.js`
- Create: `src/arbiter-bundle.js`
- Test: `tests/review-clone.test.js`
- Test: `tests/review-guard.test.js`
- Test: `tests/review-verifier.test.js`
- Test: `tests/repair.test.js`
- Test: `tests/arbiter-bundle.test.js`

**Interfaces:**
- `makeReviewClonePlan(...)`
- `reconcileReviewClone(plan,sourceRepo,runner)`
- `assertReviewCloneIntegrity(before,after,expectedOutbox)`
- `verifyReview({reviewerArchive,workerVerificationDigest,...})`
- `recordRepair({reviewVerification,repairInput},deps)`
- `makeArbiterBundle(...)`

- [ ] **Step 1: Reviewer clone RED tests**

Owner marker must exist before clone invocation. Use real temp repo to prove `--no-local --no-checkout`, exact detached commit, origin removed, common Git dir internal, status clean.

Retry exact clone adopts; wrong marker/head/origin/partial clone -> BLOCKED, no auto repair/alternate path.

- [ ] **Step 2: Reviewer evidence RED tests**

Reviewer request binds exact worker verification digest. Settled reviewer uses same finalizing protocol from Task 6.

- [ ] **Step 3: Verdict consistency RED tests**

```js
test('PASS with IMPORTANT finding is invalid evidence', async () => {
  const result = fixtureReview({ verdict:'PASS', findings:[{
    severity:'IMPORTANT', material:true, location:'x:1', problem:'bad', required_fix:'fix'
  }]});
  await assert.rejects(() => verifyReview({ reviewerArchive: result, ...deps }), /contradictory/);
});
```

PASS + MINOR/INFO with `material:false` is allowed.

- [ ] **Step 4: Review-verification digest RED test**

Tamper reviewer archive/result after digest -> reject. Valid review writes canonical review-verification artifact/digest.

- [ ] **Step 5: Repair RED tests**

Only current validated FAIL accepted. Repair schema cannot add/change allowed paths, trust, verification policy, base SHA, target repo. Repair writes canonical digest; next worker request must reference it. Tamper later -> reject.

- [ ] **Step 6: Arbiter bundle RED tests**

Owner marker before population. Bundle contains immutable summary/scope/classification, commit/evidence/repair digests/findings/history/question; must not contain source/worktree paths, remotes, `.git`, or secrets.

- [ ] **Step 7: Verify/commit**

```bash
node --test tests/review-clone.test.js tests/review-guard.test.js tests/review-verifier.test.js \
  tests/repair.test.js tests/arbiter-bundle.test.js
npm test
git diff --check
git add src/review-clone.js src/review-guard.js src/review-verifier.js src/repair.js src/arbiter-bundle.js \
  tests/review-clone.test.js tests/review-guard.test.js tests/review-verifier.test.js tests/repair.test.js tests/arbiter-bundle.test.js
git commit -m "feat(factory): chain isolated review evidence"
```

---

### Task 9: Controller loop, final freshness, cleanup, doctor and contracts

**Files:**
- Create: `src/freshness.js`
- Create: `src/controller.js`
- Create: `src/cleanup.js`
- Create: `src/doctor.js`
- Create: `prompts/worker.md`
- Create: `prompts/reviewer.md`
- Create: `prompts/arbiter.md`
- Create: `skills/mighty-factory-orchestrator/SKILL.md`
- Test: `tests/freshness.test.js`
- Test: `tests/controller.test.js`
- Test: `tests/cleanup.test.js`
- Test: `tests/doctor.test.js`
- Test: `tests/contracts.test.js`
- Modify: `src/cli.js`

**Interfaces:**
- `createController(deps)` exposes every public operation from the spec.
- `runFinalFreshness(runId,deps) -> {ok,evidence}`
- `cleanupRun({runId,removeTaskWorktree=false},deps)`
- `runDoctor({configPath,env},deps)`

- [ ] **Step 1: Controller happy-path RED test**

Exercise exact phases:

```text
PLAN -> READY -> PREPARING -> WORKING
worker settled/finalized -> VERIFYING_WORK
verification PASS -> REVIEWING
reviewer settled/finalized -> VERIFYING_REVIEW
review verification PASS -> freshness PASS -> DONE
```

- [ ] **Step 2: Cancellation RED tests**

Cancel before active -> CANCELLED. Cancel during worker/reviewer -> safe finalization atomic state write goes CANCELLED, with no verification/verdict/new turn afterward.

- [ ] **Step 3: Failure routing RED tests**

```text
project test failure + integrity intact -> REPAIR_PENDING
protected source mutation -> BLOCKED
unsafe artifact -> BLOCKED
first review material FAIL -> REPAIR_PENDING
second -> ESCALATION_PENDING + arbiter + WORK_STRONG
third -> REPLAN_REQUIRED
```

- [ ] **Step 4: Freshness RED matrix**

After reviewer PASS but before DONE independently mutate:

```text
task branch
task worktree HEAD
task worktree file/source status
main/other/new ref
common config
hooks
worker/reviewer evidence bytes
```

Each must make freshness fail. No mutation -> atomic DONE transition.

- [ ] **Step 5: Cleanup RED tests**

Refuse active/finalizing resources and resources whose necessary evidence digest does not yet exist. Require exact owner marker digest. Task worktree retained by default; explicit terminal removal uses native Git without `--force`; dirty refusal reported; task branch retained.

- [ ] **Step 6: Doctor RED tests**

Check Node/Git/Herdr, config/gears/routes, roots/common Git, serializer, writable state/temp roots, lock/process identity, no-follow capability, sanitizer, process-group runner capability, reviewer clone isolation, foreman expectation vs verified session status.

- [ ] **Step 7: Prompt/skill contract tests**

Worker: exact IDs/task digest/repair digest/result path, commit before result, no merge/push/deploy.

Reviewer: exact verified commit + verification digest, independent clone, Git-metadata-only isolation, no repair mutation.

Arbiter: evidence bundle only.

Orchestrator skill: exact `/execute`, `/cancel`, explicit recover/abandon, no shadow lifecycle, no inferred DONE.

- [ ] **Step 8: Wire CLI and verify/commit**

```bash
node --test tests/freshness.test.js tests/controller.test.js tests/cleanup.test.js tests/doctor.test.js tests/contracts.test.js
npm test
git diff --check
git add src/freshness.js src/controller.js src/cleanup.js src/doctor.js src/cli.js \
  prompts/worker.md prompts/reviewer.md prompts/arbiter.md skills/mighty-factory-orchestrator/SKILL.md \
  tests/freshness.test.js tests/controller.test.js tests/cleanup.test.js tests/doctor.test.js tests/contracts.test.js
git commit -m "feat(factory): close deterministic orchestration loop"
```

---

### Task 10: End-to-end acceptance, README, qualification matrix

**Files:**
- Create: `README.md`
- Create: `tests/e2e-controller.test.js`
- Modify: `package.json`

- [ ] **Step 1: E2E happy path**

Real temporary Git repo/state/temp root + fake Herdr. Prove complete Review-12 flow to DONE.

- [ ] **Step 2: E2E regression matrix**

Same test file must cover:

```text
immutable config/task/classification/base after authorization
snapshot/evidence byte tampering
root overlap and linked-source common Git identity
classification route defaults/high-risk/ambiguity/three-failure cap
branch-created/no-worktree crash recovery
wrong owner marker
source HEAD/status/main/other/new-ref/config/hooks mutation
prompt ambiguity and abandonment
result before settlement
archive/outbox finalizing crash before delete
after delete before atomic state update
completed archive cannot be abandoned
stale outboxes absent across repair rounds
symlink component/final symlink/oversize artifact
package lifecycle verification rewrite
process-group timeout with surviving-child regression
clean HEAD/branch movement by verification command
repairable-vs-integrity failure routing
reviewer clone isolation and contradictory PASS rejection
repair ticket tampering
post-review freshness mutations
cleanup active/evidence guard
PID reuse recovery
main/protected refs unchanged
```

- [ ] **Step 3: README**

Document: trust model; exact authority commands; task/classification schemas; immutable snapshots; roots; lifecycle; cancellation/abandonment; resource ownership; prompt ambiguity; finalizing crash recovery; artifact safety; source protection; verification policy/timeouts; evidence chain; review consistency; escalation; freshness; cleanup; qualification labels.

- [ ] **Step 4: Final package scripts**

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

Expected: all implementation tests exit 0. Doctor may report documented provider readiness failures when actual local gear identifiers are not configured; that is not runtime qualification.

- [ ] **Step 6: Spec-to-code self-review**

At the same HEAD explicitly verify every Review-12 section has a code path and regression test. Search plan/code for `TODO`, `TBD`, placeholder commands, raw generic transition, `git reset --hard`, `git clean`, implicit push/deploy, and force worktree removal.

- [ ] **Step 7: Commit**

```bash
git add README.md package.json tests/e2e-controller.test.js
git commit -m "docs(factory): complete review-12 v0.1 acceptance gate"
```

---

## Review Gate After Every Task

After each Task 1–10:

1. run focused test and observe RED before implementation,
2. implement minimal GREEN,
3. run focused tests,
4. run full `npm test`,
5. run `git diff --check`,
6. inspect changed files and `git status --short`,
7. explicitly stage only task files,
8. commit,
9. request fresh independent code review before proceeding.

Do not batch tasks.

## Acceptance Labels

### `UNIT_INTEGRATION_COMPLETE`

May be reported only after the full local matrix passes at one HEAD, including real-temp-Git/fake-Herdr recovery, lifecycle, artifact, Git-protection, evidence, review, and freshness regressions.

### `HERDR_RUNTIME_QUALIFIED`

Requires a disposable provider-backed run on the user's Mac with installed Herdr/provider CLIs proving the same invariants: exact gear launch, prompt ambiguity, settlement/finalizing recovery, cancellation, no-follow artifact handling, process-group timeout behavior, protected common Git state, independent reviewer behavior, final freshness, escalation, and cleanup.

Without that provider-backed smoke run, do not claim runtime qualification.
