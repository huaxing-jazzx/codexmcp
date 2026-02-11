# Codex MCP + OpenAI Agent SDK POC

A proof-of-concept showing how to use [OpenAI Codex CLI](https://github.com/openai/codex) as an MCP server with the [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/).

## How It Works

This repo demonstrates two approaches to integrate Codex with the OpenAI Agents SDK:

### Approach 1: MCP Server (`main.py`)

```
User prompt  -->  OpenAI Agent  -->  MCP Protocol  -->  codex mcp-server  -->  Files in output/
```

1. The agent receives your prompt via the OpenAI Agents SDK
2. It calls `codex mcp-server` through `MCPServerStdio` (Model Context Protocol over stdio)
3. Codex executes the coding task and writes files into the `output/` directory

Codex exposes two MCP tools:
- **`codex`** - Start a new coding session (accepts `prompt`, `approval-policy`, `sandbox`, `cwd`)
- **`codex-reply`** - Continue an existing session (accepts `prompt`, `threadId`)

### Approach 2: Experimental Codex Tool (`newway.py`)

```
User prompt  -->  OpenAI Agent  -->  codex_tool()  -->  Codex CLI directly  -->  Files in cwd
```

Uses the new `codex_tool` extension from [openai-agents-python#2320](https://github.com/openai/openai-agents-python/pull/2320) (merged). This wraps Codex CLI as a native agent tool — no MCP plumbing required.

Key differences from the MCP approach:
- **No `MCPServerStdio`** — Codex CLI is spawned directly as a subprocess
- **Declarative config** — `ThreadOptions` and `TurnOptions` replace verbose agent instructions
- **Built-in streaming** — `on_stream` callback for real-time Codex events (reasoning, command execution, agent messages)
- **Thread management** — automatic, with `codex resume <thread_id>` support
- **Skill support** — Codex-native skills (e.g. `$mcp-skill-smoke`) work via the prompt

> **Note:** This extension is under `agents.extensions.experimental.codex` — the API may change.

## Prerequisites

- Python 3.13+
- [uv](https://docs.astral.sh/uv/) package manager
- [Codex CLI](https://github.com/openai/codex) (`npm install -g @openai/codex` or `brew install codex`)
- Node.js 18+
- OpenAI API key

## Setup

1. Clone the repo and install dependencies:

```bash
git clone <repo-url>
cd codexmcp
uv sync
```

2. Create a `.env` file with your OpenAI API key:

```bash
echo 'OPENAI_API_KEY=sk-...' > .env
```

## Usage

### MCP Server approach (`main.py`)

```bash
uv run python main.py "<your prompt>"
```

Examples:

```bash
# Generate a simple game
uv run python main.py "Create a snake game with HTML, CSS, and JavaScript"

# Generate a landing page
uv run python main.py "Build a responsive landing page for a coffee shop"

# Generate a utility script
uv run python main.py "Write a Python script that converts CSV to JSON"
```

All generated files will be saved to the `output/` directory.

### Experimental Codex Tool approach (`newway.py`)

```bash
uv run python newway.py
```

The prompt is defined inline in `newway.py`. Edit it to change the task:

```python
result = await Runner.run(
    agent, "You must use `$mcp-skill-smoke` skill to run the smoke test and report the results."
)
```

To invoke a Codex skill, reference it by name with the `$` prefix in the prompt. The agent instructions route skill invocations to the `codex_tool`.

Configuration is declarative via `ThreadOptions` and `TurnOptions`:

```python
codex_tool(
    sandbox_mode="workspace-write",
    default_thread_options=ThreadOptions(
        model="gpt-5.2-codex",
        model_reasoning_effort="low",
        network_access_enabled=True,
        approval_policy="never",
    ),
    default_turn_options=TurnOptions(
        idle_timeout_seconds=60,
    ),
    on_stream=lambda payload: print(payload),
)
```

## Docker (Skills Included)

This repo includes project-scoped skills in `.codex/skills/`. The Docker image copies this folder and sets:

- `CODEX_HOME=/app/.codex`

That means Codex in the container can load your bundled skills (for example `$mcp-skill-smoke`).
`main.py` also forwards process environment variables to `codex mcp-server`, so runtime auth like
`OPENAI_API_KEY` is available to both Agent SDK and Codex CLI.
The container entrypoint runs `codex login --with-api-key` using `OPENAI_API_KEY` before starting
the app, which is required for Codex CLI auth in this setup.

### Where Skills Should Live in Production

Use this path inside the container:

- `/app/.codex/skills`

Do not use `/.codex/skills` when running as non-root user, because it can cause permission issues.

Codex resolves skills from `$CODEX_HOME/skills`, and this repo sets:

- `CODEX_HOME=/app/.codex`

So the effective skills directory is `/app/.codex/skills`.

Two supported deployment patterns:

1. Bake skills into the image (immutable release):
   - keep skills in repo at `.codex/skills/`
   - image copies them to `/app/.codex/skills`
2. Mount skills at runtime (hot updates without rebuild):
   - `-v /your/skills:/app/.codex/skills:ro`

### Build

```bash
docker build -t codexmcp:latest .
```

### Run

```bash
docker run --rm \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e CODEX_SANDBOX_MODE="workspace-write" \
  codexmcp:latest \
  '$mcp-skill-smoke run the smoke script and report the file contents'
```

If you want to persist generated files outside the container:

```bash
docker run --rm \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e CODEX_SANDBOX_MODE="workspace-write" \
  -v "$(pwd)/output:/app/output" \
  codexmcp:latest \
  "Build a simple landing page"
```

### Verify Skill Triggering in Docker

Use the smoke-test script to confirm a skill is loaded and executed in-container:

```bash
bash scripts/test-skill-in-docker.sh
```

Note: If `.env` wraps the key in quotes (for example `OPENAI_API_KEY="sk-..."`), the smoke test handles it.
The smoke test defaults to `CODEX_SANDBOX_MODE=danger-full-access` to avoid Linux Landlock
restrictions in Docker that can block shell-based skill scripts.

## Production Notes

Use this checklist before deploying:

1. Auth bootstrap:
`OPENAI_API_KEY` must be injected at runtime, and Codex CLI must be logged in. This repo handles that in `/Users/huaxing/Desktop/codexmcp/scripts/entrypoint.sh`.
2. Secrets handling:
Avoid baking `.env` into images. Use runtime secrets (Kubernetes secrets, ECS task secrets, Vault).
3. Skills packaging:
Baking `.codex/skills` in image gives immutable releases. Mounting skills as a volume enables hot updates without rebuilds.
4. Approval policy:
Agent instructions enforce Codex tool calls with `approval-policy=never` for non-interactive production runs.
5. Sandbox mode:
Use `CODEX_SANDBOX_MODE=workspace-write` as the default profile in production.
If your container/kernel cannot support Codex's default Linux sandbox backend (Landlock), use
`CODEX_SANDBOX_MODE=danger-full-access` and rely on container isolation and least-privilege runtime controls.
6. Writable paths:
With `workspace-write`, mount `/app/output` for persistence.
7. Version pinning:
Pin `@openai/codex`, `openai-agents`, and Python dependencies to reduce behavioral drift across deploys.
8. Observability:
Capture container stdout/stderr. Codex MCP and Agents SDK both emit useful diagnostics there.
9. Timeouts/retries:
Set request timeouts and retry strategy at the API gateway/job level for transient upstream failures.
10. Cost/latency controls:
Constrain prompt size, max turns, and model selection in production to avoid runaway token usage.
11. Security boundary:
Treat Codex tool execution as code execution. Keep least privilege (non-root user, restricted filesystem/network where possible).
12. Health checks:
Run `bash /Users/huaxing/Desktop/codexmcp/scripts/test-skill-in-docker.sh` in CI/CD as a post-build verification.

### Recommended Production Profile

Use these defaults unless you have a specific reason to change them:

- `approval-policy`: `never`
- `sandbox`: `workspace-write`
- `cwd`: `/app/output`

In this repo:
- `approval-policy` and `cwd` are enforced in `/Users/huaxing/Desktop/codexmcp/main.py`.
- `sandbox` is controlled by `CODEX_SANDBOX_MODE` (default: `workspace-write`).

## Project Structure

```
codexmcp/
├── .env              # OpenAI API key (not committed)
├── .gitignore
├── main.py           # MCP Server approach entry point
├── newway.py         # Experimental codex_tool approach entry point
├── .codex/
│   └── skills/       # Codex-native skills
│       └── mcp-skill-smoke/
├── scripts/
│   ├── entrypoint.sh
│   └── test-skill-in-docker.sh
├── output/           # Generated files go here (not committed)
├── pyproject.toml
├── uv.lock
└── README.md
```
