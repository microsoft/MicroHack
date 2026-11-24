"""Challenge 5: how often does the agent pick the right tool first?

  python check_routing.py                         tuning set, tool shortlist of 1
  python check_routing.py holdout                 requests the router was not tuned on
  python check_routing.py tuning baseline         no router: the model sees all tools
  python check_routing.py tuning top2             router shortlists 2 tools, the model chooses
  add --quick                                     two requests per tool instead of the whole set

Set ROUTING_MODEL_ID to a full model ID (for example Phi-4-mini-instruct-generic-cpu:5) to test one hardware variant.
Only the first tool the model picks is counted. Tickets are never created (the approval is always 'no').
"""
import json
import os
import sys
import time

import agent
import fault_tool
import fl
import retrieval
from tool_router import ToolRouter

SETS = {"tuning": "routing_eval.json", "holdout": "routing_holdout.json"}
first_tool = []  # the tool the model picked first for the current request
_original = agent.first_tool_call


def _spy(reply):
    call = _original(reply)
    if call and not first_tool:
        first_tool.append(call[1])
    return call


agent.first_tool_call = _spy

if __name__ == "__main__":
    quick = "--quick" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--quick"]
    dataset = args[0] if len(args) > 0 else "tuning"
    strategy = args[1] if len(args) > 1 else "top1"
    cases = json.loads((fl.DATA / "eval" / SETS[dataset]).read_text(encoding="utf-8"))
    if quick:  # the first two requests for every tool, so each tool still counts
        taken, picked = {}, []
        for c in cases:
            if taken.get(c["expected_tool"], 0) < 2:
                picked.append(c)
                taken[c["expected_tool"]] = taken.get(c["expected_tool"], 0) + 1
        cases = picked

    client = fl.client()
    embed_model = fl.load(retrieval.EMBED_MODEL)
    chat_model = os.environ.get("ROUTING_MODEL_ID") or fl.load(retrieval.CHAT_MODEL)
    chunks, vectors = retrieval.load_index() if retrieval.INDEX.exists() else retrieval.build_index(client, embed_model)
    tools = [(fault_tool.SCHEMA, fault_tool.predict_fault),
             retrieval.search_tool(client, chat_model, embed_model, chunks, vectors)]
    router = None if strategy == "baseline" else ToolRouter(client, embed_model)
    shortlist = 2 if strategy == "top2" else 1

    right, misses, start = 0, [], time.perf_counter()
    per_tool = {}
    for case in cases:
        first_tool.clear()
        agent.run_agent(client, chat_model, case["request"], extra_tools=tools, approve=lambda *_: False,
                        router=router, shortlist=shortlist, verbose=False)
        picked = first_tool[0] if first_tool else "(no tool)"
        ok = picked == case["expected_tool"]
        right += ok
        stats = per_tool.setdefault(case["expected_tool"], [0, 0])
        stats[0] += ok
        stats[1] += 1
        if not ok:
            misses.append((case["id"], case["request"][:58], case["expected_tool"], picked))
    print(f"[{dataset}{' quick' if quick else ''} / {strategy} / {chat_model}]")
    for tool, (ok, n) in per_tool.items():
        print(f"  {ok}/{n}  {tool}")
    print(f"first tool correct: {right}/{len(cases)}  ({time.perf_counter() - start:.0f} s)")
    for m in misses:
        print("  miss:", m)
