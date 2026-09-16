# Mighty Factory — Herdr Multi-Agent Software Factory Design

**Status:** Reviewed and corrected; ready for user design approval before implementation  
**Date:** 2026-09-15  
**Incubation location:** `mighty-router` branch `incubator/mighty-factory-v0` only. This design does not change Mighty Router mainline behavior and does not modify `universal-agent-loop`.

## 1. Goal

Build a small local orchestration layer that lets one coding agent act as the foreman while Herdr coordinates specialist agents from different providers.

The first practical workflow is:

```text
Human
  |
  | PLAN conversation
  v
Codex orchestrator (default: Luna / max effort)
  |
  | exact /execute boundary
  v
Mighty Factory controller
  |
  | classify + deterministic route + prepare run
  v
Antigravity worker (default configured worker gear)
  |
  | durable result artifact + commit
  v
Controller verification
  |
  | exact commit + independently rerun checks
  v
Cline reviewer (default configured review gear)
  |
  | durable review artifact
  +---- PASS ------------------------------+
  |                                         |
  +---- FAIL -> controller state machine ---+
                  |                          |
                  +-> orchestrator repair ---+
                                             v
                                  controller final gate
                                             |
                                             v
                                           done
```

The system should optimize subscription usage without making model selection a manual chore on every task.

The controller, not an LLM prompt, owns lifecycle state, correlation IDs, legal transitions, retry counts, stale-evidence invalidation, and final completion checks.

## 2. Core design decisions

### 2.1 Herdr is the transport and process control plane

Do not reimplement terminal multiplexing, agent detection, pane control, worktree creation, lifecycle waiting, or prompt delivery.

Mighty Factory uses Herdr's supported automation surface, including:

- `herdr workspace create`
- `herdr worktree create`
- `herdr pane split`
- `herdr agent start`
- `herdr agent get`
- `herdr agent prompt`
- `herdr agent wait`
- `herdr agent read`

Herdr's CLI wrappers are the v0.1 control surface. Raw socket access is deferred until a concrete need appears.

Important Herdr behavior that the design must respect:

- `agent start` requires an already-existing shell pane; it does not create layout.
- `agent prompt --wait` does not track a unique logical turn when the target is already working.
- a timeout or `agent_prompt_stalled` does not prove the prompt was not delivered.
- terminal reads are bounded snapshots, not durable application state.

Mighty Factory therefore adds its own correlation and durable artifact protocol above Herdr without replacing Herdr itself.

### 2.2 The orchestrator owns judgment; the controller owns state

The Codex orchestrator owns:

- conversation with the human
- task understanding
- task classification judgment
- architecture/planning judgment
- conversion of reviewer findings into a bounded repair ticket
- escalation judgment when policy explicitly requests an orchestrator decision

The deterministic Mighty Factory controller owns:

- run/task/turn identifiers
- legal lifecycle transitions
- retry counters
- gear selection from classification + state
- worktree/pane/agent provisioning
- durable artifact paths
- validation of worker/reviewer result schemas
- verification that result IDs and commit IDs match the active run
- verification that expected Git state exists
- independent execution of authoritative verification commands
- invalidation of stale verification/review evidence after mutations
- stop conditions
- completion eligibility

Worker and reviewer do not directly negotiate with one another.

Material flow is:

```text
worker -> controller -> orchestrator -> controller -> reviewer -> controller
                                    ^                           |
                                    +--------- repair ----------+
```

The orchestrator may provide judgment inputs, but it cannot directly force an illegal state transition.

### 2.3 Model choice and effort choice are policy, not vibes

The orchestrator may classify a task, but it does not freely invent a provider/model/effort combination.

A deterministic router maps classification + loop state into one of a small set of named **gears**.

Conceptual gears:

```text
ORCH_DEFAULT      Codex default orchestration model, max effort
ORCH_ESCALATE_1   stronger Codex gear, configured effort
ORCH_ESCALATE_2   strongest normal Codex gear, configured effort

WORK_DEFAULT      default Antigravity worker gear
WORK_STRONG       stronger worker gear

REVIEW_DEFAULT    default ClinePass review gear
REVIEW_STRONG     stronger cross-family review gear
```

Exact provider model identifiers stay in user-editable config because catalogs and subscription offerings change.

### 2.4 Luna's default orchestration effort is fixed at max

For the user's current usage economics, the default Luna orchestration gear is intentionally fixed at max effort.

Dynamic effort selection applies only to escalation gears where the user benefits from trading usage for capability.

The router chooses a named gear. It never separately improvises model + effort combinations at runtime.

### 2.5 PLAN and EXECUTE are separate authority modes

Mighty Factory must not spawn implementation workers because a conversation merely sounds implementation-adjacent.

Default behavior:

- **PLAN mode:** human + orchestrator only. Brainstorm, inspect, clarify, design, and create a task contract.
- **EXECUTE mode:** entered only after the human sends the exact command `/execute` in v0.1.

`build it`, `go for it`, `fix it`, or inferred intent do **not** cross the mutation boundary in v0.1 unless the integration layer has first converted them into a visible `/execute` request and the human sends that command.

A future version may support configurable aliases, but v0.1 uses one hard boundary to avoid accidental spend and mutation.

`/cancel` stops before the next mutation-capable state transition.

## 3. Influences without coupling

### 3.1 Matt Pocock-style skill architecture

Use small reusable skills / prompt contracts instead of one giant orchestration prompt.

Initial roles:

- `mighty-factory-orchestrator`
- worker contract
- reviewer contract

Each role gets a narrow responsibility, explicit inputs, explicit outputs, and completion criteria.

### 3.2 Gauntlet-loop ideas

Adopt the useful parts:

- implementation and review are independent turns
- reviewer is expected to look for failure, not rubber-stamp
- every material review finding must be grounded in observable evidence
- repair is bounded
- repeated failure changes strategy instead of repeating the same prompt forever
- a mutation makes previous review evidence stale

Do **not** build an infinite autonomous loop.

### 3.3 UAL ideas

Borrow invariants, not code or lifecycle ownership:

- artifacts and evidence are the source of truth
- implementation authority is separate from merge/deploy authority
- durable handoffs are structured
- old verification becomes stale after implementation changes

Mighty Factory remains a separate project and can later integrate with UAL if that becomes useful.

### 3.4 Mighty Router ideas

Reuse the risk-classification philosophy conceptually, but keep the first Factory router self-contained.

A later integration can import Mighty Router profiles once the Factory loop proves itself.

## 4. Task classification contract

Before execution, the orchestrator emits a small JSON classification object.

Example:

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

Allowed initial values:

- `scope`: `tiny | normal | broad | architectural`
- `risk`: `low | medium | high`
- `ambiguity`: `low | medium | high`
- `change_kind`: `question | docs | bugfix | feature | refactor | migration | security`
- `cross_cutting`: boolean
- `confidence`: `0.0..1.0`

Classification is model judgment. Routing is deterministic code.

## 5. Run and turn correlation

Every execution has controller-generated opaque identifiers:

```text
run_id   one end-to-end execution attempt
task_id  one approved task contract within the run
turn_id  one worker or reviewer dispatch
```

Example:

```json
{
  "run_id": "run_01J...",
  "task_id": "task_01J...",
  "turn_id": "turn_01J..."
}
```

Rules:

1. IDs are generated by the controller, never by an agent.
2. Every worker/reviewer prompt contains the active IDs.
3. Every durable result artifact must echo all active IDs.
4. Every result must also identify the exact expected commit when a commit exists.
5. Mismatched IDs are rejected as stale or unrelated output.
6. A turn cannot satisfy another turn, even if terminal timing appears correct.
7. Before sending a new prompt, the controller must establish that the target agent is in a settled input-ready state. It must not intentionally dispatch a new logical turn to an already-working agent.

For Herdr:

- if the target is `working`, wait for `idle` or `done` before dispatch
- if the target is `blocked`, surface the block instead of prompting
- if status is `unknown`, do not treat that as successful completion
- only after a settled precondition is established may the controller call `agent prompt --wait`

This avoids relying on Herdr's lifecycle wait as a unique-turn protocol.

## 6. Durable artifact protocol

Terminal scrollback is observability only. It is not the source of truth for structured handoff state.

The controller creates a run artifact directory outside the target repository so result files do not dirty the user's project.

Default state root:

```text
~/.local/state/mighty-factory/runs/<run_id>/
```

Config may override the root.

Initial shape:

```text
<run_id>/
  run.json
  task.json
  classification.json
  state.json
  events.jsonl
  turns/
    <turn_id>/
      request.json
      worker-result.json
      worker-verification.json
      review-result.json
      review-verification.json
```

Only files relevant to a specific turn need to exist.

The controller passes the exact expected result path to the agent. The agent writes that file atomically where practical and may print a short human-readable completion note to the terminal.

Terminal output is never parsed as the canonical worker/reviewer JSON when the durable result artifact exists.

### 6.1 Worker result schema

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "worker",
  "status": "implemented",
  "commit": "<sha>",
  "summary": "...",
  "reported_tests": [
    {
      "command": "npm test",
      "result": "pass"
    }
  ],
  "known_limitations": []
}
```

If blocked:

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "worker",
  "status": "blocked",
  "blocker": "..."
}
```

Worker-reported tests are informative. They are not authoritative completion evidence.

### 6.2 Reviewer result schema

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "reviewer",
  "reviewed_commit": "<sha>",
  "verdict": "PASS",
  "findings": [],
  "evidence_checked": ["base_to_head_diff", "controller_verification"],
  "confidence": 0.93
}
```

or:

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "role": "reviewer",
  "reviewed_commit": "<sha>",
  "verdict": "FAIL",
  "findings": [
    {
      "severity": "material",
      "location": "src/example.ts:42",
      "problem": "...",
      "required_fix": "..."
    }
  ],
  "evidence_checked": ["base_to_head_diff", "controller_verification"],
  "confidence": 0.91
}
```

Reviewer prose may accompany the artifact, but the artifact drives state transitions.

## 7. Deterministic lifecycle state machine

The controller owns lifecycle transitions in code. The skill/orchestrator may request an event, but it may not invent the next state.

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

Representative legal transitions:

```text
PLAN --human /execute + valid task contract--> READY
READY --prepare--> PREPARING
PREPARING --provisioned--> WORKING
WORKING --valid worker artifact--> VERIFYING_WORK
VERIFYING_WORK --verification pass--> REVIEWING
VERIFYING_WORK --verification fail--> REPAIR_PENDING
REVIEWING --valid review artifact--> VERIFYING_REVIEW
VERIFYING_REVIEW --review pass + immutable target--> DONE
VERIFYING_REVIEW --review fail #1--> REPAIR_PENDING
VERIFYING_REVIEW --review fail #2--> ESCALATION_PENDING
VERIFYING_REVIEW --review fail #3--> REPLAN_REQUIRED
REPAIR_PENDING --repair ticket accepted--> WORKING
ESCALATION_PENDING --new gear/strategy chosen--> WORKING
any nonterminal state --hard external blocker--> BLOCKED
any nonterminal state --human /cancel--> CANCELLED
```

The implementation must reject illegal transitions rather than silently coercing them.

Retry count and material-failure count live in `state.json`, not in chat memory.

## 8. Routing policy v0.1

The first router should have very few rules.

1. **Planning / brainstorming**
   - Orchestrator only.
   - Never spawn a worker or reviewer.

2. **Low/medium-risk normal implementation**
   - `ORCH_DEFAULT`
   - `WORK_DEFAULT`
   - `REVIEW_DEFAULT`

3. **Broad or architectural work**
   - Orchestrator must produce or confirm an implementation plan before `/execute` is accepted.
   - Escalate orchestrator only if the default orchestrator reports low confidence, cannot resolve architecture, or worker/reviewer disagreement remains material.

4. **High-risk work**
   - Force `REVIEW_STRONG` regardless of worker self-reported success.
   - Require explicit controller verification commands relevant to the repository.

5. **Review failure**
   - First material failure: controller requests a bounded repair ticket from the orchestrator for the same worker gear unless policy says otherwise.
   - Second consecutive material failure: controller enters `ESCALATION_PENDING`; deterministic policy bumps one permitted gear and asks the orchestrator for any needed strategy adjustment.
   - Third material failure: controller enters `REPLAN_REQUIRED`. No fourth blind retry.

6. **Low confidence before mutation**
   - If classification confidence is below the configured threshold or ambiguity is high, `/execute` is rejected until the orchestrator resolves the uncertainty and emits a new task contract/classification.

## 9. Effort policy

Effort is attached to gears rather than selected independently every turn.

This eliminates the combinatorial "which model + which effort" decision.

Example configuration shape:

```json
{
  "gears": {
    "ORCH_DEFAULT": {
      "provider_adapter": "codex",
      "herdr_kind": "<configured-kind>",
      "model_alias": "luna",
      "effort": "max"
    },
    "ORCH_ESCALATE_1": {
      "provider_adapter": "codex",
      "herdr_kind": "<configured-kind>",
      "model_alias": "strong",
      "effort": "high"
    },
    "WORK_DEFAULT": {
      "provider_adapter": "antigravity",
      "herdr_kind": "<configured-kind>",
      "model_alias": "flash",
      "effort": "high"
    },
    "REVIEW_DEFAULT": {
      "provider_adapter": "cline",
      "herdr_kind": "<configured-kind>",
      "model_alias": "review-default",
      "effort": "high"
    }
  }
}
```

The config stores aliases and launch settings separately so model-name churn does not infect routing logic.

## 10. Provider launch adapters

Routing returns only a named gear. Provider-specific argument construction lives behind adapters.

Initial adapters:

```text
provider-adapters/codex.js
provider-adapters/cline.js
provider-adapters/antigravity.js
```

Each adapter exposes a narrow interface conceptually equivalent to:

```js
buildLaunchSpec(gear, context) -> {
  herdrKind,
  argv,
  env
}
```

Rules:

- routing code never constructs provider CLI flags
- prompts never choose raw model IDs
- aliases resolve through config
- an adapter must fail closed when it cannot represent a configured effort/model combination
- `doctor` validates required adapter/config fields before execution
- v0.1 does not attempt automatic provider model-catalog discovery

## 11. Workspace and Git isolation

Each execution gets an isolated Git worktree whenever the target repository supports it.

The controller owns provisioning.

Conceptual preparation sequence:

1. inspect target repo and current Git state
2. resolve base ref and create task branch name
3. call `herdr worktree create` for the task branch
4. capture the returned workspace, tab, root pane, worktree path, and branch
5. split additional worker/reviewer panes as needed
6. start or resolve named agents in those panes
7. persist all returned Herdr IDs in `run.json`
8. only then enter `WORKING`

Rules:

- worker writes only inside the task worktree
- worker commits each accepted implementation unit
- reviewer reviews the exact controller-verified commit/diff
- reviewer is instructed not to modify files
- controller records Git status/HEAD before review and checks them again after review
- any reviewer mutation invalidates that review and is treated as a failed review turn
- a repair mutation invalidates previous controller verification and review evidence
- no automatic merge to the user's main branch in v0.1

Dirty/conflicting source repo behavior:

- do not rewrite, stash, reset, or clean the user's source repo automatically
- Herdr worktree creation may proceed only when the controller can prove the chosen base/ref and target branch are safe
- otherwise enter `BLOCKED` and surface the exact condition

## 12. Independent controller verification

Worker claims are never sufficient for completion.

After a worker artifact passes schema/correlation validation, the controller verifies at minimum:

1. the reported commit exists
2. the task worktree `HEAD` equals the reported commit
3. the reported commit descends from the expected base according to the run contract
4. the base-to-head diff is non-empty unless the task legitimately permits a no-op result
5. Git status matches the task policy
6. configured authoritative verification commands execute independently and their real exit codes are captured
7. generated verification evidence is bound to the exact commit SHA

The task contract contains the authoritative verification commands chosen during planning or repository inspection.

Example verification artifact:

```json
{
  "schema_version": 1,
  "run_id": "run_...",
  "task_id": "task_...",
  "turn_id": "turn_...",
  "verified_commit": "abc123",
  "git": {
    "head_matches": true,
    "base_is_ancestor": true,
    "worktree_clean": true
  },
  "commands": [
    {
      "command": "npm test",
      "exit_code": 0
    }
  ],
  "result": "pass"
}
```

If a worker changes code after verification, the controller marks that verification stale and requires a new verification artifact.

Reviewer PASS is not eligible for `DONE` unless it references the same verified commit.

## 13. Reviewer immutability check

The reviewer is logically read-only in v0.1.

Before review, the controller records:

- expected HEAD
- Git status
- diff hash or equivalent exact base/head identity

After review, it checks again.

If the reviewer modified files, changed HEAD, or otherwise changed the target under review:

- reject the review result
- mark the review turn invalid
- restore nothing automatically unless a future explicit safe mechanism is designed
- enter `BLOCKED` or `REPAIR_PENDING` according to the exact condition

This makes reviewer independence observable instead of purely prompt-based.

## 14. Herdr dispatch protocol

Mighty Factory uses named live agents so routing targets are stable.

A logical dispatch must follow this order:

```text
1. resolve target agent
2. inspect lifecycle status
3. if working -> wait for idle/done
4. if blocked -> surface blocker
5. if unknown -> refuse to infer success; inspect/wait according to policy
6. create turn_id and request.json
7. send prompt with run_id/task_id/turn_id/result_path
8. use agent prompt --wait from the settled state
9. on timeout/stall, inspect agent before any retry
10. read durable result artifact
11. validate IDs/schema
12. transition through controller state machine
```

Conceptual prompt:

```text
RUN_ID: run_...
TASK_ID: task_...
TURN_ID: turn_...
EXPECTED_RESULT_PATH: /Users/.../.local/state/mighty-factory/runs/run_.../turns/turn_.../worker-result.json

Perform only the attached task contract.
Write the final structured result to EXPECTED_RESULT_PATH.
Do not invent a different run/task/turn identifier.
```

Terminal reads remain useful for diagnosis and blocker handling but do not drive successful state transitions when a durable result is expected.

## 15. Proposed project structure

```text
mighty-factory/
  README.md
  package.json
  factory.config.example.json
  bin/
    mighty-factory.js
  src/
    classify-schema.js
    route.js
    state-machine.js
    state-store.js
    artifacts.js
    config.js
    git-verify.js
    verifier.js
    herdr.js
    prepare-run.js
    provider-adapters/
      codex.js
      cline.js
      antigravity.js
  skills/
    mighty-factory-orchestrator/
      SKILL.md
  prompts/
    worker.md
    reviewer.md
  tests/
    classify-schema.test.js
    route.test.js
    state-machine.test.js
    state-store.test.js
    artifacts.test.js
    config.test.js
    git-verify.test.js
    verifier.test.js
    provider-adapters.test.js
  docs/
    superpowers/
      specs/
      plans/
```

Keep the Node runtime dependency-free for v0.1 where practical. Use built-in Node modules and `node:test`.

If a tiny dependency becomes necessary for correctness, it requires an explicit design update rather than silently changing this constraint.

## 16. CLI scope v0.1

The deterministic CLI exposes enough operations to make lifecycle state observable and enforceable:

```text
mighty-factory doctor
mighty-factory print-config
mighty-factory route --classification '<json>' --state '<json>'
mighty-factory prepare-run --repo <path> --task <task.json>
mighty-factory transition --run <run_id> --event <event> [--input <artifact-path>]
mighty-factory verify-worker --run <run_id> --turn <turn_id>
mighty-factory verify-review --run <run_id> --turn <turn_id>
mighty-factory status --run <run_id>
```

The **agent skill** owns conversation and judgment requests.

The **CLI/controller** owns state, correlation, routing, provisioning, validation, and verification.

The skill may call controller commands, but it must follow the controller's returned state/action rather than maintaining an independent hidden lifecycle in prompt memory.

Do not build a daemon, database, dashboard, scheduler, remote service, or raw socket client yet.

## 17. `doctor` behavior

`doctor` is non-mutating.

It checks:

- supported Node version
- config parses
- required gears exist
- required provider adapters are known
- each configured gear has the adapter fields required to construct a launch spec
- `herdr` is on PATH
- Herdr server is reachable
- `HERDR_ENV=1` when an in-Herdr orchestration session is required
- Herdr can list/get agents
- Git is available
- configured state root is writable

It should report actionable failures, not try to install providers, log users in, purchase usage, or mutate account settings.

It does not claim a configured model identifier is valid unless the relevant provider can actually confirm that through a supported non-mutating mechanism.

## 18. Authority boundaries

By default Mighty Factory may, **after exact `/execute` authority**:

- inspect the target repository
- create a task-local worktree / branch
- create Herdr panes/workspaces needed for that run
- run configured coding agents
- modify the task worktree through the worker
- run configured tests/static checks
- commit to the task branch

By default it may **not**:

- merge to main
- deploy
- mutate production
- change credentials
- approve billing / purchases
- bypass interactive permission prompts
- delete unrelated branches/worktrees
- reset/stash/clean unrelated user changes

Those require separate explicit authority.

## 19. Failure behavior

### Agent blocked

`agent_blocked` or observed `blocked` state surfaces the exact blocker. Do not spam prompts or auto-answer permission dialogs.

### Prompt stalled or timeout

A stalled/timed-out prompt may have been delivered. Before retrying:

1. inspect agent state/output
2. check whether the expected durable result artifact appeared
3. check whether the active turn IDs match
4. retry only if the controller can prove doing so will not create a duplicate logical turn

If that proof is unavailable, enter `BLOCKED` instead of guessing.

### Missing or malformed result artifact

The controller may ask the same settled agent once to re-emit the **result artifact only**, using the same run/task/turn IDs, if the underlying work is otherwise complete.

A second malformed/missing result is a failed agent turn and follows normal escalation/replanning policy.

### Stale or mismatched artifact

Reject it. Never coerce IDs or commit SHAs to the active run.

### Verification failure

A controller verification failure cannot be overruled by worker prose. It becomes a repair/replan event according to policy.

### Dirty/conflicting target state

Stop before destructive cleanup. Surface the exact Git condition.

## 20. Completion gate

`DONE` requires all of the following to be simultaneously true:

1. active run/task IDs are valid
2. active worker turn produced a schema-valid, correlation-valid result
3. reported commit exists and matches task worktree HEAD
4. controller verification passed for that exact commit
5. reviewer result is schema-valid and correlation-valid
6. reviewer PASS references that same exact commit
7. reviewer did not mutate the reviewed target
8. no later mutation has made verification/review evidence stale
9. retry/escalation policy is satisfied
10. no implicit merge/deploy/production mutation occurred

The orchestrator may summarize completion only after the controller reports `DONE`.

## 21. Completion criteria for v0.1

v0.1 is successful when, on the user's Mac inside Herdr:

1. Codex can remain the conversational orchestrator in PLAN mode without spawning other agents.
2. Only exact `/execute` crosses into mutation-capable execution.
3. `prepare-run` creates/opens an isolated task worktree and provisions required panes/agents deterministically.
4. The router selects configured gears from classification + durable loop state.
5. A worker turn is correlated with unique run/task/turn IDs and writes a durable result artifact.
6. Controller verification independently proves Git identity and reruns authoritative verification commands.
7. A reviewer independently reviews the exact verified commit and writes a durable review artifact.
8. Reviewer mutation is detected and invalidates the review.
9. A reviewer FAIL produces one bounded repair turn through the orchestrator/controller.
10. Repeated failure escalates according to policy and eventually stops rather than looping forever.
11. A stale terminal completion or artifact from another turn cannot satisfy the active turn.
12. The exact commit and controller verification evidence are surfaced at completion.
13. No main-branch merge or deployment happens implicitly.
14. Provider model names and effort levels can be changed in config without editing routing/state-machine code.

## 22. Deferred work

Not in v0.1:

- automatic provider model-catalog discovery
- usage accounting from provider APIs
- token-price optimization
- multiple parallel workers on the same task
- automatic merge/deploy
- web UI
- remote orchestration
- raw Herdr socket subscriber
- direct UAL integration
- autonomous PLAN -> EXECUTE mode switching
- automatic permission-dialog approval
- cross-machine run migration

These should be added only after the basic foreman -> worker -> controller verification -> reviewer loop is boring and reliable.

## 23. Review corrections incorporated

The architecture review identified seven concrete gaps. This revision resolves them as follows:

1. **Turn correlation:** controller-generated `run_id`, `task_id`, and `turn_id`; settled-agent precondition; result ID validation.
2. **Scrollback as handoff:** canonical results moved to durable run artifacts outside the target repo; terminal output is diagnostic only.
3. **Prompt-owned lifecycle:** explicit deterministic state machine and `transition` command now own legal next states/retry counters.
4. **Unverified worker claims:** controller independently verifies commit ancestry/HEAD/status and reruns authoritative verification commands.
5. **Pane provisioning gap:** `prepare-run` owns Herdr worktree/workspace/pane provisioning before agent start.
6. **Provider flag leakage:** provider launch adapters convert named gears into Herdr kind/argv/env launch specs.
7. **Fuzzy PLAN -> EXECUTE:** v0.1 uses exact `/execute` and `/cancel` commands only.

## 24. Source references

Herdr behavior used by this design should be rechecked against the installed/current Herdr version during implementation.

- Herdr agent automation: https://herdr.dev/docs/agent-automation/
- Herdr CLI reference: https://herdr.dev/docs/cli-reference/
- Herdr socket API: https://herdr.dev/docs/socket-api/
- Herdr configuration: https://herdr.dev/docs/configuration/
- Local inspiration only: `JOHNNYMACONNY/universal-agent-loop`
- Local routing inspiration only: `JOHNNYMACONNY/mighty-router`
