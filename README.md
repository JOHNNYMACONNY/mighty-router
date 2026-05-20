# Mighty Router

**Mighty Router** is a lightweight, risk-based execution profiling framework for AI developer agents (Hermes, OpenClaw, Codex, Gemini/Antigravity) and AI-first IDEs (Cursor, VS Code Copilot, Windsurf, Claude Code, Aider).

By dynamically classifying developer requests into distinct risk tiers, it prevents agents from incurring unnecessary token overhead on simple tasks while enforcing strict architectural and verification gates on high-risk edits.

---

## The Core Concept: Risk-Based Routing

AI agents often fall into one of two traps:
1. **The Verbosity Trap:** They waste thousands of tokens writing complex XML tags (like planning, red-teaming, and post-action audits) for a 1-line refactor or simple question.
2. **The Bypass Trap:** To save effort, they bypass safety planning and write buggy code directly to critical files without thinking through regressions.

**Mighty Router** introduces four dynamic profiles:

| Profile | Use Case | Key Rules | Token Footprint |
| :--- | :--- | :--- | :--- |
| **`MIGHTY-LIGHT`** | Questions, queries, code explanations. | No code edits. Brief, telegraphic responses. No XML tags. | **Minimal** |
| **`MIGHTY-VERIFY`** | Auditing, UAT checks, checking test status. | No code edits. Checks evidence on disk. Bulleted evidence log. | **Minimal** |
| **`MIGHTY-STANDARD`** | Simple, routine code changes. | Plain-text 1-3 sentence plan. Minimum necessary code footprint. | **Low** |
| **`MIGHTY-FORENSIC`** | Complex edits, database changes, schema edits. | Strict XML tags: context audit, adversarial planning, verification proof. | **Full** |

---

## Automatic Escalation & Configuration (`.mightyrc`)

Mighty Router supports a project-specific configuration file named `.mightyrc` or `.mighty.json` placed in the workspace root. 

If this file is detected, the agent loads the defined paths and automatically escalates any modification tasks targeting them to the **`MIGHTY-FORENSIC`** profile.

### Example `.mightyrc` configuration:
```json
{
  "high_risk_paths": [
    "gateway",
    "persistence",
    "db",
    "SOUL.md",
    "credentials"
  ]
}
```

*If no configuration file is detected, it falls back to standard defaults (e.g. database schemas, credentials, SOUL.md, gateway protocols).*

---

## Installation

### 1. Clone the repository
```bash
git clone https://github.com/yourusername/mighty-router.git
cd mighty-router
```

### 2. Run the automated installer
```bash
chmod +x install.sh
./install.sh
```
The script will automatically detect active agent setups on your system and link the Router:
- **Hermes:** Skill category `mighty`
- **OpenClaw, Codex, Antigravity:** Flat skill `mighty-router`
- **VS Code Copilot:** Global custom agent `@mighty-router`

### 3. Setup workspace templates (Cursor, Windsurf, Claude Code, Aider)
To enforce these safety gates inside a specific repository, copy or symlink the respective template configuration to your workspace root:

* **Cursor / Trae:** Link `templates/.cursorrules` to `.cursorrules` in your project.
* **Windsurf:** Link `templates/.windsurfrules` to `.windsurfrules` in your project.
* **Claude Code:** Link `templates/.clauderules` to `.clauderules` in your project.
* **Cline / Roo Code:** Link `templates/.clinerules` to `.clinerules` in your project.
* **Aider:** Link `templates/.aider.instructions.md` to `.aider.instructions.md` in your project.

---

## License
MIT
