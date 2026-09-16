# Mighty Factory v0.1 — Normative Implementation Amendment 12.1

**Status:** Required alongside Review-12 implementation plan  
**Date:** 2026-09-16

This amendment adds mandatory files/tests to Review-12 Tasks 1, 6, 8, and 10. No other task boundaries change.

## Amend File Structure

Add these exact files to the Review-12 file map:

```text
src/artifact-schema.js
tests/artifact-schema.test.js
```

All specialist/repair schema validation lives in `src/artifact-schema.js`. Do not create a competing `artifacts.js` schema module.

Required exports:

```js
validateWorkerResult(value, expected)
validateReviewerResult(value, expected)
validateArbiterResult(value, expected)
validateRepairTicket(value, expected)
```

## Amend Task 1 — Artifact schema validators

**Create:**
- `src/artifact-schema.js`
- `tests/artifact-schema.test.js`

Add RED tests:

```js
test('blocked worker accepts null commit and required blocker', () => {
  const value = {
    schema_version:1,
    run_id:'run_1', task_id:'task_1', turn_id:'turn_1', role:'worker',
    status:'blocked', commit:null, summary:'blocked',
    blocker:{code:'permission_required',message:'needs permission'},
    reported_tests:[], known_limitations:[]
  };
  assert.equal(validateWorkerResult(value, expected).status, 'blocked');
});

test('implemented worker requires commit', () => {
  assert.throws(() => validateWorkerResult({ ...implemented, commit:null }, expected), /commit/);
});

test('blocked worker rejects non-null commit', () => {
  assert.throws(() => validateWorkerResult({ ...blocked, commit:'a'.repeat(40) }, expected), /commit/);
});
```

Task-1 verify/commit commands must include `src/artifact-schema.js` and `tests/artifact-schema.test.js`.

## Amend Task 6 — Exact blocked-worker transition

Add RED controller/finalization test:

```text
worker result status=blocked, commit=null
producer settles
result safely ingested
turn archive written/digested
exact source outbox removed
one atomic state write clears active lease and transitions WORKING -> BLOCKED
verifyWorker call count remains zero
blocker evidence remains in archived turn
```

There is no implementation-defined alternative blocker state for this case: the exact next phase is `BLOCKED`.

Worker `reported_tests` remains informational and is never controller verification evidence.

## Amend Task 8 — Reviewer/arbiter/repair consistency

Reviewer RED tests:

```text
PASS + zero findings -> valid
PASS + MINOR material=false -> valid
PASS + IMPORTANT/material=true -> invalid
FAIL + IMPORTANT/material=true -> valid
FAIL + only MINOR/material=false -> invalid
confidence -0.1, 1.1, NaN, or string -> invalid
FAIL + explicit top-level blocker when review cannot complete -> valid blocker evidence
```

Arbiter RED tests:

```text
second material failure launches ORCH_ESCALATE_1 before interpreting decision
status decided + decision retry_strong -> next phase WORKING and next worker WORK_STRONG
status decided + decision replan -> REPLAN_REQUIRED, no worker launch
status blocked + decision block -> BLOCKED, no worker launch
status blocked + decision retry_strong -> invalid
arbiter result containing target/base/allowed_paths/trust/verification mutation fields -> invalid
```

Repair-ticket RED tests:

```text
source_review_digest must equal current validated review FAIL digest
required_fixes are bounded non-empty strings
forbidden_scope_changes must be true
target/base/allowed_paths/trust/verification mutation fields rejected
post-record byte tamper -> digest failure
```

## Amend Task 10 — E2E

Add mandatory scenarios:

```text
pre-implementation worker blocker with null commit finalizes atomically to BLOCKED without commit verifier
implemented worker with null commit rejected
blocked worker with non-null commit rejected
PASS/material contradiction rejected
FAIL with no material finding or blocker rejected
arbiter retry_strong -> WORK_STRONG
arbiter replan -> REPLAN_REQUIRED with no worker
arbiter block -> BLOCKED with no worker
repair ticket scope-widening fields rejected
```
