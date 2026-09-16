# Mighty Factory — Canonical v0.1 Design (Review 12)

**Status:** Canonical implementation contract  
**Date:** 2026-09-16  
**Supersedes:** Review-11 and all earlier Mighty Factory drafts  
**Incubation:** `mighty-router` branch `incubator/mighty-factory-v0` only

## 1. Purpose and trust

Mighty Factory is a trusted-local-repository controller around Herdr. The human-facing Codex/Luna-Max foreman owns conversation, requirements, architecture, and bounded judgment. Deterministic Node.js owns authorization, immutable run inputs, lifecycle, locking, routing, resource reconciliation, evidence integrity, Git protection, verification, review, escalation, cleanup, and DONE.

v0.1 is **not** an OS/network sandbox. The controller does not authorize merge, push, deploy, production mutation, billing, credential changes, package installation, destructive cleanup, or permission approval.

## 2. PLAN / EXECUTE / CANCEL / ABANDON

PLAN is non-mutating and launches no specialist. Only exact `/execute` grants execution authority.

Public CLI:

```text
mighty-factory help
mighty-factory doctor
mighty-factory print-config
mighty-factory route
mighty-factory authorize-execute
mighty-factory cancel
mighty-factory recover-run
mighty-factory abandon-turn
mighty-factory prepare-run
mighty-factory dispatch-worker
mighty-factory verify-worker
mighty-factory dispatch-reviewer
mighty-factory verify-review
mighty-factory dispatch-arbiter
mighty-factory record-repair
mighty-factory status
mighty-factory cleanup
```

No generic public transition command.

Cancellation:

- no active turn -> atomic `CANCELLED`,
- active turn -> `cancel_requested=true`, lease retained,
- turn may only finish via normal finalization,
- final atomic state write clears lease and goes directly `CANCELLED`,
- no verification/verdict/repair/arbiter/new specialist/DONE after cancel requested.

`abandon-turn` is human-only before a completed turn archive exists. It never resends. It requires exact active-turn/workspace ownership and proven workspace closure, archives `abandoned`, and atomically clears lease + cancels. Completed archived turns with transport cleanup pending cannot be abandoned; recovery resumes finalization.

## 3. Immutable task contract

Operator task input before authorization:

```json
{
  "schema_version": 1,
  "summary": "Implement bounded feature X",
  "target_repo": "/absolute/or/repo-subpath",
  "base_ref": "main",
  "execution_trust": "trusted-local-repository",
  "allowed_paths": ["src/", "tests/"],
  "allow_noop": false,
  "verification": {
    "policy": "trusted-repo-checks",
    "commands": [
      {"kind": "npm-script", "script": "test"},
      {"kind": "node-check", "path": "src/index.js"}
    ]
  }
}
```

Rules:

- `schema_version` exactly `1`,
- `summary` non-empty bounded string,
- `target_repo` must resolve inside one non-bare Git worktree,
- trust mode exactly supported value,
- code-changing tasks require non-empty normalized repository-relative `allowed_paths`, no absolute/traversal paths,
- code-changing tasks require at least one executable verification check,
- `.mighty-factory-outbox/` is never an allowed committed path,
- `allow_noop=false` by default; empty committed diff only allowed when explicitly true,
- after authorization the mutable task input is never consulted again.

## 4. Classification contract and deterministic route

```json
{
  "scope": "normal",
  "risk": "medium",
  "ambiguity": "low",
  "change_kind": "feature",
  "cross_cutting": false,
  "confidence": 0.89
}
```

Allowed values:

```text
scope: tiny | normal | broad | architectural
risk: low | medium | high
ambiguity: low | medium | high
change_kind: question | docs | bugfix | feature | refactor | migration | security
cross_cutting: boolean
confidence: finite number 0..1
```

No type coercion.

Factory gears:

```text
ORCH_ESCALATE_1
WORK_DEFAULT
WORK_STRONG
REVIEW_DEFAULT
REVIEW_STRONG
```

Routing:

- normal low/medium -> WORK_DEFAULT + REVIEW_DEFAULT,
- high risk -> REVIEW_STRONG,
- broad/architectural -> human-approved PLAN must precede exact `/execute`,
- low confidence or unresolved high ambiguity -> authorization rejected until clarified,
- first material review failure -> repair + normally WORK_DEFAULT,
- second -> ORCH_ESCALATE_1 arbiter + WORK_STRONG,
- third -> REPLAN_REQUIRED.

All Factory gear launch specs are exact non-secret argv pinned at authorization. Foreman expectation is separate and reported verified only when introspection proves it.

## 5. Authorization and immutable snapshots

At `/execute` under one controller transaction:

1. validate config/task/classification,
2. canonicalize target worktree/Git top-level/common Git dir,
3. require non-bare worktree support,
4. pin `base_ref -> base_sha`,
5. reject containment overlap among source repo/state root/temp root,
6. allocate run/task IDs + deterministic task branch/path; task branch must not preexist,
7. normalize config/task/classification; task snapshot embeds canonical Git identity/base SHA,
8. canonicalize/write exact UTF-8 JSON atomically,
9. SHA-256 exact written bytes,
10. persist input digests and immutable identity in `run.json`,
11. transition PLAN -> READY only after durable success.

Canonical files:

```text
config.snapshot.json
task.snapshot.json
classification.snapshot.json
run.json
```

Later commands hash exact bytes before parse and never reread mutable inputs.

Canonical JSON: recursive sorted object keys, preserved array order, finite JSON values only, exactly one trailing newline.

## 6. Minimal durable run/state shapes

`run.json` minimum:

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "input_digests": {
    "config": "sha256:...",
    "task": "sha256:...",
    "classification": "sha256:..."
  },
  "target_repo": "/canonical/repo",
  "git_common_dir": "/canonical/common-git-dir",
  "base_ref": "main",
  "base_sha": "<40-hex>",
  "task_branch": "mf/run-...",
  "task_worktree": "/factory-temp/run.../task/repo"
}
```

`state.json` minimum:

```json
{
  "schema_version": 1,
  "revision": 0,
  "phase": "PLAN",
  "cancel_requested": false,
  "active_turn": null,
  "material_review_failures": 0,
  "verification_stale": false,
  "review_stale": false
}
```

Active turn minimum:

```json
{
  "turn_id": "turn_...",
  "role": "worker|reviewer|arbiter",
  "stage": "prompt_attempted",
  "gear": "WORK_DEFAULT",
  "workspace_label": "mighty-factory:turn_...",
  "agent_name": "mf-worker-...",
  "prompt_digest": "sha256:...",
  "expected_result_path": "/owned/path/result.json"
}
```

Active stages:

```text
claimed
workspace_ready
agent_started
prompt_attempted
result_seen
settling
finalizing
```

## 7. Lifecycle

```text
PLAN
READY
PREPARING
WORKING
VERIFYING_WORK
REVIEWING
VERIFYING_REVIEW
REPAIR_PENDING
ESCALATION_PENDING
REPLAN_REQUIRED
BLOCKED
DONE
CANCELLED
```

Core legal transitions:

```text
PLAN -> READY                     authorize
READY -> PREPARING                prepare
PREPARING -> WORKING              task resource + source baseline ready
WORKING -> VERIFYING_WORK         atomic worker finalization
VERIFYING_WORK -> REVIEWING       verification PASS
VERIFYING_WORK -> REPAIR_PENDING  repairable verification FAIL
VERIFYING_WORK -> BLOCKED         integrity/authority violation
REVIEWING -> VERIFYING_REVIEW     atomic reviewer finalization
VERIFYING_REVIEW -> DONE          review PASS + final freshness
VERIFYING_REVIEW -> REPAIR_PENDING first material review FAIL
VERIFYING_REVIEW -> ESCALATION_PENDING second material review FAIL
VERIFYING_REVIEW -> REPLAN_REQUIRED third material review FAIL
REPAIR_PENDING -> WORKING         canonical repair accepted
ESCALATION_PENDING -> WORKING     completed arbiter + strong route selected
any nonterminal -> BLOCKED         hard integrity/recovery ambiguity
```

Illegal transitions rejected. Counters/stale flags durable.

Repairable verification failure: project test/lint/typecheck or implementation defect with repository integrity intact.

Integrity/authority violation -> BLOCKED: input/evidence digest mismatch, protected source mutation, unsafe artifact, forbidden committed path, unexpected Git identity, or verification process group not proven terminated.

## 8. Ownership, locking, roots, safe files

Source/state/temp roots must not contain each other in either direction after canonicalization of existing ancestors.

Every task/review/arbiter parent gets a canonical byte-digested owner marker before external mutation. Adoption/deletion requires exact marker digest.

Every state-changing operation uses exclusive run lock metadata: nonce, PID, process-start token, controller-instance ID, timestamp, command. Recovery requires nonce + process identity; PID reuse distinguishable; ambiguity fails closed; no force clear.

Externally produced JSON is descriptor-safely read: owned-root containment, reject symlink components, final no-follow open on target macOS, regular-file fstat, turn-result <=1MiB, bounded descriptor read, stable pre/post identity+size, parse captured bytes, validate schema/IDs/commit, hash exact bytes, atomic durable copy.

## 9. Specialist request/result contracts

Worker request minimum:

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "worker",
  "task_digest": "sha256:...",
  "classification_digest": "sha256:...",
  "repair_digest": null,
  "base_sha": "...",
  "result_path": ".mighty-factory-outbox/turn_.../worker-result.json"
}
```

Worker result minimum:

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "worker",
  "status": "implemented|blocked",
  "commit": "<40-hex>",
  "summary": "...",
  "reported_tests": [],
  "known_limitations": []
}
```

Reviewer request binds `verified_commit` + `verification_digest`.

Reviewer result minimum:

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "reviewer",
  "reviewed_commit": "<40-hex>",
  "verification_digest": "sha256:...",
  "verdict": "PASS|FAIL",
  "findings": [
    {
      "severity": "BLOCKER|IMPORTANT|MINOR|INFO",
      "material": true,
      "location": "src/file.js:10",
      "problem": "...",
      "required_fix": "..."
    }
  ],
  "confidence": 0.9
}
```

PASS can contain only findings with `material=false` and severity MINOR/INFO. BLOCKER/IMPORTANT or any `material=true` requires FAIL; contradictory PASS is invalid evidence -> BLOCKED.

Arbiter result is correlated and contains a bounded `decision`, `reasoning_summary`, and `repair_strategy`; it cannot change immutable task scope/policy.

## 10. Prompt ambiguity and atomic finalization

Persist turn/workspace/agent identity, pinned gear, request, prompt bytes/digest, result path before mutation. `prompt_attempted` is durable before prompt call. Definite non-delivery may resend exact prompt once; ambiguous delivery never blindly resends.

Result file never completes turn; producer must settle.

Finalization after settlement:

1. lock run; set `finalizing`,
2. safely ingest result,
3. capture role final snapshot with source outbox present,
4. write canonical completed turn archive + digest,
5. delete only exact ingested source outbox,
6. verify exact deletion/no unrelated delta,
7. one atomic state write records archive digest, clears active turn, increments revision, and transitions to normal next phase or directly CANCELLED if cancellation requested.

Crash/retry:

- no archive -> resume ingest/snapshot/archive,
- valid archive + outbox exists -> retry exact deletion only,
- valid archive + outbox absent + matching finalizing lease -> atomic clear+transition,
- archive mismatch -> BLOCKED,
- delete failure/ambiguity -> BLOCKED with completed archive + active finalizing lease; fix and recover, do not abandon,
- concurrent finalizers converge to one archive/transition.

## 11. Crash-safe task resource and source protection

Task owner marker precedes Git mutation. Exact deterministic branch/path only. Branch-only crash may attach valid recorded unattached branch; incompatible/foreign state BLOCKS; no alternate identity.

Pinned canonical `git_common_dir` is used even if source is linked worktree.

Protected baseline after task prep/before first worker:

- source HEAD,
- full source porcelain status,
- all refs except task branch,
- task branch OID separately,
- common config exact bytes,
- common hooks tree digest.

Each protected check requires source HEAD/status, all protected refs, common config/hooks unchanged; no new refs except task branch; task branch exact expected commit. Mismatch BLOCKS.

## 12. Verification command contract

Supported checks:

```json
{"kind":"npm-script","script":"test"}
{"kind":"pnpm-script","script":"lint"}
{"kind":"yarn-script","script":"typecheck"}
{"kind":"node-test","paths":["tests/foo.test.js"]}
{"kind":"node-check","path":"src/foo.js"}
```

No arbitrary shell/binary/install/migrate/deploy/destructive Git. Package `pre<script>/<script>/post<script>` definitions at reported commit must equal pinned base definitions.

Timeout per command pinned in config: default 10min, range 1–30min. Runner uses no shell, own process group/session on target macOS, 16KiB stdout/stderr tail buffers, kills whole group on timeout with bounded grace/force kill, and proves termination before final Git checks.

## 13. Worker verification

Requires completed finalized worker archive digest and no active lease.

Order:

1. input digests,
2. archive digest/correlation,
3. task HEAD + branch == commit,
4. base ancestry,
5. committed path/outbox audit (`allowed_paths`, `allow_noop`),
6. protected source check,
7. `git diff --check`,
8. clean task worktree after transport deletion,
9. package lifecycle integrity,
10. bounded sanitized checks,
11. group termination proof,
12. recheck task HEAD/branch,
13. clean final status,
14. protected source check,
15. canonical verification evidence digest.

Repairable check failures -> REPAIR_PENDING. Integrity/authority failures -> BLOCKED.

## 14. Evidence chain and repair

All decision evidence canonical exact-byte SHA-256:

```text
worker archive -> worker verification -> reviewer request
-> reviewer archive -> review verification
-> repair ticket if FAIL -> arbiter evidence/result if escalated
-> final freshness
```

`record-repair` accepts current validated FAIL only, uses bounded schema, cannot widen immutable scope/path/policy, writes/digests repair evidence, and next worker request binds its digest.

## 15. Reviewer isolation and review verification

Reviewer parent marker precedes clone mutation. Independent clone uses `git clone --no-local --no-checkout`, exact detached verified commit, origin removed, internal common Git dir, clean pre-launch status. Reviewer request binds verification digest.

Reviewer uses same settled/finalizing/atomic state protocol. Review verification checks archive digest, reviewed commit, bound verification digest, findings/verdict schema and emits canonical digested evidence.

Reviewer isolation is repository/Git-metadata isolation only.

## 16. Arbiter/escalation

Arbiter gets ownership-marked evidence bundle only: immutable summary/scope/classification, commit/evidence/repair digests, findings/history/question. No checkout/source paths/remotes/.git/secrets.

First material review FAIL -> repair/default worker. Second -> ORCH_ESCALATE_1 + WORK_STRONG. Third -> REPLAN_REQUIRED.

## 17. Final freshness and DONE

Immediately before DONE under run lock:

1. verify all immutable input/evidence digests,
2. no active turn/cancellation/stale evidence,
3. task worktree HEAD == verified commit,
4. task branch == verified commit,
5. task worktree clean,
6. protected source HEAD/status/refs/common config/hooks baseline valid with task branch at verified commit,
7. retry/escalation policy satisfied.

Then atomic DONE transition. DONE is point-in-time, not permanent external-mutation prevention.

## 18. Cleanup

Only exact valid-owner resources; never active/finalizing resources; never evidence-needed resources before digests exist. Task worktree removal requires terminal run + explicit authority, native Git without force, branch retained unless separately authorized.

## 19. Doctor and qualification

Doctor non-mutating checks Node/Git/Herdr, config/gears/routing, roots/common Git, serializer, writable roots, lock/process identity, no-follow support, sanitizer, process-group runner, reviewer isolation, foreman configured-vs-verified truthfulness.

`UNIT_INTEGRATION_COMPLETE` requires full local matrix at one HEAD.

`HERDR_RUNTIME_QUALIFIED` additionally requires disposable provider-backed Mac/Herdr proof of lifecycle/cancel, prompt/finalization recovery, artifacts, process groups, source protection, review, freshness, escalation, cleanup.

## 20. Review-12 corrections

1. Restores an exact task contract including `allowed_paths`, `allow_noop`, and verification schema.
2. Restores exact classification value constraints.
3. Defines minimum run/state/active-turn data shapes.
4. Defines worker/reviewer request/result schemas and PASS consistency directly in the canonical spec.
5. Defines exact supported verification-check object shapes.
6. Makes the implementation handoff able to use named interfaces without inventing core contracts.

## 21. Deferred

OS/container sandboxing; guaranteed network isolation; model catalog/usage pricing; parallel workers; auto merge/push/deploy; web/remote orchestration; raw socket subscription; UAL integration; autonomous PLAN->EXECUTE; automatic permission approval.
