"""Minimal MCP client for Challenge 6: launch ``mcp_server.py`` and call ``inject_signal``.

``mcp_server.py`` uses the stdio transport, so it can't be run on its own and typed
into: an MCP client starts it as a child process and exchanges JSON-RPC over its
stdin/stdout. This script is that client.

Run it from ``src/`` in a second terminal while the planner console is running:

    uv run python mcp_client.py "Competitor out of stock on chainsaws in the West"
    uv run python mcp_client.py "Heatwave intensifies" --category outdoor_power_tools --region "Pacific Northwest"
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER = Path(__file__).with_name("mcp_server.py")


async def inject(headline: str, category: str, region: str) -> int:
    params = StdioServerParameters(command=sys.executable, args=[str(SERVER)], cwd=str(SERVER.parent))
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = [tool.name for tool in (await session.list_tools()).tools]
            print(f"Connected to MCP server 'zava-signals' - tools: {', '.join(tools)}")
            result = await session.call_tool(
                "inject_signal", {"headline": headline, "category": category, "region": region}
            )
            for item in result.content:
                print(getattr(item, "text", item))
            return 1 if result.isError else 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Call the inject_signal MCP tool.")
    parser.add_argument("headline", help='The market signal, e.g. "Competitor out of stock on chainsaws in the West"')
    parser.add_argument("--category", default="outdoor_power_tools")
    parser.add_argument("--region", default="Pacific Northwest")
    args = parser.parse_args()
    sys.exit(asyncio.run(inject(args.headline, args.category, args.region)))


if __name__ == "__main__":
    main()
