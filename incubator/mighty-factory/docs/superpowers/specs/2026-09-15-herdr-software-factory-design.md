# Mighty Factory — Herdr Multi-Agent Software Factory Design

**Status:** Canonical v0.1 design after second architecture review  
**Date:** 2026-09-15  
**Incubation location:** `mighty-router` branch `incubator/mighty-factory-v0` only. This design does not change Mighty Router mainline behavior and does not modify `universal-agent-loop`.

## 1. Goal

Build a small local orchestration layer that lets one conversational Codex agent act as the foreman while Herdr coordinates fresh specialist turns from other providers.

The default workflow is:

```text
Human
  |
  | PLAN conversation
  v
Codex orchestrator (default gear: Luna / max effort)
  |
  | exact /execute boundary
  v
Mighty Factory controller
  |
  | classify + deterministic route + pin base_sha
  v
Fresh Antigravity worker turn
  |
  | commit + outbox result
  v
Controller verification
  |
  | independently verify exact commit + rerun checks
  v
Fresh Cline reviewer turn in separate review worktree
  |
  | read-only review of exact verified commit + outbox result
  +---- PASS -------------------------------+
  |                                          |
  +---- FAIL -> controller state machine ----+
                  |                           |
                  +-> orchestrator repair ----+
                                              v
                                   controller final gate
                                              |
                                              v
                                            DONE
```

The system optimizes subscription usage without making provider/model/effort selection a manual chore for every task.

The controller owns lifecycle state. Models provide planning, coding, review, and bounded adjudication only.

## 2. Non-negotiable design rules

### 2.1 Herdr is transport, not lifecycle truth

Mighty Factory uses Herdr for workspaces, panes, process launch, prompting, waiting, and reading diagnostics. It does not treat Herdr terminal scrollback or lifecycle timing as canonical task state.

Relevant Herdr operations include:

- `herdr workspace create`
- `herdr worktree create`
- `herdr pane split`
- `herdr agent start`
- `herdr agent get`
- `herdr agent prompt`
- `herdr agent wait`
- `herdr agent read`

Herdr responses are parsed for returned IDs. Pane/workspace IDs are never predicted.

### 2.2 The controller owns state; the orchestrator owns judgment

The conversational Codex orchestrator owns:

- conversation with the human
- requirements clarification
- task classification judgment
- architecture/planning judgment
- creation of the task contract
- conversion of reviewer findings into a bounded repair ticket
- interpretation of escalation/adjudication results

The controller owns:

- exact `/execute` and `/cancel` authority state
- run/task/turn IDs
- legal lifecycle transitions
- retry counters
- routing from classification + durable state
- exact gear activation
- worktree and review-worktree provisioning
- artifact transport and ingestion
- pinned base commit identity
- Git verification
- authoritative verification command execution
- stale evidence invalidation
- reviewer immutability checks
- completion eligibility

The orchestrator cannot force an illegal transition or declare DONE by memory.

## 3. PLAN and EXECUTE authority boundary

PLAN is conversational and non-mutating. No worker/reviewer/arbiter agent is spawned merely because conversation sounds implementation-adjacent.

Only exact `/execute` grants mutation authority in v0.1.

`build it`, `go for it`, `fix it`, inferred intent, or similar prose does not cross the boundary.

`/cancel` prevents the next mutation-capable state transition.

Before `/execute` is accepted, the controller requires a valid task contract, valid classification, pinned target repository, and valid verification policy.

## 4. Task contract

The approved task contract is durable JSON and is created before execution.

Minimum shape:

```json
{
  "schema_version": 1,
  "summary": "Implement bounded feature X",
  "target_repo": "/absolute/path/to/repo",
  "base_ref": "main",
  "allowed_paths": ["src/", "tests/"],
  "allow_noop": false,
  "verification": {
    "policy": "repo-checks-required",
    "commands": [
      {"command": "npm", "args": ["test"]},
      {"command": "git", "args": ["diff", "--check"]}
    ]
  }
}
```

Rules:

- code-changing tasks must use `repo-checks-required`
- `repo-checks-required` requires at least one repository-specific executable check plus `git diff --check` or an equivalent syntax/whitespace check
- empty verification command arrays are invalid for code-changing tasks
- `no-executable-checks` is allowed only for task classes explicitly permitted by policy, such as pure planning; it requires a human-readable rationale
- authoritative verification commands are persisted in `task.json` and are not taken from worker prose

## 5. Classification contract

Before execution, the orchestrator emits:

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

- `scope`: `tiny | normal | broad | architectural`
- `risk`: `low | medium | high`
- `ambiguity`: `low | medium | high`
- `change_kind`: `question | docs | bugfix | feature | refactor | migration | security`
- `cross_cutting`: boolean
- `confidence`: `0.0..1.0`

Classification is model judgment. Routing is deterministic code.

## 6. Pinned Git identity

`base_ref` is resolved once during preparation to immutable `base_sha`.

The run persists both:

```json
{
  "base_ref": "main",
  "base_sha": "0123456789abcdef..."
}
```

All later ancestry checks, diffs, reviewer prompts, and completion checks use `base_sha`, never the moving branch name.

A branch moving during a run cannot change what code the run claims to review.

## 7. Correlation IDs

Every execution has controller-generated opaque IDs:

```text
run_id   one end-to-end execution
task_id  one approved task contract
turn_id  one worker, reviewer, or arbiter dispatch
```

Every prompt and result includes all active IDs. Mismatched IDs are rejected.

A turn cannot satisfy another turn even if Herdr timing appears to line up.

## 8. Fresh-turn agent model

Worker, reviewer, and escalation/adjudication specialists are **fresh per turn** in v0.1.

This is deliberate:

- a selected gear always maps to a newly launched process using that gear's exact launch spec
- escalation therefore actually changes model/effort rather than merely changing a label
- stale hidden conversation context is minimized
- each turn can be reconstructed from durable request artifacts

The human-facing Luna orchestrator remains the conversational foreman. Orchestrator escalation does not silently mutate that live session. Instead, the controller launches a bounded **orchestrator arbiter turn** using `ORCH_ESCALATE_1` when state enters `ESCALATION_PENDING`. The arbiter receives durable context and returns an adjudication artifact. Luna incorporates that result and continues as foreman.

### 8.1 Worker escalation

A normal worker turn uses `WORK_DEFAULT`.

After policy escalation, the next worker turn is a fresh process launched with `WORK_STRONG`.

The controller records the actual gear and exact launch spec for every turn.

### 8.2 Reviewer escalation

Normal review uses `REVIEW_DEFAULT`; high-risk review uses `REVIEW_STRONG` from the first review turn.

Any stronger review route also starts a fresh reviewer process.

## 9. Gear configuration and activation

A gear is not valid merely because it has a friendly alias.

Required gear shape:

```json
{
  "provider_adapter": "codex",
  "herdr_kind": "codex",
  "model_alias": "luna",
  "effort": "max",
  "launch": {
    "resolved": true,
    "model_args": ["--model", "actual-installed-model-id"],
    "effort_args": ["--config", "model_reasoning_effort=max"],
    "extra_args": []
  }
}
```

Rules:

- `launch.resolved` must be `true` for every gear reachable by v0.1 policy
- reachable gears must provide concrete launch arguments sufficient to avoid silently falling back to a provider default model or effort
- routing returns a named gear only
- provider adapters construct argv/env; routing never emits raw provider flags
- an adapter fails closed when it cannot represent the requested model/effort
- `doctor` reports configured-but-unverified model IDs honestly when provider introspection is unavailable

Required reachable gears in v0.1:

```text
ORCH_DEFAULT
ORCH_ESCALATE_1
WORK_DEFAULT
WORK_STRONG
REVIEW_DEFAULT
REVIEW_STRONG
```

A configuration missing any reachable gear is invalid.

## 10. Provider-neutral artifact transport

Direct writes to `~/.local/state/...` are not assumed to be writable from every coding-agent sandbox.

v0.1 therefore uses a **worktree outbox** transport by default.

### 10.1 Worker outbox

The controller creates an ignored local-only path inside the task worktree:

```text
.mighty-factory-outbox/<turn_id>/worker-result.json
```

The path is excluded using worktree-local Git metadata such as `.git/info/exclude`; the repository's tracked `.gitignore` is not modified.

The worker writes only its result artifact there. The controller then:

1. validates the result
2. copies/ingests it atomically into the external durable run-state root
3. records its digest
4. treats the external copy as canonical

### 10.2 Reviewer outbox

Reviewer runs in a **separate disposable review worktree** pinned to the exact verified commit.

Its outbox is:

```text
.mighty-factory-outbox/<turn_id>/review-result.json
```

Because review occurs in a separate review worktree, writing the outbox does not mutate the worker's task worktree.

Reviewer immutability checks ignore only the designated outbox path and require all tracked files plus HEAD to remain unchanged.

### 10.3 Optional direct sidecar

A provider adapter may later declare a proven `direct_sidecar` capability, but v0.1 does not require it. The default transport must work with workspace-scoped write permissions.

## 11. Durable external state

Canonical controller state lives outside the target repository:

```text
~/.local/state/mighty-factory/runs/<run_id>/
```

Shape:

```text
run.json
task.json
classification.json
state.json
events.jsonl
turns/
  <turn_id>/
    request.json
    launch.json
    ingested-result.json
    verification.json
```

Terminal scrollback is diagnostic only.

## 12. Deterministic lifecycle

Initial states:

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

Representative transitions:

```text
PLAN --human_execute + valid contract--> READY
READY --prepare--> PREPARING
PREPARING --provisioned--> WORKING
WORKING --worker_artifact_valid--> VERIFYING_WORK
VERIFYING_WORK --verification_pass--> REVIEWING
VERIFYING_WORK --verification_fail--> REPAIR_PENDING
REVIEWING --review_artifact_valid--> VERIFYING_REVIEW
VERIFYING_REVIEW --review_pass + immutable target--> DONE
VERIFYING_REVIEW --review_fail #1--> REPAIR_PENDING
VERIFYING_REVIEW --review_fail #2--> ESCALATION_PENDING
VERIFYING_REVIEW --review_fail #3--> REPLAN_REQUIRED
REPAIR_PENDING --repair_ticket_accepted--> WORKING
ESCALATION_PENDING --arbiter_result_accepted--> WORKING
any nonterminal --hard_blocker--> BLOCKED
any nonterminal --human_cancel--> CANCELLED
```

The controller rejects illegal transitions.

Retry/failure counts live in `state.json`.

## 13. Routing policy v0.1

Rules are intentionally small:

1. PLAN -> orchestrator only, no specialist spawn.
2. Normal low/medium-risk implementation -> `ORCH_DEFAULT`, `WORK_DEFAULT`, `REVIEW_DEFAULT`.
3. High risk -> `REVIEW_STRONG` from first review.
4. Broad/architectural work requires confirmed implementation plan before `/execute`.
5. Low confidence or high ambiguity blocks execution until reclassified.
6. First material review failure -> bounded repair with `WORK_DEFAULT` unless policy says strong worker is required.
7. Second material failure -> `ESCALATION_PENDING`; launch fresh `ORCH_ESCALATE_1` arbiter and next worker with `WORK_STRONG`.
8. Third material failure -> `REPLAN_REQUIRED`; no fourth blind retry.

Router output is invalid if it references a gear unavailable in validated config.

## 14. Provider launch adapters

Initial adapters:

```text
provider-adapters/codex.js
provider-adapters/cline.js
provider-adapters/antigravity.js
```

Interface:

```js
buildLaunchSpec(gear, context) -> {
  herdrKind,
  argv,
  env,
  artifactTransport
}
```

Rules:

- no raw model selection inside routing code
- no provider defaults when a model/effort-bearing gear is unresolved
- environment output is explicit and sanitized
- secrets are never printed by `print-config`

## 15. Run preparation

Preparation sequence:

1. inspect source repo without mutation
2. resolve `base_ref` to immutable `base_sha`
3. validate branch/worktree safety
4. create task worktree from `base_sha`
5. add local-only outbox exclusion
6. persist task-worktree identity
7. do not start worker/reviewer until an actual dispatch turn chooses its gear

Fresh specialist panes/processes are provisioned per turn rather than launched once and reused forever.

## 16. Worker dispatch

For each worker turn the controller:

1. selects validated worker gear
2. creates `turn_id`
3. creates `request.json` and `launch.json`
4. creates a fresh Herdr pane/process using the exact launch spec
5. prompts with run/task/turn IDs, task contract path, repair ticket if any, worktree path, and outbox result path
6. waits only from a settled state
7. ingests and validates the outbox artifact
8. records the actual launched gear/model arguments
9. transitions to verification only after correlation passes

A timeout/stall is not retried until duplicate-turn safety is proven.

## 17. Independent worker verification

Worker claims are not authoritative.

The controller verifies:

1. reported commit exists
2. task worktree HEAD equals reported commit
3. `base_sha` is an ancestor
4. base-to-head diff is non-empty unless allowed
5. tracked/untracked status matches policy
6. authoritative task-contract verification commands execute independently
7. real exit codes are captured
8. evidence is bound to exact commit SHA

Any later worker mutation makes prior verification/review stale.

## 18. Reviewer dispatch and immutability

For each review turn the controller:

1. creates a disposable review worktree pinned to the exact verified commit
2. adds only the local outbox exclusion
3. records HEAD, tracked diff/status, and base-to-head identity
4. launches a fresh reviewer process with the selected exact gear
5. provides `base_sha`, verified commit, worker verification artifact, and review outbox path
6. ingests review result
7. checks HEAD and tracked files remain unchanged except the designated ignored outbox

Reviewer PASS is rejected if it references a different commit or if tracked state changed.

## 19. Orchestrator escalation / arbiter turn

When state becomes `ESCALATION_PENDING`, Luna does not merely label itself stronger.

The controller launches a fresh Codex arbiter turn using `ORCH_ESCALATE_1`.

Input artifact contains:

- task contract
- classification
- pinned `base_sha`
- prior worker verification
- prior reviewer findings
- repair history
- exact question to adjudicate

The arbiter returns a correlated `arbiter-result.json` containing:

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "arbiter",
  "decision": "continue_with_strong_worker",
  "repair_strategy": "...",
  "confidence": 0.91
}
```

The controller validates it before allowing the next worker turn.

## 20. Controller command surface

v0.1 CLI must expose all state-changing controller operations needed by the skill:

```text
mighty-factory doctor
mighty-factory print-config
mighty-factory route
mighty-factory prepare-run
mighty-factory dispatch-worker
mighty-factory verify-worker
mighty-factory dispatch-reviewer
mighty-factory verify-review
mighty-factory dispatch-arbiter
mighty-factory record-repair
mighty-factory transition
mighty-factory status
```

The skill never calls hidden in-process methods it cannot reach from the CLI.

## 21. Doctor behavior

`doctor` is non-mutating and checks:

- Node version
- Git availability
- Herdr availability/server reachability
- config syntax
- all reachable gears exist
- all reachable gears are `launch.resolved: true`
- provider adapter can construct a concrete launch spec for every reachable gear
- state root is writable by the controller
- outbox transport can be prepared in a disposable local worktree

If provider model introspection is unavailable, `doctor` says the configured model ID is not provider-validated. It must never silently substitute defaults.

## 22. Authority boundaries

After exact `/execute`, Mighty Factory may:

- inspect repo
- create task/review worktrees and Herdr panes
- run configured coding agents
- modify only the task worktree through workers
- run verification commands
- commit task changes

It may not implicitly:

- merge to main
- deploy
- mutate production
- alter credentials
- approve billing/purchases
- auto-answer permission prompts
- reset/stash/clean unrelated user changes

## 23. Failure behavior

- blocked agent -> surface blocker, do not spam retries
- timeout/stall -> inspect state + outbox before retry
- malformed result -> one re-emit request allowed with same IDs; second failure becomes failed turn
- mismatched IDs/commit -> reject
- unresolved gear -> fail before agent launch
- verification failure -> repair/replan; worker prose cannot override
- reviewer tracked mutation -> reject review
- missing required verification commands -> reject `/execute`
- unsafe Git state -> BLOCKED without destructive cleanup

## 24. Completion gate

DONE requires all simultaneously:

1. exact active run/task IDs valid
2. exact worker turn result valid
3. task worktree HEAD equals reported commit
4. controller verification passed for exact commit using task-contract commands
5. reviewer result valid and references same commit
6. reviewer tracked state remained immutable
7. no later mutation made evidence stale
8. retry/escalation policy satisfied
9. every selected gear had a concrete recorded launch spec
10. no implicit merge/deploy/production mutation occurred

Only after controller state is `DONE` may the orchestrator summarize completion.

## 25. v0.1 completion criteria

v0.1 is successful when a provider-backed smoke run proves:

1. PLAN spawns no specialists
2. exact `/execute` is required
3. `base_ref` is pinned to `base_sha`
4. task contract contains authoritative verification commands
5. default worker launches with concrete `WORK_DEFAULT` model/effort args
6. worker result travels through the outbox and is correlated
7. controller independently verifies exact commit
8. reviewer launches fresh in separate review worktree
9. reviewer PASS targets exact verified commit and tracked files remain unchanged
10. a material FAIL produces bounded repair
11. second material FAIL launches real `ORCH_ESCALATE_1` arbiter and `WORK_STRONG` worker rather than only relabeling the state
12. third material FAIL stops at REPLAN_REQUIRED
13. stale artifacts cannot satisfy a new turn
14. main branch remains unchanged

## 26. Deferred work

Not in v0.1:

- automatic provider model-catalog discovery
- provider usage accounting
- token-price optimization
- multiple parallel workers on one task
- automatic merge/deploy
- web UI
- remote orchestration
- raw Herdr socket subscriber
- direct UAL integration
- autonomous PLAN -> EXECUTE switching
- automatic permission approval

## 27. Review corrections incorporated

Second architecture review corrections:

1. **Real gear activation:** specialist agents are fresh per turn; escalation launches a process with the new exact gear. Orchestrator escalation uses a fresh bounded arbiter turn.
2. **Reachable dispatch surface:** CLI now explicitly includes worker/reviewer/arbiter dispatch and repair-recording operations.
3. **Authoritative verification:** task contract owns required verification commands; empty code-task verification is invalid.
4. **Sandbox-safe artifacts:** default transport is a worktree outbox ingested into external durable state; reviewer uses a separate review worktree.
5. **Pinned base:** `base_ref` resolves once to immutable `base_sha`, which drives all later verification/review.
6. **Reachable gear validation:** every policy-reachable gear is mandatory in config.
7. **No lying aliases:** every reachable gear must have a concrete resolved launch spec; unresolved model/effort selection fails closed.
8. **CLI IO literal fix:** implementation uses `process.stdout` / `process.stderr`, never undefined bare `stdout` / `stderr` identifiers.

## 28. Source references

- Herdr socket API: https://herdr.dev/docs/socket-api/
- Herdr CLI reference: https://herdr.dev/docs/cli-reference/
- Herdr agent automation: https://herdr.dev/docs/agent-automation/
- Herdr agent skill: https://herdr.dev/docs/agent-skill/
- Local inspiration only: `JOHNNYMACONNY/universal-agent-loop`
- Local routing inspiration only: `JOHNNYMACONNY/mighty-router`
