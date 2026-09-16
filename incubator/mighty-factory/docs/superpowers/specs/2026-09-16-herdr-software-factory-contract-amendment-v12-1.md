# Mighty Factory v0.1 — Normative Contract Amendment 12.1

**Status:** Required alongside Review-12 design  
**Date:** 2026-09-16

This amendment overrides only the specialist/repair result details below. All other Review-12 requirements remain unchanged.

## 1. Worker result is status-dependent

### Implemented worker

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "worker",
  "status": "implemented",
  "commit": "<40-hex>",
  "summary": "...",
  "reported_tests": [],
  "known_limitations": []
}
```

Rules:

- `commit` is required and must resolve as a Git commit during controller verification.
- `reported_tests` is informational only and never proves controller verification.

### Pre-implementation blocked worker

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "worker",
  "status": "blocked",
  "commit": null,
  "summary": "Unable to continue",
  "blocker": {
    "code": "permission_required",
    "message": "..."
  },
  "reported_tests": [],
  "known_limitations": []
}
```

Rules:

- `commit` must be `null`.
- `blocker.code` and `blocker.message` are required bounded strings.
- After normal settled/finalizing turn archival, a blocked worker transitions **atomically from WORKING to BLOCKED** when the lease is cleared. It never enters `VERIFYING_WORK` and `verifyWorker` is never invoked.
- If a worker already created a commit and then encountered a later limitation, it uses `status:"implemented"`; the limitation belongs in `known_limitations` and independent verification decides whether the commit is usable.

This worker-blocked transition overrides the generic Review-12 `WORKING -> VERIFYING_WORK` transition for `status:"blocked"` only.

## 2. Reviewer result consistency

Reviewer `confidence` must be a finite numeric value in `[0,1]` without coercion.

### PASS

- may contain zero findings,
- every finding must have severity `MINOR` or `INFO`,
- every finding must have `material:false`.

### FAIL

- must contain at least one `material:true` finding of severity `BLOCKER` or `IMPORTANT`, **or** a top-level `blocker` object when the review itself cannot complete,
- FAIL containing only non-material MINOR/INFO findings is invalid evidence,
- PASS containing any material/BLOCKER/IMPORTANT finding is invalid evidence.

Review-verification rejects contradictory verdict/findings instead of guessing intent.

## 3. Arbiter result and second-failure routing

Canonical arbiter result minimum:

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "arbiter",
  "status": "decided|blocked",
  "decision": "retry_strong|replan|block",
  "reasoning_summary": "bounded summary",
  "repair_strategy": "bounded strategy or empty string",
  "evidence_digests": ["sha256:..."]
}
```

Rules:

- second material review failure always launches fresh `ORCH_ESCALATE_1` arbiter,
- `decision:"retry_strong"` -> controller transitions to WORKING and the next worker uses `WORK_STRONG`,
- `decision:"replan"` -> controller transitions to `REPLAN_REQUIRED` and launches no worker,
- `decision:"block"` or `status:"blocked"` -> controller transitions to `BLOCKED` and launches no worker,
- `status:"blocked"` requires `decision:"block"`,
- any decision attempting to widen immutable task scope/path/policy is invalid evidence.

These rules override any shorthand Review-12 wording that implies every second-failure arbiter must necessarily produce a strong-worker retry.

## 4. Repair ticket minimum

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "source_review_digest": "sha256:...",
  "summary": "bounded repair summary",
  "required_fixes": ["..."],
  "forbidden_scope_changes": true
}
```

Controller canonicalizes and digests this object. It rejects attempts to alter target repo, base SHA, allowed paths, trust mode, or verification policy.
