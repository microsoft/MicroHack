"""Challenge 6: the complete offline maintenance copilot.

One agent with four tools: machine status, maintenance tickets, fault prediction (ONNX) and SOP search.
A ToolRouter shortlists the tool for each request, because a small model picks the wrong tool too often when it sees all four.
"""
import sys
import time

import agent
import fault_tool
import fl
import retrieval
from tool_router import ToolRouter

CHAT_MODEL = "phi-4-mini"


def build():
    client = fl.client()
    chat_model = fl.load(CHAT_MODEL)
    embed_model = fl.load(retrieval.EMBED_MODEL)
    chunks, vectors = retrieval.load_index() if retrieval.INDEX.exists() else retrieval.build_index(client, embed_model)
    tools = [(fault_tool.SCHEMA, fault_tool.predict_fault),
             retrieval.search_tool(client, chat_model, embed_model, chunks, vectors)]
    return client, chat_model, tools, ToolRouter(client, embed_model)


def main():
    client, chat_model, tools, router = build()
    print("Offline maintenance copilot. Type a question, or 'exit'.")
    queue = sys.argv[1:]  # questions given on the command line run once, without a prompt
    scripted = bool(queue)
    while True:
        if scripted:
            if not queue:
                return
            question = queue.pop(0)
            print(f"\nTechnician> {question}")
        else:
            question = input("\nTechnician> ").strip()
        if question.lower() in ("", "exit", "quit"):
            return
        start = time.perf_counter()
        print(agent.run_agent(client, chat_model, question, extra_tools=tools, router=router))
        print(f"  ({time.perf_counter() - start:.1f} s)")


if __name__ == "__main__":
    main()
