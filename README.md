# Codex MCP + OpenAI Agent SDK POC

A proof-of-concept showing how to use [OpenAI Codex CLI](https://github.com/openai/codex) as an MCP server with the [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/).

## How It Works

```
User prompt  -->  OpenAI Agent (gpt-4.1)  -->  Codex MCP Server  -->  Files in output/
```

1. The agent receives your prompt via the OpenAI Agents SDK
2. It calls `codex mcp-server` through `MCPServerStdio` (Model Context Protocol over stdio)
3. Codex executes the coding task and writes files into the `output/` directory

Codex exposes two MCP tools:
- **`codex`** - Start a new coding session (accepts `prompt`, `approval-policy`, `sandbox`, `cwd`)
- **`codex-reply`** - Continue an existing session (accepts `prompt`, `threadId`)

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

```bash
uv run python main.py "<your prompt>"
```

### Examples

```bash
# Generate a simple game
uv run python main.py "Create a snake game with HTML, CSS, and JavaScript"

# Generate a landing page
uv run python main.py "Build a responsive landing page for a coffee shop"

# Generate a utility script
uv run python main.py "Write a Python script that converts CSV to JSON"
```

All generated files will be saved to the `output/` directory.

## Project Structure

```
codexmcp/
├── .env              # OpenAI API key (not committed)
├── .gitignore
├── main.py           # Agent entry point
├── output/           # Generated files go here (not committed)
├── pyproject.toml
├── uv.lock
└── README.md
```
