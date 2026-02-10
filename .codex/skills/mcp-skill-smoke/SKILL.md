---
name: mcp-skill-smoke
description: Run a local smoke test for Codex skills by executing the bundled script that writes `skill-smoke-result.txt` in the current working directory. Use when the user mentions `$mcp-skill-smoke`, asks to verify skill loading, or wants an end-to-end skills test in Codex MCP or Agent SDK flows.
---

# Mcp Skill Smoke

## Overview

Use this skill to prove that Codex can load and execute a bundled skill script.

## Workflow

1. Resolve the skill root:
   - `repo_root="$(cd .. && pwd)"`
   - `skill_home="${CODEX_HOME:-$repo_root/.codex}"`
2. Run the smoke script:
   - `bash "$skill_home/skills/mcp-skill-smoke/scripts/run-smoke.sh" "skill-smoke-result.txt"`
3. Confirm output:
   - `cat skill-smoke-result.txt`
4. Report whether the file exists and include its contents in the final summary.

## Resource

- `scripts/run-smoke.sh`: Writes a marker file in the current working directory with timestamp and runtime details.
