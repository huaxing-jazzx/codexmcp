import asyncio
import os

from dotenv import load_dotenv
load_dotenv(override=True)

from agents import Agent, Runner, set_default_openai_key
from agents.extensions.experimental.codex import (
    ThreadOptions,
    TurnOptions,
    codex_tool,
)

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if OPENAI_API_KEY:
    set_default_openai_key(OPENAI_API_KEY)

async def main() -> None:
    agent = Agent(
        name="Codex Agent",
        instructions=(
            "Use the codex tool to inspect the workspace and answer the question. "
            "When skill names, which usually starts with `$`, are mentioned, "
            "you must rely on the codex tool to use the skill and answer the question.\n\n"
            "When you send the final answer, you must include the following info at the end:\n\n"
            "Run `codex resume <thread_id>` to continue the codex session."
        ),
        tools=[
            # Run local Codex CLI as a sub process
            codex_tool(
                sandbox_mode="workspace-write",
                default_thread_options=ThreadOptions(
                    # You can pass a Codex instance to customize CLI details
                    # codex=Codex(executable_path="/path/to/codex", base_url="..."),
                    model="gpt-5.2-codex",
                    model_reasoning_effort="low",
                    network_access_enabled=True,
                    web_search_enabled=False,
                    approval_policy="never",  # We'll update this example once the HITL is implemented
                ),
                default_turn_options=TurnOptions(
                    # Abort Codex CLI if no events arrive within this many seconds.
                    idle_timeout_seconds=60,
                ),
                # Subscribe the events from codex CLI
                on_stream=lambda payload: print(payload),
            )
        ],
    )
    result = await Runner.run(
        agent, "You must use `$mcp-skill-smoke` skill to run the smoke test and report the results."
    )
    print(result.final_output)

if __name__ == "__main__":
    asyncio.run(main())