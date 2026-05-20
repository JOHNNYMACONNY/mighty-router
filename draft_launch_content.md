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

## 3. Twitter/X Launch Thread Copy

### Tweet 1 (The Hook) 🪝
> Ever get frustrated when your AI coding tool:
> 1. Wastes 2 minutes writing a giant plan for a simple 1-line change? (Time/Money bloat)
> 2. Recklessly writes code into critical files without double-checking? (Regressions)
> 
> I built a simple background router to fix this. Meet Mighty Router. 🧵👇

### Tweet 2 (How it Works) ⚡
> Mighty Router sits behind your AI (Cursor, Windsurf, Aider, CLI agents) and automatically changes its behavior based on the task:
> 
> 🔴 Light: For simple questions. Tells the AI to reply in ultra-short text. (Saves 90% in tokens!)
> 🟢 Verify: For checking tests. Tells the AI to only inspect logs.
> 🟡 Standard: For routine edits. Requires a simple 1-sentence plan.
> 🔵 Forensic: For database or API changes. Enforces planning and safety reviews.

### Tweet 3 (Set-and-Forget Auto-Escalation) 🛠️
> You can place a `.mightyrc` file in your workspace containing sensitive folders (like `db/` or `auth/`). 
> 
> If the AI tries to modify them, Mighty Router automatically escalates the AI's logic to the Forensic (strict safety) profile. 
> 
> Fast edits everywhere, strict safety where it counts.

### Tweet 4 (Outro & Link) 🔗
> Easy global installer to set it up across all your local tools in one click.
> 
> Check out the open-source code and drop-in templates here:
> 👉 https://github.com/JOHNNYMACONNY/mighty-router

---

## 4. Reddit Post Copy (`r/LocalLLaMA`, `r/Cursor`, `r/cline`)

**Title:** Show r/Cursor: Mighty Router – Stop your AI coding tools from wasting tokens (and breaking important files)

> Hey everyone,
>
> If you use AI coding assistants like Cursor, Windsurf, Aider, or CLI agents, you've probably noticed two annoying habits:
>
> 1. **The Verbosity Trap:** You ask a simple question, and the AI spends minutes writing out a massive, expensive explanation/plan you didn't need.
> 2. **The Bypass Trap:** You ask the AI to change a critical part of your app, and it rushes ahead, editing files directly without double-checking or running tests, causing bugs.
>
> To fix this, I built **Mighty Router**—a simple, risk-based routing system that instructs your AI to dynamically change its behavior based on the risk of your request.
>
> ### The 4 Profiles
> * **`MIGHTY-LIGHT`** (Questions): The AI is restricted from editing code and must respond in short, telegraphic sentences. (Saves up to 90% in token costs).
> * **`MIGHTY-VERIFY`** (Checking Tests): The AI is instructed to only inspect log outputs on disk and return a checklist of findings.
> * **`MIGHTY-STANDARD`** (Routine Tweaks): AI requires a simple 1-sentence plain text plan before making any code changes.
> * **`MIGHTY-FORENSIC`** (Critical Changes): Automatically triggered for sensitive paths. AI is forced into a full-scale planning, testing, and auditing flow.
>
> ### Dynamic Auto-Escalation (`.mightyrc`)
> Place a `.mightyrc` file in your project root with your database or API paths. If the AI targets these directories, it automatically switches to `MIGHTY-FORENSIC` to prevent bugs:
>
> ```json
> {
>   "high_risk_paths": ["db/", "gateway/", "credentials"]
> }
> ```
>
> ### How to Install
> 1. Clone the repository.
> 2. Run `./install.sh`. The script auto-detects your local AI agents (Hermes, Codex, OpenClaw, Gemini, VS Code Copilot) and links the skills.
> 3. Use the templates in `templates/` to drop directly into Cursor (`.cursorrules`), Windsurf, Claude Code, or Aider.
>
> It’s open source, free, and MIT licensed. Let me know what you think!
>
> **GitHub Link:** https://github.com/JOHNNYMACONNY/mighty-router

---

## 5. Show HN Pitch Copy

**Title:** Show HN: Mighty Router – Risk-based prompt routing for coding agents

> AI coding tools either spend too many tokens writing long-winded plans for simple changes, or they bypass safety reviews entirely on critical files.
>
> Mighty Router is a simple, background routing framework that directs your AI (Cursor, Windsurf, Aider, CLI agents) to switch profiles based on the risk of your task:
> - **Light:** Quick, ultra-short text responses for simple questions (saves up to 90% in tokens).
> - **Verify:** Inspecting logs and test outputs.
> - **Standard:** Quick 1-sentence plan for routine edits.
> - **Forensic:** Full planning, testing, and reviews for critical files (auto-escalates via a project `.mightyrc` file).
>
> The repository includes drop-in templates for Cursor (`.cursorrules`), Windsurf, Claude Code, Aider, and an installer for terminal agents.
>
> Open source: https://github.com/JOHNNYMACONNY/mighty-router

