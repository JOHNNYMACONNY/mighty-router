# Mighty Factory — Canonical v0.1 Design (Review 9)

**Status:** Canonical design for implementation  
**Date:** 2026-09-16  
**Supersedes:** Review-8 and all earlier Mighty Factory drafts  
**Incubation:** `mighty-router` branch `incubator/mighty-factory-v0` only

## 1. System contract

Mighty Factory is a trusted-local-repository software-factory controller around Herdr. Luna-Max owns conversation/planning/judgment. Deterministic Node.js code owns authorization, immutable run inputs, crash-safe resources, turn leases, evidence integrity, Git protection, verification, review, escalation, cleanup, and DONE.

v0.1 is not an OS/network sandbox. The controller never authorizes merge/push/deploy/production/billing/credential/install actions, but cannot prove an unsandboxed model process never caused an external side effect.

## 2. Authorization and immutable inputs

Exact `/execute` only.

At authorization:

1. validate config/task/classification and `execution_trust: trusted-local-repository`,
2. canonicalize target worktree root and Git top-level,
3. resolve and canonicalize `git rev-parse --git-common-dir`,
4. require non-bare worktree support,
5. pin `base_ref -> base_sha`,
6. reject state/temp/source containment overlap,
7. allocate run/task IDs and deterministic task branch/path; task branch must not preexist,
8. canonicalize/write exact config/task/classification snapshot bytes,
9. hash exact bytes and persist digests + canonical repo/common-git/base identity in `run.json`,
10. transition PLAN -> READY only after durable writes.

Later commands hash exact snapshot bytes before parsing and never reread mutable input files.

Canonical JSON recursively sorts object keys, preserves array order, accepts finite JSON values only, and ends with exactly one newline.

## 3. Ownership and safe files

Every Factory-created task/review/arbiter parent gets a canonical owner marker written and byte-digested **before** external mutation. Adoption/deletion requires exact marker bytes/digest.

Externally produced JSON/artifacts use a descriptor-based safe reader:

- lexical containment under owned root,
- reject symlink components,
- open final file no-follow on target macOS,
- `fstat` regular file,
- turn result maximum 1 MiB,
- bounded descriptor read only,
- pre/post descriptor identity+size stable,
- parse UTF-8 JSON only from captured bytes,
- schema/IDs/commit validated,
- exact bytes hashed and atomically copied to durable state.

## 4. Locking and recovery

All state mutation is per-run locked. Lock metadata contains nonce, PID, process-start token, controller-instance ID, time, command.

Recovery requires nonce and process identity. Same PID+same token is live; absent PID or same PID+different token is stale; ambiguous/unsupported identity fails closed. No force-clear CLI.

## 5. Active turn, prompt ambiguity, settlement

Active stages:

```text
claimed
workspace_ready
agent_started
prompt_attempted
result_seen
settling
```

Persist deterministic workspace/agent identity, gear spec, request, prompt bytes/digest, and result path before external mutation. Persist `prompt_attempted` before calling prompt. Definite non-delivery may resend exact bytes at most once; ambiguous delivery never blindly resends and may require human `abandon-turn`.

A result does not finish a turn. Producer must reach qualified settled state. Then controller safely ingests result, captures final role state, writes canonical turn archive, hashes it, persists archive digest, clears lease, and applies one transition. Concurrent settlement reuses existing valid archive.

`abandon-turn` never resends; it must prove exact owned workspace closure/absence, archive status `abandoned`, clear lease, preserve filesystem evidence, and cancel run. If closure cannot be proved, remain BLOCKED.

## 6. Evidence chain and repair tickets

Every decision-bearing durable evidence object is canonical exact-byte SHA-256 evidence.

```text
worker turn archive
 -> worker verification
 -> reviewer request binds worker verification digest
 -> reviewer turn archive
 -> review verification
 -> repair ticket (when FAIL)
 -> arbiter evidence/result (when escalation)
 -> final freshness
```

`record-repair` accepts only the current validated review FAIL, cannot alter immutable scope/path/policy, writes canonical bounded repair evidence, persists digest, and the next worker request binds it. Mutation after recording fails digest verification.

## 7. Crash-safe task worktree

Task owner parent exists before `git worktree` mutation. The task branch was proven absent at authorization.

Reconciliation:

- absent branch/path -> create exact branch/worktree at pinned base,
- branch exists at valid recorded base/descendant and is unattached -> attach at exact recorded path,
- attached elsewhere/incompatible -> BLOCKED,
- exact owned worktree -> adopt,
- wrong/tampered marker/non-worktree/alternate path -> BLOCKED,
- never allocate alternate identity on retry.

## 8. Protected source Git state

The canonical source worktree may itself be a linked worktree, so common metadata is addressed through the canonical `git_common_dir` pinned at authorization, never by assuming `<repo>/.git` is a directory.

After task worktree preparation and before first worker launch capture and digest a baseline containing:

- canonical source worktree HEAD,
- full source worktree porcelain status,
- **protected refs map = all refs except the exact Factory task branch**, sorted name -> OID,
- whether the exact task branch exists and its initial OID separately,
- exact common repository config bytes from `<git_common_dir>/config`,
- deterministic hooks tree digest from `<git_common_dir>/hooks`.

Because baseline is captured after task worktree creation, task branch normally exists and is tracked separately rather than contradictorily treated as absent.

At each protected check:

- source HEAD/status equal baseline,
- every protected ref has identical OID,
- no new ref exists except exact task branch,
- no protected ref disappeared,
- common config identical,
- hooks identical,
- exact task branch OID equals the expected task commit for the current verified state.

Any mismatch BLOCKS; no reset/repair.

## 9. Outbox lifecycle

A specialist source outbox is transport, not durable evidence.

Settlement sequence for an outbox:

1. no-follow safe ingest exact bytes into durable state,
2. write/digest turn archive referencing ingested artifact digest,
3. capture required role final status/integrity while source outbox still exists,
4. after archive durability and while holding the appropriate controller lock, delete **only the exact ingested outbox file/directory owned by that turn**,
5. verify deletion did not change any other path,
6. clear active lease.

If exact outbox deletion fails, turn may still archive but run becomes BLOCKED before verification/next specialist. Controller never broad-cleans `.mighty-factory-outbox`.

Thus repair rounds do not accumulate stale prior-turn outboxes in the task worktree. Worker verification expects a clean task worktree after settled-turn source outbox removal.

Reviewer clone integrity is captured before its exact result outbox deletion; durable reviewer archive thereafter replaces the transport file.

## 10. Verification command policy and process-group bounds

Allowed checks:

```text
npm-script
pnpm-script
yarn-script
node-test
node-check
```

No arbitrary shell/binary/install/migrate/deploy/destructive-Git forms.

For a package-script check, root `package.json` `pre<script>`, `<script>`, `post<script>` definitions at reported commit must exactly equal definitions at pinned base.

Each check timeout is pinned in config: default 10 minutes, allowed range 1–30 minutes.

Command runner:

- uses `spawn` without shell,
- starts the verification subprocess in its own process group/session where supported on target macOS,
- streams stdout/stderr to bounded 16 KiB tail ring buffers,
- on timeout terminates the **whole spawned process group**, waits a bounded grace period, then force-kills the group if necessary,
- waits for process/group termination before post-command Git/status checks,
- persists exit/signal/timeout/timing metadata without environment values,
- timeout or inability to terminate the group is verification failure/BLOCKED, never PASS.

## 11. Worker verification

Only a completed settled worker archive with valid digest is eligible.

Order:

1. verify immutable input bytes/digests,
2. verify worker archive bytes/digest/correlation,
3. require task worktree HEAD and task branch equal reported commit,
4. pinned-base ancestry,
5. committed path/outbox audit,
6. protected-source check,
7. `git diff --check`,
8. require task worktree clean after settled outbox removal,
9. validate package lifecycle definitions,
10. run bounded sanitized verification commands,
11. require process group fully terminated,
12. recheck task HEAD/task branch equal reported commit,
13. final task status clean,
14. protected-source check again,
15. write/digest verification evidence.

This rejects both dirty side effects and clean new-commit/reset side effects.

## 12. Reviewer isolation and verdict consistency

Reviewer parent owner marker precedes clone mutation. Clone is independent:

```text
git clone --no-local --no-checkout <source> <repo>
git -C <repo> checkout --detach <verified_commit>
git -C <repo> remote remove origin
```

Before launch require exact HEAD, empty remotes, internal common Git dir, and clean status. Request binds worker verification digest.

Reviewer result is final only after producer settlement. Integrity snapshot is captured with exact outbox as sole delta, then outbox is durably ingested/archived and removed per §9.

Review-verification checks archive digest, reviewed commit, bound verification digest, schema, findings, verdict, and writes its own digested artifact.

Verdict invariant:

- `PASS` may contain only informational/minor findings explicitly marked non-material,
- any BLOCKER/IMPORTANT/material finding requires `FAIL`,
- contradictory `PASS` + material finding is invalid review evidence and blocks rather than being interpreted heuristically.

Reviewer isolation is Git/repository-metadata isolation only.

## 13. Arbiter and escalation

Arbiter gets only an ownership-marked evidence bundle: immutable task summary/scope, classification, commit IDs, evidence/repair digests, review findings/history, adjudication question. No checkout paths/remotes/.git/secrets.

First material FAIL -> canonical repair -> `WORK_DEFAULT`.
Second material FAIL -> fresh `ORCH_ESCALATE_1` arbiter -> `WORK_STRONG`.
Third material FAIL -> `REPLAN_REQUIRED`; no automatic fourth attempt.

## 14. Final freshness and DONE

Immediately before DONE, under run lock:

1. verify all immutable input/evidence digests,
2. require no active turn/cancellation/stale evidence,
3. require task worktree HEAD exact verified commit,
4. require task branch exact verified commit,
5. require task worktree clean (settled source outboxes already removed),
6. protected source worktree/refs/common config/hooks equal baseline with only task branch at verified commit,
7. retry/escalation policy satisfied.

Only then transition DONE.

DONE represents a point-in-time verified state; v0.1 does not claim to prevent a separate external process from mutating files immediately afterward.

## 15. Cleanup

Cleanup touches only exact recorded valid-owner resources, never active-turn resources, and never evidence-needed resources before durable digests exist.

Task worktree removal requires terminal run + explicit authority, uses native Git without `--force`, and retains task branch unless separately authorized.

## 16. Gears and foreman

Factory gears: `ORCH_ESCALATE_1`, `WORK_DEFAULT`, `WORK_STRONG`, `REVIEW_DEFAULT`, `REVIEW_STRONG`, all exact pinned argv.

Foreman expected model/effort is separate; `current-session-verified` only when introspection proves it.

## 17. Runtime qualification

Provider-backed qualification must cover:

- immutable authorization/root/common-Git identity,
- task marker/partial resource recovery,
- protected source refs/config/hooks/source status,
- no stale outboxes across repair rounds,
- prompt ambiguity/abandonment,
- settlement/idempotence,
- no-follow artifact reads,
- evidence/repair tamper,
- package verification-definition rewrite,
- process-group timeout termination,
- clean HEAD movement detection,
- contradictory reviewer PASS/material finding rejection,
- post-review freshness mutation detection,
- reviewer isolation,
- cleanup guards,
- PID reuse,
- escalation cap.

Without this smoke run report at most `UNIT_INTEGRATION_COMPLETE`.

## 18. Review-9 corrections

1. Protected Git common metadata is resolved with `--git-common-dir`; source may be a linked worktree.
2. Protected ref baseline explicitly excludes/tracks task branch separately, removing Review-8 timing contradiction.
3. Exact ingested outbox is removed after durable archive/final snapshot so repair rounds remain clean.
4. Verification timeout kills and waits for the entire spawned process group before final checks.
5. Reviewer `PASS` is invalid when material findings are present.
6. DONE is documented as a point-in-time freshness assertion, not permanent external-mutation prevention.

## 19. Deferred

OS/container sandboxing; guaranteed network isolation; model catalog/usage pricing; parallel workers; auto merge/push/deploy; web/remote orchestration; raw socket subscriber; UAL integration; autonomous PLAN->EXECUTE; automatic permission approval.
