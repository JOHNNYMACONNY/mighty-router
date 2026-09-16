# Mighty Factory v0.1 — Normative Implementation Amendment 12.1

**Status:** Required alongside Review-12 implementation plan  
**Date:** 2026-09-16

This amendment adds mandatory tests/implementation details to Review-12 Tasks 1, 6, and 8. No other task boundaries change.

## Amend Task 1 — Schema validators

Add worker/reviewer/arbiter result validators under `src/artifacts.js` or the focused artifact-schema module chosen by Task 1/Task 5. The exact exported names must be fixed before Task 6 consumes them; recommended names:

```js
validateWorkerResult(value, expected)
validateReviewerResult(value, expected)
validateArbiterResult(value, expected)
validateRepairTicket(value, expected)
```

Add RED tests:

```js
test('blocked worker may have null commit and required blocker', () => {
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
```

Also reject `status:'blocked'` with a non-null commit under the pre-implementation-blocker schema.

## Amend Task 6 — Worker blocker routing

Add controller/turn-finalization test:

```text
worker result status=blocked, commit=null
producer settles
result is ingested and turn archived/finalized normally
active lease clears atomically
controller does NOT call verifyWorker
controller transitions to BLOCKED (or the exact blocker-handling state defined by the implementation) with blocker evidence preserved
```

Worker self-reported tests remain informational and are never treated as controller verification evidence.

## Amend Task 8 — Reviewer/arbiter/repair consistency

Add RED reviewer tests:

```text
PASS + no findings -> valid
PASS + MINOR material=false -> valid
PASS + IMPORTANT/material=true -> invalid
FAIL + IMPORTANT/material=true -> valid
FAIL + only MINOR/material=false -> invalid
reviewer confidence -0.1, 1.1, NaN, or string -> invalid
FAIL review unable to complete + explicit blocker object -> valid blocker evidence
```

Add arbiter tests:

```text
status decided + retry_strong in ESCALATION_PENDING -> valid
status blocked + decision block -> valid
status blocked + decision retry_strong -> invalid
arbiter attempt to include scope/path/policy mutation fields -> reject
```

Add repair-ticket tests:

```text
source_review_digest must match current review FAIL digest
required_fixes must be bounded non-empty strings
forbidden_scope_changes must be true
fields attempting target/base/allowed_paths/trust/verification mutation -> reject
post-record byte tamper -> digest failure
```

## Amend Task 10 — E2E

Add these regression cases to `tests/e2e-controller.test.js`:

```text
pre-implementation worker blocker with null commit finalizes without invoking commit verifier
implemented worker with null commit rejected
PASS/material contradiction rejected
FAIL with no material finding/blocker rejected
arbiter illegal decision/state combination rejected
repair ticket scope-widening fields rejected
```
