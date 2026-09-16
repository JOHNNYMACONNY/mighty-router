# Mighty Factory — Herdr Multi-Agent Software Factory Design

**Status:** Design candidate for user review  
**Date:** 2026-09-15  
**Incubation location:** `mighty-router` branch `incubator/mighty-factory-v0` only. This design does not change Mighty Router mainline behavior and does not modify `universal-agent-loop`.

## 1. Goal

Build a small local orchestration layer that lets one coding agent act as the foreman while Herdr coordinates specialist agents from different providers.

The first practical workflow is:

```text
Human
  |
  v
Codex orchestrator (default: Luna / max effort)
  |
  | classify + route
  v
Antigravity worker (default: Gemini Flash / high)
  |
  | commit + tests + evidence
  v
Cline reviewer (default: configured ClinePass review gear)
  |
  +---- PASS ------------------------------+
  |                                         |
  +---- FAIL -> orchestrator -> repair -----+
                                            |
                                            v
                                  orchestrator final gate
                                            |
                                            v
                                          done
```

The system should optimize subscription usage without making model selection a manual chore on every task.

## 2. Core design decisions

### 2.1 Herdr is the transport and process control plane

Do not reimplement terminal multiplexing, agent lifecycle detection, pane control, waiting, or prompt delivery.

Mighty Factory uses Herdr's supported automation surface:

- `herdr agent start`
- `herdr agent prompt`
- `herdr agent wait`
- `herdr agent read`
- Herdr worktree helpers when available

Herdr's own documentation recommends the CLI wrappers for simple orchestration. Raw socket access is deferred until a concrete need appears.

### 2.2 The orchestrator owns the loop

Reviewer and worker do not directly negotiate with one another.

All material state transitions return to the orchestrator:

```text
worker -> orchestrator -> reviewer -> orchestrator -> worker
```

This prevents two specialist agents from silently changing scope or creating an uncontrolled repair loop.

### 2.3 Model choice and effort choice are policy, not vibes

The orchestrator may classify a task, but it does not freely invent a provider/model/effort combination.

A deterministic router maps classification + loop state into one of a small set of named **gears**.

Example concepts:

```text
ORCH_DEFAULT      Codex Luna, max
ORCH_ESCALATE_1   stronger Codex gear, configured effort
ORCH_ESCALATE_2   strongest normal Codex gear, configured effort

WORK_DEFAULT      Antigravity Gemini Flash, high
WORK_STRONG       alternate stronger worker gear

REVIEW_DEFAULT    ClinePass review gear
REVIEW_STRONG     stronger cross-family review gear
```

Exact provider model identifiers stay in user-editable config because catalogs and subscription offerings change.

### 2.4 Luna's default orchestration effort is fixed at max

For the user's current usage economics, Luna is cheap enough that reducing its reasoning effort creates little value. `ORCH_DEFAULT` therefore always uses max effort.

Dynamic effort selection applies only to gears where the user actually benefits from trading usage for capability.

### 2.5 Planning and execution are separate modes

Mighty Factory must not spawn implementation workers because a conversation merely sounds implementation-adjacent.

Default behavior:

- **PLAN mode:** human + orchestrator only. Brainstorm, inspect, clarify, design, create a task contract.
- **EXECUTE mode:** entered only after explicit human authorization such as `execute`, `build it`, or an equivalent command recognized by the skill.

The orchestrator may say that a plan appears executable, but it cannot cross the boundary by itself in v0.1.

This avoids accidental token spend and accidental repository mutation during brainstorming.

## 3. Influences without coupling

### 3.1 Matt Pocock-style skill architecture

Use small reusable skills / prompt contracts instead of one giant orchestration prompt.

Initial roles:

- `mighty-factory-orchestrator`
- worker contract
- reviewer contract
- optional arbiter contract later

Each role gets a narrow responsibility, explicit inputs, explicit outputs, and completion criteria.

### 3.2 Gauntlet-loop ideas

Adopt the useful parts:

- implementation and review are independent turns
- reviewer is expected to look for failure, not rubber-stamp
- every review finding must be grounded in observable evidence
- repair is bounded
- repeated failure changes strategy instead of repeating the same prompt forever

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

A later integration can import Mighty Router profiles rather than duplicating them once the Factory loop proves itself.

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

Classification is judgment. Routing is deterministic code.

## 5. Routing policy v0.1

The first router should have very few rules.

1. **Planning / brainstorming**
   - Orchestrator only.
   - Never spawn a worker or reviewer.

2. **Low/medium-risk normal implementation**
   - `ORCH_DEFAULT`
   - `WORK_DEFAULT`
   - `REVIEW_DEFAULT`

3. **Broad or architectural work**
   - Orchestrator must produce or confirm an implementation plan before worker execution.
   - Escalate orchestrator only if Luna reports low confidence, cannot resolve architecture, or worker/reviewer disagreement remains material.

4. **High-risk work**
   - Force `REVIEW_STRONG` regardless of worker success.
   - Require explicit final evidence from tests / checks relevant to the repository.

5. **Review failure**
   - First failure: orchestrator converts reviewer findings into a bounded repair ticket for the same worker.
   - Second consecutive material failure: reclassify and escalate one gear where policy allows it.
   - Third material failure: stop the implementation loop and return to replanning. No fourth blind retry.

6. **Low confidence before mutation**
   - If classification confidence is below the configured threshold or ambiguity is high, do not implement yet. Ask or inspect first.

## 6. Effort policy

Effort is attached to gears rather than selected independently every turn.

This eliminates a combinatorial "which model + which effort" decision.

Example configuration shape:

```json
{
  "gears": {
    "ORCH_DEFAULT": {
      "agent": "codex",
      "model_alias": "luna",
      "effort": "max"
    },
    "ORCH_ESCALATE_1": {
      "agent": "codex",
      "model_alias": "strong",
      "effort": "high"
    },
    "WORK_DEFAULT": {
      "agent": "agy",
      "model_alias": "flash",
      "effort": "high"
    },
    "REVIEW_DEFAULT": {
      "agent": "cline",
      "model_alias": "review-default",
      "effort": "high"
    }
  }
}
```

The config stores aliases and launch arguments separately so model-name churn does not infect routing logic.

## 7. Workspace / git isolation

Each execution gets an isolated git worktree whenever the target repository supports it.

Rules:

- worker writes only inside the task worktree
- worker commits each accepted implementation unit
- reviewer reviews the exact commit/diff under consideration
- reviewer does not modify files in the normal path
- a repair mutation invalidates the previous review evidence
- no automatic merge to the user's main branch in v0.1

The orchestrator reports the final branch/worktree and evidence to the human.

## 8. Handoff contracts

### Worker result

Worker must finish with structured evidence similar to:

```json
{
  "status": "implemented",
  "commit": "<sha>",
  "summary": "...",
  "tests": [
    {"command": "...", "result": "pass"}
  ],
  "known_limitations": []
}
```

If blocked, it says why instead of claiming completion.

### Reviewer result

Reviewer returns:

```json
{
  "verdict": "PASS",
  "findings": [],
  "evidence_checked": ["diff", "tests"],
  "confidence": 0.93
}
```

or:

```json
{
  "verdict": "FAIL",
  "findings": [
    {
      "severity": "material",
      "location": "src/example.ts:42",
      "problem": "...",
      "required_fix": "..."
    }
  ],
  "evidence_checked": ["diff", "tests"],
  "confidence": 0.91
}
```

Reviewer prose can accompany the object, but the object drives state transitions.

## 9. Herdr interaction pattern

Mighty Factory uses named live agents so routing targets are stable.

Conceptual flow:

```bash
# start or resolve named agents in panes
herdr agent start worker --kind agy --pane <pane> -- <configured args>
herdr agent start reviewer --kind cline --pane <pane> -- <configured args>

# dispatch
herdr agent prompt worker "<worker ticket>" --wait --until idle --until done
herdr agent read worker --source recent-unwrapped --lines 160

# review
herdr agent prompt reviewer "<review contract + commit>" --wait --until idle --until done
herdr agent read reviewer --source recent-unwrapped --lines 160
```

The implementation should prefer Herdr's CLI wrappers over raw socket code in v0.1.

## 10. Proposed project structure

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
    loop-state.js
    config.js
  skills/
    mighty-factory-orchestrator/
      SKILL.md
  prompts/
    worker.md
    reviewer.md
  tests/
    route.test.js
    loop-state.test.js
    config.test.js
  docs/
    superpowers/
      specs/
      plans/
```

Keep Node runtime dependency-free for v0.1. Use `node:test`.

## 11. CLI scope v0.1

Only implement what makes the orchestration observable and testable:

```text
mighty-factory route --classification '<json>' --state '<json>'
mighty-factory doctor
mighty-factory print-config
```

The **agent skill** owns the conversational loop and calls Herdr. The deterministic CLI owns routing and config validation.

Do not build a daemon, database, dashboard, scheduler, remote service, or raw socket client yet.

## 12. `doctor` behavior

`doctor` should check, without mutation:

- Node version supported
- config parses
- required gears exist
- `herdr` is on PATH
- running inside Herdr when an orchestration session is expected (`HERDR_ENV=1`)
- Herdr can list agents
- configured role targets / launch kinds are valid enough to proceed

It should report actionable failures, not try to install providers or log users in.

## 13. Authority boundaries

By default Mighty Factory may:

- inspect target repository
- create task-local worktrees / branches
- run configured coding agents
- modify the task worktree through the worker
- run tests and static checks
- commit to the task branch

By default it may **not**:

- merge to main
- deploy
- mutate production
- change credentials
- approve billing / purchases
- bypass interactive permission prompts
- delete unrelated branches/worktrees

Those require separate explicit authority.

## 14. Failure behavior

- `agent_blocked`: surface the exact blocker to the orchestrator/human. Do not spam retries.
- `agent_prompt_stalled` / timeout: inspect agent output before deciding whether to retry, because Herdr documents that input may already have been delivered.
- malformed worker/reviewer JSON: orchestrator may ask the same agent once to re-emit the result contract without redoing the work.
- repeated malformed output: treat as a failed agent turn and escalate/replan according to policy.
- dirty or conflicting target repo: stop before creating a worktree unless the isolation method is proven safe.

## 15. Completion criteria for v0.1

v0.1 is successful when, on the user's Mac inside Herdr:

1. Codex can remain the conversational orchestrator in PLAN mode without spawning other agents.
2. Explicit execution triggers one worker turn and one independent review turn.
3. The deterministic router selects configured gears from classification + loop state.
4. A reviewer FAIL produces one bounded repair turn through the orchestrator.
5. Repeated failure escalates according to policy and eventually stops rather than looping forever.
6. The exact commit and verification evidence are surfaced at completion.
7. No main-branch merge or deployment happens implicitly.
8. Provider model names and effort levels can be changed in config without editing routing code.

## 16. Deferred work

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

These should be added only after the basic foreman -> worker -> reviewer loop is boring and reliable.

## 17. Source references

- Herdr socket API: https://herdr.dev/docs/socket-api/
- Herdr CLI reference: https://herdr.dev/docs/cli-reference/
- Herdr agent automation: https://herdr.dev/docs/agent-automation/
- Herdr agent skill: https://herdr.dev/docs/agent-skill/
- Local inspiration only: `JOHNNYMACONNY/universal-agent-loop`
- Local routing inspiration only: `JOHNNYMACONNY/mighty-router`
