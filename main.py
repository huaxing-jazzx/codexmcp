import asyncio
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(override=True)

from agents import Agent, Runner, set_default_openai_key
from agents.mcp import MCPServerStdio

OUTPUT_DIR = Path(__file__).parent / "output"
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if OPENAI_API_KEY:
    set_default_openai_key(OPENAI_API_KEY)
CODEX_SANDBOX_MODE = os.getenv("CODEX_SANDBOX_MODE", "workspace-write")


async def main() -> None:
    prompt = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else None
    if not prompt:
        print("Usage: uv run python main.py <prompt>")
        print('Example: uv run python main.py "Create a simple snake game"')
        sys.exit(1)

    OUTPUT_DIR.mkdir(exist_ok=True)
    cwd = str(OUTPUT_DIR.resolve())

    async with MCPServerStdio(
        name="Codex CLI",
        params={
            "command": "codex",
            "args": ["mcp-server"],
            # Ensure codex mcp-server receives runtime auth/env vars in all environments
            # (especially containerized deployments).
            "env": dict(os.environ),
        },
        client_session_timeout_seconds=300,
    ) as codex_mcp_server:
        tools = await codex_mcp_server.list_tools()
        print(f"Codex MCP tools available: {[t.name for t in tools]}")

        developer_agent = Agent(
            name="Developer",
            instructions=(
                "You are an expert software developer. "
                "Use the codex tool to complete coding tasks. "
                "Always call codex with approval-policy set to 'never', "
                f"sandbox set to '{CODEX_SANDBOX_MODE}', "
                f"and cwd set to '{cwd}' so all files are written to the output folder. "
                "When done, summarize what was created or changed."
            ),
            mcp_servers=[codex_mcp_server],
        )

        print(f"Output directory: {cwd}")
        print(f"Running agent with prompt: {prompt}\n")
        result = await Runner.run(developer_agent, prompt)
        print(f"\n--- Agent Output ---\n{result.final_output}")


if __name__ == "__main__":
    asyncio.run(main())
