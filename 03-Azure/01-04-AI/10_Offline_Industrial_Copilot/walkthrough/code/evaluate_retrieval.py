"""Challenge 4: measure retrieval and answer quality against the evaluation set.

  python evaluate_retrieval.py          fixed pipeline: always retrieve, then answer
  python evaluate_retrieval.py agent    the agent decides whether to call search_sops
"""
import json
import sys

import agent
import fl
import retrieval as r


REFUSAL_PHRASES = ("could not find", "not find", "not specified", "not available", "not mentioned",
                   "no information", "not contain", "not in the")


def is_refusal(text):
    return any(p in text.lower() for p in REFUSAL_PHRASES)


def evaluate(mode="pipeline"):
    client = fl.client()
    embed_model, chat_model = fl.load(r.EMBED_MODEL), fl.load(r.CHAT_MODEL)
    chunks, vectors = r.build_index(client, embed_model)
    search = r.search_tool(client, chat_model, embed_model, chunks, vectors)
    cases = json.loads((fl.DATA / "eval" / "retrieval_eval.json").read_text(encoding="utf-8"))
    hit = correct = cited = refused = 0
    for case in cases:
        if mode == "agent":
            text = agent.run_agent(client, chat_model, case["question"], extra_tools=[search],
                                   approve=lambda *_: False, verbose=False)
            sources = [(case["expected_sop"],)] if case["expected_sop"] and case["expected_sop"] in text else []
        else:
            text, sources = r.answer(client, chat_model, embed_model, chunks, vectors, case["question"])
        if not case["expected_sop"]:
            ok = is_refusal(text)
            refused += ok
            print(f"{case['id']} {'PASS' if ok else 'FAIL'} (should refuse) -> {text[:70]!r}")
            continue
        facts = all(f.lower() in text.lower() for f in case["must_include"])
        cites = case["expected_sop"] in text
        correct += facts
        cited += cites
        hit += any(s[0] == case["expected_sop"] for s in sources) if mode == "pipeline" else cites
        print(f"{case['id']} facts={facts} cited={cites}")
    n = sum(1 for c in cases if c["expected_sop"])
    label = "retrieval hit" if mode == "pipeline" else "right SOP named"
    print(f"\n[{mode}] {label} {hit}/{n} | correct facts {correct}/{n} | cites right SOP {cited}/{n} | "
          f"refused unanswerable {refused}/{len(cases) - n}")


if __name__ == "__main__":
    evaluate(sys.argv[1] if len(sys.argv) > 1 else "pipeline")
