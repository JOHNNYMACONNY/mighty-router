# Mighty Router — Launch & Distribution Drafts

This document contains pre-written copy, schemas, and instructions for launching **Mighty Router** to the developer community.

---

## 1. Git Repository
The repository is published on GitHub at:
[https://github.com/JOHNNYMACONNY/mighty-router](https://github.com/JOHNNYMACONNY/mighty-router)

If you make local edits and wish to push them:
```bash
git add .
git commit -m "your commit message"
git push
```

---

## 2. ClawHub / Hermes Skill Registry Submission
To register Mighty Router globally on ClawHub (the central OpenClaw/Hermes registry), users will register your repository as a "tap". 

### Registry Tap JSON Schema (`clawhub.json` / `tap.json` if needed):
If ClawHub requests a repository manifest metadata file, you can place this `clawhub.json` in the root:
```json
{
  "name": "mighty-router",
  "version": "1.0.0",
  "description": "Dynamic risk-based routing and execution profiles for AI coding agents.",
  "homepage": "https://github.com/JOHNNYMACONNY/mighty-router",
  "author": "Bobby in the Lobby",
  "license": "MIT",
  "categories": ["mighty"],
  "skills": ["mighty-router"]
}
```

### Installation Command for Users:
Once pushed, anyone can install the skill globally via CLI:
```bash
# Add the tap
hermes skills tap add JOHNNYMACONNY/mighty-router

# Install the skill
hermes skills install mighty-router
```

---

## 3. Twitter/X Launch Thread Copy

### Tweet 1 (Hook) 🪝
> AI coding agents are awesome, but they fall into two traps:
> 1. Wasting 10k tokens planning a 1-line edit (Verbosity Trap)
> 2. Bypassing safety planning and writing buggy code to critical database schemas (Bypass Trap)
> 
> I built a solution: Mighty Router. 🧵👇

### Tweet 2 (The Solution) ⚡
> Mighty Router is a lightweight, risk-based prompt routing framework for Cursor, Windsurf, Aider, and CLI agents (Hermes, Codex, OpenClaw).
> 
> It dynamically routes task requests into 4 distinct execution profiles:
> 
> 🔴 LIGHT (Minimal tokens - no edits)
> 🟢 VERIFY (UAT checks & audits)
> 🟡 STANDARD (Routine edits - 1 sentence plan)
> 🔵 FORENSIC (Complex edits - full XML safety gates)

### Tweet 3 (Auto-Escalation) 🚀
> It supports a project-level `.mightyrc` configuration file.
> 
> If a developer request targets any high-risk file path (like schemas, credentials, gateways, or SOUL.md), the agent automatically escalates its logic to FORENSIC planning.
> 
> Safe edits on critical files, lightning-fast edits everywhere else.

### Tweet 4 (Outro & Link) 🔗
> Clean, modular, and works out of the box with an automated system installer.
> 
> Check out the open-source code and templates here:
> 👉 https://github.com/JOHNNYMACONNY/mighty-router

---

## 4. Reddit Post Copy (`r/LocalLLaMA`, `r/Cursor`, `r/cline`)

**Title:** Show r/Cursor: Mighty Router – Stop your AI coding agents from wasting tokens on simple edits (and breaking critical schemas)

> Hey everyone,
>
> If you use AI coding tools like Cursor, Windsurf, Aider, or CLI agents (Hermes, OpenClaw, Codex), you’ve probably noticed two recurring issues:
>
> 1. **The Verbosity Trap:** The agent wastes thousands of tokens writing complex planning blocks, system audits, and verification logs for a simple 1-line refactor or a question.
> 2. **The Bypass Trap:** For a complex database schema change, the agent rushes ahead and edits files directly without thinking through safety checks, introducing regressions.
>
> To solve this, I built **Mighty Router**—a lightweight, risk-based execution profiling framework.
>
> ### How it works
> It routes user requests dynamically into 4 distinct profiles based on task complexity:
>
> * **`MIGHTY-LIGHT`** (Questions & Explanations): Zero code edits allowed. The agent responds in brief, telegraphic text. Saves 90%+ in token overhead.
> * **`MIGHTY-VERIFY`** (Auditing & Tests): No code edits. Agent inspects test runs on disk and returns a concise checklist of evidence.
> * **`MIGHTY-STANDARD`** (Routine Changes): Routine edits. Requires a simple 1-to-3 sentence plain text plan.
> * **`MIGHTY-FORENSIC`** (Critical Changes): Triggered automatically for sensitive files (database schemas, gateways, credentials, credentials). Enforces strict XML tags, adversarial planning, and post-action verification.
>
> ### Project-Specific Escalation (`.mightyrc`)
> You can place a `.mightyrc` file in your workspace root specifying sensitive paths. If the agent detects edits targeting these paths, it automatically escalates to the `MIGHTY-FORENSIC` gate:
>
> ```json
> {
>   "high_risk_paths": ["db/", "gateway/", "credentials", "SOUL.md"]
> }
> ```
>
> ### Easy Global Setup
> The repo comes with an automated shell script that auto-detects and symlinks the skill globally across your CLI tools, alongside ready-to-use template files for `.cursorrules`, `.windsurfrules`, `.clinerules`, and `.aider.instructions.md`.
>
> Open source, free, and MIT licensed.
>
> **GitHub Link:** https://github.com/JOHNNYMACONNY/mighty-router
>
> Let me know what you think or if you have ideas on expanding the profiles!

---

## 5. Show HN Pitch Copy

**Title:** Show HN: Mighty Router – Risk-based prompt routing for coding agents

> AI coding agents are highly capable but terribly inefficient. They either spend thousands of tokens writing long-winded plans for a simple 1-line refactor, or they bypass safety reviews entirely on critical files.
>
> Mighty Router introduces dynamic, risk-based prompt routing. It defines four execution profiles (Light, Verify, Standard, Forensic) and uses a project-level `.mightyrc` configuration to auto-escalate the agent's logic when it interacts with high-risk paths.
>
> Features:
> - Save 90%+ tokens on simple questions/queries (via MIGHTY-LIGHT rules).
> - Enforce rigid XML safety planning and post-action verification on sensitive paths (via MIGHTY-FORENSIC rules).
> - One-click global installer for terminal-based agents (Hermes, Codex, OpenClaw).
> - Drop-in rule templates for Cursor, Windsurf, Claude Code, and Aider.
>
> The project is open-source. I'd love feedback on the profiles or rules design!
