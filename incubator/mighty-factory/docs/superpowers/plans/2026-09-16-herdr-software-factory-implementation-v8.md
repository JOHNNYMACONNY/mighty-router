# Mighty Factory v0.1 Implementation Plan — Review 8

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Review-8 Mighty Factory as a dependency-free Node.js controller around Herdr with immutable authorization, crash-safe owned resources, prompt-safe settled turns, protected shared Git state, byte-digested evidence, bounded verification, isolated review, escalation caps, and a final freshness gate before DONE.

**Architecture:** Luna-Max owns planning/judgment. Exact `/execute` freezes config/task/classification/canonical repo/base SHA. The controller owns lifecycle and evidence. Workers run in one linked task worktree while source Git state is guarded. Reviewers run in independent clones. Arbiters receive evidence bundles only. Every decision-bearing artifact is canonicalized/digested.

**Tech Stack:** Node.js >= 20, ESM, `node:test`, built-in `fs/path/os/crypto/child_process`; native Git; Herdr CLI; no runtime npm dependencies.

**Spec:** `incubator/mighty-factory/docs/superpowers/specs/2026-09-16-herdr-software-factory-design-v8.md`

## Global Constraints

- Exact `/execute`; no public generic lifecycle transition.
- Trusted-local-repository only; not a sandbox.
- Freeze config/task/classification/repo/base SHA at authorization.
- Roots may not overlap source repo or each other.
- Every external resource gets a verified owner marker before mutation.
- Every state mutation uses run lock + process-start identity.
- Prompt attempt is persisted before prompt delivery; ambiguity never blindly resends.
- Result file != completion; settled agent -> archive+digest -> clear lease.
- Externally produced JSON is opened no-follow, regular-file-only, bounded, exact-byte digested.
- Protect source worktree, all preexisting refs, local config, hooks; only exact task branch may newly appear/move.
- Verification commands are structured, bounded by time/output, and post-recheck HEAD/ref/status/source baseline.
- Package script lifecycle definitions used for verification must equal pinned base definitions.
- Repair tickets are canonical/digested and cannot widen immutable task scope/policy.
- Reviewer clone is independent and clean before launch; review verification is explicit/digested.
- Final freshness gate rechecks task HEAD/branch/status/source baseline immediately before DONE.
- No implicit merge/push/deploy/production/billing/credential/install/destructive cleanup.

---

### Task 1 — CLI scaffold and schemas

**Create:** `package.json`, `bin/mighty-factory.js`, `src/cli.js`, `src/errors.js`, `src/task-contract.js`, `src/classify-schema.js`, tests.

- [ ] RED: help lists all high-level commands including `abandon-turn`, excludes `transition`; unknown command exit 2.
- [ ] RED: task accepts only trusted-local-repository, bounded paths, code verification; rejects traversal/absolute paths and malformed checks.
- [ ] RED: classification exact enums/boolean/finite numeric confidence without coercion.
- [ ] Implement minimal CLI/errors/schema.
- [ ] Focused tests, `npm test`, `git diff --check`, explicit stage/commit.

---

### Task 2 — Canonical authorization, roots, concrete gears

**Create:** `src/canonical-json.js`, `src/authorization.js`, `src/config.js`, `src/environment.js`, `src/route.js`, provider adapters, config example, tests.

**Interfaces:** canonical bytes/hash/read/write, `authorizeInputs`, `routeTask`, `buildSanitizedEnv`, adapter launch specs.

- [ ] RED canonical serializer: sorted recursive keys, preserved arrays, finite JSON only, exactly one newline.
- [ ] RED auth: temp Git repo commit A; authorize; mutate live task/config/classification and advance main B; pinned snapshots/base remain A.
- [ ] RED one-byte snapshot tamper rejected before parse.
- [ ] RED non-bare Git root canonicalization.
- [ ] RED root overlap in every containment direction rejected, including symlinked existing ancestor cases.
- [ ] RED deterministic task branch preexistence rejected at authorization.
- [ ] RED specialist gears concrete/resolved; foreman expectation separate.
- [ ] RED env sanitizer strips synthetic secret.
- [ ] Implement and verify/commit.

---

### Task 3 — Locks, lifecycle, evidence store, turn archives

**Create:** `src/process-identity.js`, `src/run-lock.js`, `src/state-machine.js`, `src/state-store.js`, `src/evidence.js`, `src/turn-archive.js`, tests.

- [ ] RED PID/start-token cases including PID reuse and ambiguous probe.
- [ ] RED stale lock recovery exact nonce + process identity; no force clear.
- [ ] RED cancellation/review-failure state transitions.
- [ ] RED active stages `claimed workspace_ready agent_started prompt_attempted result_seen settling`.
- [ ] RED archive exact-byte digest; tamper later rejected.
- [ ] RED active turn cannot clear without matching archive digest.
- [ ] RED concurrent settlement of same turn produces one archive/transition and second caller reuses it.
- [ ] Implement atomic state/evidence/event writes; verify/commit.

---

### Task 4 — Owned task worktree + protected source baseline

**Create:** `src/git.js`, `src/resource-plan.js`, `src/source-guard.js`, `src/artifacts.js`, tests.

- [ ] RED task owner marker exists and digest is durable before `git worktree add` is invoked.
- [ ] RED resource matrix: absent branch/path create; existing valid unattached branch attach; attached elsewhere block; incompatible block; exact owned adopt; wrong/tampered marker block; no alternate allocation.
- [ ] RED pinned base A used after main advances B.
- [ ] RED source baseline records source HEAD/status, sorted full refs map, local config exact bytes, hooks digest.
- [ ] RED changes to main/other ref/new ref/source checkout/config/hooks fail.
- [ ] RED exact task branch movement to expected commit is the only allowed ref delta.
- [ ] Implement no destructive Git commands; verify/commit.

---

### Task 5 — No-follow artifact ingestion + verification command policy

**Create:** `src/artifact-ingest.js`, `src/verification-policy.js`, `src/command-runner.js`, tests.

- [ ] RED safe artifact regular JSON <=1MiB returns exact-byte digest.
- [ ] RED symlink final file rejected.
- [ ] RED symlink in any parent component below owned root rejected.
- [ ] RED directory/FIFO/special file/oversize/path escape/unstable descriptor metadata/bad UTF-8/bad JSON/wrong IDs rejected.
- [ ] Implementation opens final file no-follow, reads through descriptor, compares pre/post `fstat`; never path-re-reads after checks.
- [ ] RED verification form allowlist only `npm-script pnpm-script yarn-script node-test node-check`.
- [ ] RED base vs reported `pre<script>/script/post<script>` mismatch rejects package-script check.
- [ ] RED command timeout config bounds 1–30 minutes; default 10.
- [ ] RED command runner streams into 16KiB stdout/stderr tails, times out and terminates/kills with bounded grace, no unbounded exec buffer.
- [ ] Implement/verify/commit.

---

### Task 6 — Worker verification and protected-state rechecks

**Create:** `src/verifier.js`, tests.

- [ ] RED refuses active/unarchived/tampered worker turn.
- [ ] RED immutable input digest mismatch fails before checks.
- [ ] RED bad commit/HEAD/branch/ancestry/path/outbox/diff hygiene/initial dirt fails.
- [ ] RED source baseline mismatch before checks fails.
- [ ] RED package verification lifecycle rewrite fails before package manager.
- [ ] RED check exit 0 creating dirt fails final status.
- [ ] RED check exit 0 creating clean commit/resetting HEAD fails post-command HEAD+task-ref equality.
- [ ] RED check mutating main/other ref/new ref/config/hooks/source checkout fails protected-source final check.
- [ ] RED timeout fails verification and persists timeout metadata without env values.
- [ ] GREEN artifact binds verified commit, worker archive digest, three immutable-input digests, protected-source baseline digest; artifact itself canonical/digested.
- [ ] Implement exact Review-8 order; verify/commit.

---

### Task 7 — Herdr dispatch, settlement, recovery, abandonment

**Create:** `src/herdr.js`, `src/turn-launcher.js`, `src/recovery.js`, tests.

- [ ] RED Herdr IDs from returned JSON, unknown not success, blocked blocker, stall/timeout inspect-required.
- [ ] RED deterministic workspace/agent reused after crash, no duplicate start.
- [ ] RED prompt bytes/digest + `prompt_attempted` persisted before call.
- [ ] RED ambiguous call never resend; definite non-delivery same bytes at most once.
- [ ] RED result while agent working does not clear lease.
- [ ] RED settled agent -> descriptor-safe ingest -> final role snapshot -> archive+digest -> clear lease.
- [ ] RED concurrent waiter reuses existing archive.
- [ ] RED reviewer writes PASS then mutates clone before settlement -> final snapshot catches.
- [ ] RED abandonment exact turn/workspace only, no resend, preserves checkout, archive abandoned, cancel run; uncertain close leaves active/BLOCKED.
- [ ] RED stale-lock recovery preserves turn/prompt/resource identity.
- [ ] Verify/commit.

---

### Task 8 — Reviewer clone, review verification, repair evidence, arbiter

**Create:** `src/review-clone.js`, `src/review-guard.js`, `src/review-verifier.js`, `src/repair.js`, `src/arbiter-bundle.js`, tests.

- [ ] RED owner marker before clone; marker tamper blocks adoption.
- [ ] RED `clone --no-local --no-checkout`, detached exact commit, origin removed, common dir internal, initial status clean.
- [ ] RED retry exact clone adopts; partial/mismatched clone blocks.
- [ ] RED reviewer request binds exact worker verification digest.
- [ ] RED reviewer archive binds reviewed commit + verification digest; post-settlement delta exact outbox only.
- [ ] RED review-verification writes canonical digest; altered reviewer archive/result fails.
- [ ] RED `record-repair` only accepts current FAIL, cannot change immutable scope/policy, canonicalizes/digests ticket; mutation after record rejected; next worker request binds repair digest.
- [ ] RED arbiter parent marker before bundle; bundle contains exact evidence/repair digests and omits source/worktree/remotes/secrets/.git.
- [ ] Verify/commit.

---

### Task 9 — Controller, final freshness, cleanup, doctor, contracts

**Create:** `src/controller.js`, `src/freshness.js`, `src/cleanup.js`, `src/doctor.js`, prompts/skill, tests.

- [ ] RED happy path through worker archive -> verification digest -> reviewer archive -> review-verification PASS -> final freshness -> DONE.
- [ ] RED live input/base mutations after auth do not change run; snapshot/evidence tampering blocks.
- [ ] RED duplicate dispatch/settlement no duplicate effects.
- [ ] RED cancellation semantics and abandonment.
- [ ] RED first FAIL repair/default worker; second FAIL arbiter/strong worker; third stop.
- [ ] RED final freshness detects task branch move after reviewer PASS.
- [ ] RED final freshness detects task worktree HEAD move/dirt after reviewer PASS.
- [ ] RED final freshness detects source main/other-ref/config/hooks/status mutation after reviewer PASS.
- [ ] RED cleanup refuses active resources and resources whose needed evidence is not yet digested; wrong marker/unowned path rejected; dirty task worktree not forced.
- [ ] RED doctor checks roots, serializer, lock/process identity, Herdr, gears, env sanitizer, no-follow capability on macOS, bounded runner, reviewer isolation; foreman expected vs verified truthfulness.
- [ ] Contracts state trusted model/no push-deploy authority/Git-metadata-only reviewer isolation.
- [ ] Wire CLI including `record-repair`, `abandon-turn`; verify/commit.

---

### Task 10 — E2E and runtime qualification contract

**Create:** `README.md`, `tests/e2e-controller.test.js`; modify `package.json`.

- [ ] Happy path with real temp Git + fake Herdr.
- [ ] E2E regressions cover:
  - immutable snapshots/base and root overlap,
  - owner marker-before-mutation and marker tamper,
  - branch-only crash recovery,
  - source main/other-ref/new-ref/config/hooks/status mutation,
  - prompt ambiguity/abandonment,
  - result-before-settlement + concurrent settlement,
  - symlink component/final symlink/oversize artifact,
  - evidence/repair tamper,
  - package lifecycle rewrite,
  - verification timeout/output cap,
  - clean HEAD/task-ref movement by repo check,
  - reviewer independent clone + review archive tamper,
  - final branch/head/status/source mutation after PASS,
  - cleanup evidence/active guard,
  - PID reuse,
  - escalation cap,
  - protected source main unchanged.
- [ ] README documents all Review-8 guarantees and trust limitations.
- [ ] Final matrix:

```bash
npm test
npm run test:e2e
git diff --check
node bin/mighty-factory.js help
node bin/mighty-factory.js doctor --config ./factory.config.json
```

- [ ] Self-review spec coverage at same HEAD; explicitly stage/commit.

## Review Gate

After every task: focused RED -> focused GREEN -> full `npm test` -> `git diff --check` -> inspect status/diff -> explicitly stage -> commit -> fresh independent code review. Never batch tasks.

## Qualification Labels

`UNIT_INTEGRATION_COMPLETE` requires the full local matrix at one HEAD.

`HERDR_RUNTIME_QUALIFIED` additionally requires disposable provider-backed testing on the user's Mac proving installed-Herdr settlement, prompt ambiguity, artifact no-follow behavior, verification runtime bounds, protected source state, final freshness, and escalation/cleanup invariants. Without that run, do not claim runtime qualification.
