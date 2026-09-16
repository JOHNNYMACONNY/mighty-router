# Mighty Factory v0.1 Implementation Plan — Review 7

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Review-7 Mighty Factory as a dependency-free Node.js controller around Herdr with immutable authorization inputs, crash-safe resource ownership, prompt-safe settled turns, protected source Git state, byte-digested evidence, independent verification, isolated review, bounded escalation, and safe cleanup.

**Architecture:** The Luna-Max foreman owns planning/judgment. At exact `/execute`, the controller freezes config/task/classification/canonical repo/base SHA. Thereafter only pinned snapshots drive routing and authority. Workers use one linked task worktree but the controller snapshots and protects shared source-repository state. Reviewers use independent clones and arbiters use evidence bundles. Result artifacts are accepted only after agent settlement and turn archival.

**Tech Stack:** Node.js >= 20, ESM, built-in `node:test`, `fs`, `path`, `os`, `crypto`, `child_process`; native Git; Herdr CLI; no runtime npm dependencies.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-16-herdr-software-factory-design-v7.md`

## Global Constraints

- Work only under `incubator/mighty-factory/` on `incubator/mighty-factory-v0`.
- TDD every behavior: RED first, then minimal GREEN.
- No runtime npm dependencies.
- Exact `/execute` only; no generic public transition command.
- Freeze config/task/classification/canonical repo/base SHA at authorization.
- State/temp roots must not overlap each other or the canonical source repo.
- Every state mutation uses per-run locking with process-start identity.
- Every external resource has deterministic persisted ownership before mutation.
- Prompt bytes/digest and `prompt_attempted` are persisted before delivery.
- Ambiguous delivery is never blindly resent.
- Result file does not end a turn: agent settles, archive is written/digested, then lease clears.
- Artifacts must be regular files <= 1 MiB; symlinks/special files rejected.
- Worker verification consumes archived settled evidence only.
- Protect source worktree, refs, local config, hooks, and exact task branch identity.
- Recheck HEAD/ref/source baseline after repository verification commands.
- Package-script lifecycle definitions used for verification must match pinned base definitions.
- Reviewer clone is independent and origin-free; arbiter gets evidence only.
- Cleanup refuses active/evidence-needed resources and never force-removes dirty task worktrees.
- No implicit merge, push, deploy, production mutation, billing action, credential change, package installation, or permission approval.

---

## File Structure

```text
incubator/mighty-factory/
  README.md
  package.json
  factory.config.example.json
  bin/mighty-factory.js
  src/
    cli.js
    errors.js
    ids.js
    canonical-json.js
    authorization.js
    config.js
    environment.js
    route.js
    provider-adapters/{index,codex,cline,antigravity}.js
    process-identity.js
    run-lock.js
    state-machine.js
    state-store.js
    evidence.js
    turn-archive.js
    artifact-ingest.js
    git.js
    resource-plan.js
    source-guard.js
    verification-policy.js
    command-runner.js
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
  prompts/{worker,reviewer,arbiter}.md
  skills/mighty-factory-orchestrator/SKILL.md
  tests/*.test.js
```

---

### Task 1: Scaffold CLI and input schemas

**Files:** Create `package.json`, `bin/mighty-factory.js`, `src/cli.js`, `src/errors.js`, `src/task-contract.js`, `src/classify-schema.js`; tests `cli.test.js`, `task-contract.test.js`, `classify-schema.test.js`.

**Interfaces:**
- `main(argv, io = {stdout: process.stdout, stderr: process.stderr}) -> Promise<number>`
- `validateTaskContract(value, classification)`
- `validateClassification(value)`

- [ ] Write failing CLI test requiring `doctor print-config route authorize-execute cancel recover-run abandon-turn prepare-run dispatch-worker verify-worker dispatch-reviewer verify-review dispatch-arbiter record-repair status cleanup` and forbidding `transition`.
- [ ] Write failing task tests for exact trust mode, non-empty code `allowed_paths`, code verification checks, and rejection of absolute/traversal paths.
- [ ] Write failing classification tests for exact enums and finite numeric confidence `[0,1]` without coercion.
- [ ] Run focused tests and observe RED.
- [ ] Implement minimal package/CLI/errors/schema validation.
- [ ] Run focused tests, `npm test`, `git diff --check`.
- [ ] Explicitly stage Task-1 files and commit `feat(factory): scaffold authority contracts`.

---

### Task 2: Canonical immutable authorization and root separation

**Files:** Create `src/canonical-json.js`, `src/authorization.js`, `src/config.js`, `src/environment.js`, `src/route.js`, provider adapters, `factory.config.example.json`; tests `canonical-json.test.js`, `authorization.test.js`, `config.test.js`, `environment.test.js`, `route.test.js`, `provider-adapters.test.js`.

**Interfaces:**
- `canonicalJsonBytes(value) -> Buffer`
- `sha256Bytes(bytes) -> sha256:<hex>`
- `writeSnapshotFile(path,value) -> {digest}`
- `readVerifiedSnapshot(path,digest) -> value`
- `authorizeInputs({taskPath,classificationPath,configPath}, deps) -> runManifest`
- `buildSanitizedEnv(source, allowedNames, fixed)`
- `routeTask({classification,state,configSnapshot})`

- [ ] RED: insertion-order-independent canonical bytes; array order preserved; one trailing newline; non-finite/non-JSON rejected.
- [ ] RED: authorization temp repo pins commit A, then mutable inputs and `main` advance to B; pinned snapshots still return original config/task/classification and base A.
- [ ] RED: one-byte snapshot tamper fails before parsing.
- [ ] RED: canonical target repo must be non-bare and equal Git top-level after normalization.
- [ ] RED: `state_root`/`temp_root` reject overlap with each other or source repo in either containment direction.
- [ ] RED: deterministic task branch name must not preexist at authorization.
- [ ] RED: specialist gears require resolved concrete argv; foreman expectation stays separate.
- [ ] RED: environment sanitizer strips synthetic secret not allowlisted by name.
- [ ] Implement authorization transaction and pinned routing.
- [ ] Verify focused/full tests and commit `feat(factory): freeze run authority inputs`.

---

### Task 3: Locking, process identity, lifecycle, byte-digested turn archives

**Files:** Create `src/process-identity.js`, `src/run-lock.js`, `src/state-machine.js`, `src/state-store.js`, `src/evidence.js`, `src/turn-archive.js`; tests corresponding.

**Interfaces:**
- `getProcessIdentity(pid, runner)`
- `withRunLock(runDir, command, fn, deps)`
- `recoverDeadRunLock(runDir,{expectedNonce},deps)`
- `writeCanonicalEvidence(path,value) -> {digest}`
- `readVerifiedEvidence(path,digest) -> value`
- `archiveTurn(...) -> {record,digest}`

- [ ] RED: PID absent; same PID/same start token live; same PID/different token reused; unsupported probe ambiguous.
- [ ] RED: lock recovery wrong nonce/live owner reject; reused/absent owner recover; ambiguous probe fails with manual instructions.
- [ ] RED: cancellation semantics and review-failure progression.
- [ ] RED: active stages `claimed workspace_ready agent_started prompt_attempted result_seen settling`.
- [ ] RED: turn cannot clear without a matching archived record/digest.
- [ ] RED: altering archived `turn.json` bytes after archive makes later read fail digest validation.
- [ ] RED: two concurrent settlement attempts return one existing archive rather than applying transition twice.
- [ ] Implement atomic state/evidence/archive writes and event history.
- [ ] Verify and commit `feat(factory): persist guarded lifecycle evidence`.

---

### Task 4: Crash-safe task worktree and protected source baseline

**Files:** Create `src/git.js`, `src/resource-plan.js`, `src/source-guard.js`, `src/artifacts.js`; tests `git.test.js`, `resource-plan.test.js`, `source-guard.test.js`, `artifacts.test.js`.

**Interfaces:**
- `makeTaskResourcePlan({runId,tempRoot,baseSha,branch})`
- `reconcileTaskWorktree(plan,canonicalRepo,runner)`
- `captureProtectedSourceBaseline({repo,taskBranch},deps) -> {record,digest}`
- `assertProtectedSourceUnchanged(baseline,{expectedTaskCommit},deps)`

- [ ] RED: owned task parent marker is written before any `git worktree add` call.
- [ ] RED resource matrix: branch/path absent create once; branch exists at expected base unattached attaches exact path; attached elsewhere blocks; incompatible branch blocks; exact marked worktree adopts; wrong/missing owner marker blocks; retry never allocates alternate path.
- [ ] RED: authorization-pinned base A remains task base after source `main` advances B.
- [ ] RED baseline captures source HEAD/status, all refs except task branch, local config bytes, hooks digest.
- [ ] RED: changing source `main`, another ref, source checkout file, local config, or hooks causes protected-source failure.
- [ ] RED: moving only exact task branch to expected commit is allowed; unexpected new ref is rejected.
- [ ] Implement argv-only Git inspection/operations with no reset/stash/clean.
- [ ] Verify and commit `feat(factory): protect shared source repository state`.

---

### Task 5: Safe artifact ingestion and verification policy

**Files:** Create `src/artifact-ingest.js`, `src/verification-policy.js`, `src/command-runner.js`; tests `artifact-ingest.test.js`, `verification-policy.test.js`.

**Interfaces:**
- `ingestJsonArtifact({expectedPath,destination,maxBytes=1048576,expected})`
- `compileVerificationCommand(check,configSnapshot,repoRoot)`
- `readPinnedPackageLifecycle({repo,baseSha,script,runner})`

- [ ] RED artifact: exact regular JSON file accepted and exact-byte digest returned.
- [ ] RED artifact: symlink, directory, FIFO/special type, oversized file, path escape, unstable-size read, malformed UTF-8/JSON, wrong IDs are rejected.
- [ ] RED verification forms only allow `npm-script pnpm-script yarn-script node-test node-check` and safe relative paths.
- [ ] RED package script: base `pretest/test/posttest` equal reported commit passes; changing any selected lifecycle definition fails before execution.
- [ ] RED: script changes intentionally under task still cannot use that package-script check; explicit node check/test can be used instead.
- [ ] Implement no-shell command runner and output cap helper.
- [ ] Verify and commit `feat(factory): validate artifacts and verification commands`.

---

### Task 6: Worker verifier with post-command identity rechecks

**Files:** Create `src/verifier.js`; test `tests/verifier.test.js`.

**Interface:** `verifyWorker({runManifest,taskSnapshot,configSnapshot,archivedTurn,protectedSourceBaseline},deps)`.

- [ ] RED: still-active or undigested worker archive rejected.
- [ ] RED: snapshot/evidence digest mismatch rejected before commands.
- [ ] RED: forbidden committed path, committed outbox, bad ancestry, initial dirty state, `git diff --check` failure rejected.
- [ ] RED: synthetic secret absent from check environment.
- [ ] RED: check exit 0 but creates untracked/tracked dirt -> final-status failure.
- [ ] RED: check exit 0 but creates a new commit or `reset --hard` so worktree is clean -> failure because HEAD/task branch no longer equal reported commit.
- [ ] RED: check mutates protected source ref/config/hooks/source checkout -> failure.
- [ ] RED: selected package lifecycle definition rewrite -> failure before package-manager execution.
- [ ] RED: valid verification writes canonical verification artifact with digest bound to commit, worker archive digest, and three run-input digests.
- [ ] Implement exact order from spec, including protected-source check before and after repo commands.
- [ ] Verify and commit `feat(factory): verify immutable worker result identity`.

---

### Task 7: Herdr dispatch, prompt ambiguity, settlement, recovery, abandonment

**Files:** Create `src/herdr.js`, `src/turn-launcher.js`, `src/recovery.js`; tests corresponding.

**Interfaces:**
- `createHerdrClient(runner)`
- `reconcileTurnLaunch(...)`
- `settleAndArchiveTurn(...)`
- `recoverRun(...)`
- `abandonActiveTurn(...)`

- [ ] RED: returned Herdr IDs parsed from JSON; blocked != success; unknown != settlement; timeout/stall -> inspect-required.
- [ ] RED: deterministic workspace/agent identity reused after crash; no duplicate start.
- [ ] RED: prompt bytes/digest + `prompt_attempted` persisted before prompt API call.
- [ ] RED: crash after prompt API ambiguity never resends; definite non-delivery permits same bytes once only.
- [ ] RED: result file while agent still working does not archive/clear lease.
- [ ] RED: settled worker captures final task status, safely ingests artifact, archives+digests turn, then clears lease.
- [ ] RED: reviewer PASS followed by clone mutation before settlement is caught in final snapshot.
- [ ] RED: concurrent settlement waiter gets existing verified archive, no second transition.
- [ ] RED abandon: wrong turn rejects; successful exact workspace close archives `abandoned`, clears lease, cancels run, preserves task checkout; close ambiguity leaves BLOCKED/active; no prompt resend.
- [ ] RED stale-lock recovery reuses existing turn/resource/prompt stage.
- [ ] Verify and commit `feat(factory): settle or abandon prompt-safe turns`.

---

### Task 8: Independent reviewer clone, arbiter bundle, review evidence chain

**Files:** Create `src/review-clone.js`, `src/review-guard.js`, `src/arbiter-bundle.js`; tests corresponding.

- [ ] RED reviewer parent marker exists before clone call.
- [ ] RED reviewer clone uses `--no-local --no-checkout`, detached verified commit, removes origin, common Git dir internal.
- [ ] RED exact owned clone adopts on retry; partial/wrong marker/wrong HEAD/origin-present mismatch blocks rather than auto-repairs.
- [ ] RED review request contains exact verification artifact digest.
- [ ] RED reviewer final archived evidence requires same verified commit and verification digest.
- [ ] RED only expected review outbox may differ after settlement.
- [ ] RED arbiter marker exists before bundle population; bundle omits target/source paths, remotes, secrets, `.git`; includes exact evidence digests.
- [ ] RED review-verification artifact is canonical/digested and PASS cannot be applied from altered reviewer archive.
- [ ] Verify and commit `feat(factory): isolate and chain review evidence`.

---

### Task 9: Controller loop, escalation, cleanup, doctor, contracts

**Files:** Create `src/controller.js`, `src/cleanup.js`, `src/doctor.js`, prompts, orchestrator skill; tests `controller.test.js`, `cleanup.test.js`, `doctor.test.js`, `contracts.test.js`.

- [ ] RED happy path: authorize snapshots -> prepare marked task worktree -> capture source baseline -> worker settle/archive -> verify+digest -> reviewer settle/archive -> review verify+digest -> DONE.
- [ ] RED live mutable config/task/classification/base changes after authorization do not alter run.
- [ ] RED duplicate dispatch/settlement do not duplicate work or transitions.
- [ ] RED cancel before active turn immediate; cancel with active turn lets safe handoff only then cancels before verification/new turn.
- [ ] RED escalation: first FAIL repair/default worker; second FAIL evidence-only arbiter then strong worker; third FAIL `REPLAN_REQUIRED`.
- [ ] RED cleanup refuses active turn and evidence-needed resources; wrong ownership marker/unrecorded path rejected; non-force dirty task-worktree removal reported; task branch retained.
- [ ] RED doctor checks deterministic serializer, roots, locks/process identity, Herdr, concrete gears, env sanitizer, artifact regular-file fixture, reviewer isolation; foreman expected vs current-session-verified remains truthful.
- [ ] RED prompt contracts state no push/merge/deploy, trust limitation, exact IDs/outboxes, reviewer Git-metadata-only isolation.
- [ ] Wire all public CLI operations including `abandon-turn`.
- [ ] Verify and commit `feat(factory): close guarded orchestration loop`.

---

### Task 10: E2E acceptance, README, qualification

**Files:** Create `README.md`, `tests/e2e-controller.test.js`; modify `package.json`.

- [ ] Build fake-Herdr + real-temp-Git happy-path E2E covering immutable snapshots, ownership markers, worker archive, source baseline, verification digest, independent reviewer, PASS, DONE.
- [ ] Add E2E regressions:
  - mutable input/base drift ignored and snapshot tampering rejected,
  - root overlap rejected,
  - branch-created/no-worktree crash reconciled,
  - wrong task parent marker blocks,
  - source main/other ref/config/hooks/source checkout mutation blocks,
  - duplicate dispatch and settlement are idempotent,
  - prompt ambiguity no resend; explicit abandonment works,
  - symlink/oversized artifact rejected,
  - package verification lifecycle rewrite rejected,
  - repository check that cleanly moves HEAD rejected,
  - repository check mutating protected source metadata rejected,
  - reviewer clone no origin/common-dir sharing and archive tamper rejected,
  - arbiter evidence chain exact,
  - cleanup active/evidence guard,
  - PID reuse handling,
  - second failure arbiter+strong worker; third stops,
  - source main remains unchanged.
- [ ] README documents trust model, immutable inputs, root rules, protected source baseline, verification definition integrity, artifact safety, prompt ambiguity, abandonment, settlement/archive evidence chain, review isolation, escalation, cleanup, qualification labels.
- [ ] Package scripts:

```json
{
  "scripts": {
    "test": "node --test tests/*.test.js",
    "test:e2e": "node --test tests/e2e-controller.test.js",
    "doctor": "node bin/mighty-factory.js doctor"
  }
}
```

- [ ] Run final matrix:

```bash
cd incubator/mighty-factory
npm test
npm run test:e2e
git diff --check
node bin/mighty-factory.js help
node bin/mighty-factory.js doctor --config ./factory.config.json
```

- [ ] Self-review every Review-7 spec requirement against code/tests at one HEAD.
- [ ] Explicitly stage Task-10 files and commit `docs(factory): complete review-7 v0.1 acceptance gate`.

---

## Review Gate After Every Task

After each task:

1. focused RED observed before implementation,
2. focused GREEN,
3. full `npm test`,
4. `git diff --check`,
5. inspect `git status --short` and changed files,
6. explicitly stage only task files,
7. commit,
8. fresh independent code review before the next task.

Do not batch tasks.

## Acceptance Labels

### `UNIT_INTEGRATION_COMPLETE`

Only after the full local matrix passes at one HEAD, including fake-Herdr crash/recovery, protected-source, evidence-digest, artifact-safety, and verification-identity regressions.

### `HERDR_RUNTIME_QUALIFIED`

Requires a disposable provider-backed run on the user's Mac proving the same invariants against the installed Herdr/provider CLIs, including settlement semantics and source Git protection. Without that smoke run, do not claim runtime qualification.
