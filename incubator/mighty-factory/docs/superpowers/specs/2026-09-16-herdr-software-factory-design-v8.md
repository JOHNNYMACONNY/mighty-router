# Mighty Factory — Canonical v0.1 Design (Review 8)

**Status:** Canonical design for implementation  
**Date:** 2026-09-16  
**Supersedes:** Review-7 and all earlier Mighty Factory drafts  
**Incubation:** `mighty-router` branch `incubator/mighty-factory-v0` only

## 1. Purpose

Mighty Factory is a local Herdr-backed software-factory controller. The human-facing Codex/Luna-Max session plans and judges. Deterministic Node.js code owns authorization, immutable inputs, state, recovery, routing, artifact/evidence integrity, Git protection, verification, review, escalation, cleanup, and completion.

Default flow:

```text
PLAN -> exact /execute
 -> immutable authorization snapshots + canonical repo/base_sha
 -> crash-safe owned task worktree
 -> fresh worker -> settled archived turn
 -> controller verification + protected-source checks
 -> independent reviewer clone -> settled archived turn
 -> review verification
 -> PASS => fresh final freshness gate => DONE
 -> FAIL => repair / arbiter / stronger worker / third-failure stop
```

v0.1 is trusted-local-repository automation, **not** an OS/network security sandbox.

## 2. Non-negotiable authority boundaries

Factory never implicitly authorizes merge, push, deploy, production mutation, billing, credentials changes, package installation, destructive cleanup, or permission approval.

Public authority commands include:

```text
authorize-execute
cancel
recover-run
abandon-turn
```

No public raw lifecycle transition exists.

Cancellation with no active turn is immediate. Cancellation with an active turn sets `cancel_requested`; the active turn may reach safe settlement but no subsequent mutation-capable step begins.

`abandon-turn --run <run_id> --turn <turn_id>` never retries a prompt. It closes only the exact owned Herdr workspace, requires closure/absence proof, archives the turn as abandoned, clears the lease, preserves filesystem evidence, and cancels the run. Failure to prove closure leaves the run BLOCKED.

## 3. Immutable authorization manifest

At `/execute`, under one controller transaction:

1. validate config/task/classification,
2. canonicalize target repo using realpath + Git top-level and require non-bare worktree support,
3. resolve `base_ref` immediately to `base_sha`,
4. validate `state_root` and `temp_root` are distinct/non-overlapping and neither overlaps the source repo,
5. allocate run/task IDs plus deterministic task branch/path; task branch must not preexist,
6. normalize config/task/classification; task snapshot embeds canonical repo + base SHA,
7. write canonical UTF-8 JSON bytes atomically,
8. SHA-256 exact written bytes,
9. persist all three input digests and base identity in `run.json`,
10. transition PLAN -> READY only after durable success.

Files:

```text
config.snapshot.json
task.snapshot.json
classification.snapshot.json
run.json
```

Every later command verifies exact snapshot bytes against manifest digests before parsing. Mutable source input files are never reread for decisions.

Canonical JSON recursively sorts object keys, preserves arrays, accepts finite JSON values only, uses no insignificant whitespace, and ends with exactly one newline.

## 4. Roots and ownership

Factory roots must not contain each other or the canonical source repo, and the source repo must not contain either root.

Every externally-mutated resource has a deterministic parent ownership marker written **before** external mutation. Ownership markers themselves are canonical JSON regular files, byte-digested in run state, and are verified before adoption/deletion.

Resources include:

```text
<temp>/<run>/task/.mighty-factory-owner.json
<temp>/<run>/task/repo/
<temp>/<run>/review/<turn>/.mighty-factory-owner.json
<temp>/<run>/review/<turn>/repo/
<temp>/<run>/arbiter/<turn>/.mighty-factory-owner.json
<temp>/<run>/arbiter/<turn>/bundle/
```

Wrong/missing/tampered owner marker blocks adoption or cleanup.

## 5. Locks and process identity

Every state-changing operation uses exclusive per-run locking. Lock metadata records nonce, PID, platform process-start token, controller-instance ID, timestamp, and command.

Recovery requires exact nonce plus process identity:

- absent PID => stale,
- same PID/same start token => live, reject,
- same PID/different token => PID reuse, stale,
- unavailable/ambiguous identity => fail closed with manual instructions,
- no force-clear CLI.

## 6. Turn dispatch, prompt ambiguity, settlement

Persist before external launch/prompt mutation:

- turn ID/role,
- deterministic workspace/agent identity,
- pinned gear launch spec,
- request artifact,
- exact prompt bytes + digest,
- expected result path.

Active stages:

```text
claimed
workspace_ready
agent_started
prompt_attempted
result_seen
settling
```

`prompt_attempted` is persisted before the external prompt call. Definite non-delivery may resend the exact persisted prompt at most once. Ambiguous delivery is never blindly retried; the run blocks and can be human-abandoned.

A result file does not finish a turn. The exact agent must reach locally-qualified settled state. Then under lock the controller:

1. revalidates run-input digests/turn identity,
2. safely ingests the result,
3. captures role-specific final state,
4. writes canonical `turns/<turn>/turn.json`,
5. hashes exact archive bytes and persists the archive digest,
6. clears the active lease,
7. performs exactly one deterministic transition.

Settlement is idempotent: concurrent waiters verify and reuse the existing archive rather than transition twice.

No later operation consumes an active turn.

## 7. Safe artifact/file ingestion

Worker/reviewer/arbiter results, owner markers, and other externally-produced JSON inputs are read through a no-follow safe-file primitive.

Requirements:

- expected path is lexically inside the owned root,
- every existing path component from owned root to file is inspected and symlink components are rejected,
- final file is opened with no-follow semantics where supported (`O_NOFOLLOW` on target macOS); unsupported platforms fail closed for provider-backed qualification,
- `fstat` on the opened descriptor proves regular file,
- max size 1 MiB for turn result artifacts,
- bounded read from the opened descriptor only,
- `fstat` identity/size checked before and after read,
- UTF-8 JSON parse only after bytes are captured,
- schema/run/task/turn/role/commit expectations validated,
- exact bytes SHA-256 hashed and atomically copied into durable state.

Path re-resolution or ordinary `readFile(path)` after the safety checks is forbidden.

## 8. Evidence integrity chain

Canonical exact-byte evidence artifacts are hashed and later consumers verify bytes before parse/use.

Chain:

```text
worker turn archive digest
 -> worker verification artifact digest
 -> reviewer request binds verification digest
 -> reviewer turn archive digest
 -> review-verification artifact digest
 -> final freshness gate
```

Repair tickets are also decision-bearing evidence.

`record-repair --run <id> --file <repair.json>` must:

- consume only a current validated review FAIL artifact,
- validate bounded repair schema,
- reject changes to immutable scope/allowed paths/policy,
- canonicalize/write the repair ticket into durable state,
- hash exact bytes,
- persist `repair_digest`,
- next worker request binds the exact repair digest.

A modified repair artifact after recording is rejected by digest verification.

Arbiter inputs include exact evidence/repair digests; arbiter output is archived/digested like any other settled turn.

## 9. Crash-safe task worktree

Task parent marker is written before Git mutation. Task branch is known absent at authorization.

Reconciliation:

1. path absent + branch absent -> create exact branch/worktree at pinned base,
2. path absent + expected branch exists at valid recorded base/descendant and unattached -> attach exact branch at exact path,
3. branch attached elsewhere -> BLOCKED,
4. incompatible branch/history -> BLOCKED,
5. exact owned recorded worktree -> adopt,
6. wrong marker/non-worktree/alternate path -> BLOCKED,
7. retry never invents a new branch/path.

## 10. Protected source repository

Because worker task worktree shares Git common metadata with the source repo, Factory captures a protected baseline after task preparation and before first worker launch:

- source worktree HEAD,
- source worktree full porcelain status,
- complete Git ref map (sorted name -> object ID),
- local common repository config exact bytes/digest,
- `.git/hooks` deterministic tree digest.

The exact task branch is the **only** ref allowed to be absent from the initial map and later appear/move. No vague administrative-ref exception exists.

After every worker settlement, after every repository verification command sequence, and at final DONE freshness gate:

- source HEAD/status equal baseline,
- every baseline ref except exact task branch unchanged,
- no new refs except exact task branch,
- local config unchanged,
- hooks unchanged,
- exact task branch equals the currently expected verified commit.

Mismatch BLOCKS; no automatic reset/repair.

This is final-state detection, not sandbox prevention.

## 11. Verification policy

Supported task checks:

```text
npm-script
pnpm-script
yarn-script
node-test
node-check
```

No shell/arbitrary executable/install/migrate/deploy/destructive-Git forms.

### 11.1 Package script integrity

For package-script checks, the root `package.json` `pre<script>`, `<script>`, `post<script>` definitions at the reported commit must exactly equal definitions at pinned `base_sha`. Otherwise verification fails before package-manager execution.

### 11.2 Command runtime bounds

Each verification command has a pinned timeout in the config snapshot. v0.1 defaults to 10 minutes and config may choose 1–30 minutes.

Command runner must:

- spawn without shell interpolation,
- stream stdout/stderr into bounded ring buffers (16 KiB tail each), not unbounded `exec` buffers,
- on timeout send termination, then bounded grace period, then kill if still alive,
- report timeout as verification failure,
- persist exit/signal/timing metadata without secret environment values.

## 12. Worker verification exact ordering

Only a settled archived worker turn with valid archive digest can be verified.

Order:

1. verify config/task/classification exact-byte digests,
2. verify worker archive bytes/digest/correlation,
3. verify reported commit exists and task worktree HEAD + task branch equal it,
4. verify pinned-base ancestry,
5. audit committed paths/outbox,
6. check protected source baseline,
7. `git diff --check base..commit`,
8. initial task-worktree status,
9. package-script lifecycle definition integrity when applicable,
10. run bounded sanitized checks,
11. re-verify task worktree HEAD + exact task branch equal reported commit,
12. final task-worktree status,
13. protected source baseline again,
14. write canonical verification artifact and persist digest.

Only the exact expected worker-result outbox may remain untracked.

## 13. Reviewer isolation and review verification

Reviewer parent marker precedes clone mutation. Clone uses:

```text
git clone --no-local --no-checkout <canonical-source-repo> <repo>
git -C <repo> checkout --detach <verified_commit>
git -C <repo> remote remove origin
```

Adopt only exact owner marker, exact HEAD, empty remotes, and clone-internal common Git dir. Partial/mismatched clone blocks with no destructive repair.

Before reviewer launch, require clean clone and record HEAD/status plus verification artifact digest. Reviewer result is not final until agent settles. Post-settlement clone HEAD/status may differ only by exact result outbox.

Review-verification consumes the digested reviewer archive, verifies reviewed commit and verification digest, validates findings/verdict schema, and writes its own canonical digested artifact.

Reviewer isolation is Git/repository-metadata isolation only.

## 14. Arbiter and escalation

Arbiter gets an ownership-marked evidence bundle, never a target checkout. Bundle includes sanitized immutable task summary/scope, classification, commit IDs, verification/review/repair digests and findings, repair history, adjudication question. It omits repository/worktree paths, remotes, `.git`, secrets.

First material review failure -> `REPAIR_PENDING`, canonical repair ticket, default worker.

Second material failure -> `ESCALATION_PENDING`, fresh `ORCH_ESCALATE_1` arbiter, then `WORK_STRONG`.

Third material failure -> `REPLAN_REQUIRED`; no fourth automatic retry.

## 15. Final freshness gate and DONE

A previously passing verification/review is not enough. Immediately before DONE, under the run lock, perform a non-mutating final freshness gate:

1. verify all immutable run-input digests,
2. verify worker/verification/reviewer/review-verification evidence byte digests,
3. require no active turn and no cancellation,
4. re-read task worktree HEAD and require exact verified commit,
5. require exact task branch ref equals verified commit,
6. require task worktree status still acceptable (only exact retained Factory outbox paths, if not yet ingested/cleaned),
7. re-check protected source baseline and exact task branch,
8. require no evidence marked stale,
9. require retry/escalation policy satisfied.

Only then transition to DONE.

This catches external/task-branch/worktree changes occurring after worker verification or reviewer completion.

## 16. Cleanup

Cleanup may touch only exact recorded, valid-owner Factory resources; active-turn resources are always refused.

Reviewer/arbiter resources may be deleted only after all evidence needed by later phases has been persisted and byte-digested. Task worktree requires terminal run plus explicit task-worktree cleanup authority.

Native task worktree removal never uses `--force` by default. Dirty refusal is reported. Task branch remains unless separately authorized.

## 17. Gears and foreman

Factory-launched gears are `ORCH_ESCALATE_1`, `WORK_DEFAULT`, `WORK_STRONG`, `REVIEW_DEFAULT`, `REVIEW_STRONG`, all exact argv in pinned config snapshot.

Human foreman expectation is separate. Report `current-session-verified` only when introspection proves it; otherwise only `configured-session-contract`.

## 18. DONE requirements

DONE implies:

- immutable run-input bytes/digests valid,
- canonical repo/base identity pinned,
- valid protected source baseline/final check,
- valid completed worker archive digest,
- valid worker verification artifact digest,
- valid completed reviewer archive digest,
- valid review-verification PASS artifact digest,
- repair/arbiter evidence chain valid when applicable,
- final task HEAD/branch/status freshness valid,
- no active turn/cancellation/stale evidence,
- exact pinned specialist gear history,
- no controller-authorized merge/push/deploy/production mutation.

## 19. Runtime qualification

Provider-backed qualification must exercise:

- snapshot/base/root rules,
- owner marker-before-mutation,
- partial worktree reconciliation,
- protected source main/other-ref/config/hooks detection,
- prompt ambiguity/abandonment,
- settlement-before-release/idempotent settlement,
- artifact no-follow/symlink/size rejection,
- archive/evidence tamper detection,
- repair ticket tamper detection,
- verification script-definition rewrite rejection,
- verification timeout/output bounds,
- clean HEAD movement by verification command rejected,
- post-review external task-branch/worktree mutation rejected by final freshness gate,
- independent reviewer isolation,
- active/evidence cleanup guards,
- PID reuse recovery,
- escalation cap,
- source protected refs unchanged.

Without provider-backed smoke qualification, report at most `UNIT_INTEGRATION_COMPLETE`.

## 20. Review-8 corrections

1. Final DONE freshness rechecks task HEAD/branch/status and protected source state after review.
2. Repair tickets become canonical byte-digested decision evidence bound into subsequent worker/arbiter requests.
3. Artifact ingestion uses no-follow descriptor-based reads and rejects symlink path components/TOCTOU swaps.
4. Verification subprocesses have pinned timeouts and bounded streaming output capture.
5. Protected source ref allowlist is exact: only the Factory task branch may newly appear/move.
6. Ownership marker bytes are themselves digested and verified.
7. Reviewer clone must be clean before launch and review-verification is an explicit digested step.

## 21. Deferred

- OS/container sandboxing and guaranteed network isolation,
- model-catalog discovery/usage-price optimization,
- parallel workers,
- auto merge/push/deploy,
- web/remote orchestration,
- raw Herdr socket subscription,
- direct UAL integration,
- autonomous PLAN->EXECUTE,
- automatic permission approval.
