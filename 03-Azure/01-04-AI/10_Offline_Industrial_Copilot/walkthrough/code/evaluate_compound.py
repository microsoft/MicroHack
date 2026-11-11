"""Challenge 4: does the agent retrieve more than once when a question needs it?"""
import json

import agent
import fl
import retrieval as r


def evaluate(repeats=2):
    client = fl.client()
    embed_model, chat_model = fl.load(r.EMBED_MODEL), fl.load(r.CHAT_MODEL)
    chunks, vectors = r.build_index(client, embed_model)
    schema, search = r.search_tool(client, chat_model, embed_model, chunks, vectors)
    calls = []

    def counting_search(query):
        result = search(query)
        calls.extend(result["queries"])
        return result

    cases = json.loads((fl.DATA / "eval" / "compound_eval.json").read_text(encoding="utf-8"))
    multi = both = facts = runs = 0
    for case in cases:
        for _ in range(repeats):
            calls.clear()
            text = agent.run_agent(client, chat_model, case["question"], extra_tools=[(schema, counting_search)],
                                   approve=lambda *_: False, verbose=False)
            runs += 1
            multi += len(calls) >= 2
            both += all(s in text for s in case["expected_sops"])
            facts += all(f.lower() in text.lower() for f in case["must_include"])
            print(f"{case['id']} topics={len(calls)} both_sops={all(s in text for s in case['expected_sops'])} "
                  f"facts={all(f.lower() in text.lower() for f in case['must_include'])}")
    print(f"\nretrieved more than once {multi}/{runs} | both SOPs found {both}/{runs} | all facts {facts}/{runs}")


if __name__ == "__main__":
    evaluate()
