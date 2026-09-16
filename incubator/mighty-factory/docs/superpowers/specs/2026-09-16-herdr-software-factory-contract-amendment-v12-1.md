# Mighty Factory v0.1 — Normative Contract Amendment 12.1

**Status:** Required alongside Review-12 design  
**Date:** 2026-09-16

This amendment changes only specialist/repair result schema details. All other Review-12 requirements remain unchanged.

## 1. Worker result is status-dependent

A blocked worker may have no commit. The canonical worker result schema is:

### Implemented

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

- `commit` is required and exactly a Git commit SHA accepted by controller Git verification.
- `reported_tests` is informational only and never proves verification.

### Blocked

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

- `commit` must be `null` for a pre-implementation blocker.
- `blocker.code` and `blocker.message` are required bounded strings.
- A blocked worker result never enters worker commit verification and transitions according to controller blocker policy.
- If a worker made a commit and then encountered a later blocker, it must still use `status:"implemented"` and describe the blocker/limitation in `known_limitations`; the controller independently decides whether verification can proceed.

## 2. Reviewer result consistency

Reviewer `confidence` must be a finite number in `[0,1]` without coercion.

### PASS

- may have zero findings,
- every finding must be `severity: MINOR|INFO`,
- every finding must have `material:false`.

### FAIL

- must contain at least one finding with `material:true` and severity `BLOCKER|IMPORTANT`, **or** an explicit top-level `blocker` object when the review itself cannot complete,
- a FAIL with only non-material MINOR/INFO findings is invalid evidence,
- a PASS with any material/BLOCKER/IMPORTANT finding is invalid evidence.

Review-verification rejects contradictory verdict/findings instead of guessing intent.

## 3. Arbiter result schema

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

- `decision` cannot widen immutable task scope/path/policy.
- `status:"blocked"` requires `decision:"block"`.
- `retry_strong` is only legal in controller state that permits the strong-worker escalation path.

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
