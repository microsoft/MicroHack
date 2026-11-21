"""Challenge 2: compare edge models on speed, memory, tool calling and answer quality."""
import json
import re
import sys
import time

import fl
from tools import TOOL_SCHEMAS

SYSTEM = ("You are a maintenance assistant for technicians. Machine data is only available through your tools. "
          "Never guess a machine reading.")


def strip_thinking(text):
    return re.sub(r"<think>.*?</think>", "", text or "", flags=re.S).strip()


def speed(client, model):
    start = time.perf_counter()
    first = None
    chunks = 0
    stream = client.chat.completions.create(
        model=model, stream=True, temperature=0, max_tokens=120,
        messages=[{"role": "user", "content": "Explain in three sentences why bearings fail."}])
    for part in stream:
        # Reasoning models stream their thinking in a separate field. It costs time, so we count it.
        delta = part.choices[0].delta if part.choices else None
        if delta and (delta.content or getattr(delta, "reasoning_content", None)):
            chunks += 1
            first = first or time.perf_counter()
    end = time.perf_counter()
    return round((first or end) - start, 2), round(chunks / max(end - (first or start), 0.001), 1)


def tool_calling(client, model, choice):
    cases = json.loads((fl.DATA / "eval" / "tool_eval.json").read_text(encoding="utf-8"))
    passed = 0
    for case in cases:
        try:
            reply = client.chat.completions.create(
                model=model, temperature=0, max_tokens=150, tools=TOOL_SCHEMAS, tool_choice=choice,
                messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": case["prompt"]}],
            ).choices[0].message
        except Exception:
            continue  # a failed request counts as a failed case
        calls = reply.tool_calls or []
        if case["expected_tool"] is None:
            ok = not calls
        else:
            # Exactly one call: a model that also invents a second call (for example a ticket) fails.
            ok = len(calls) == 1 and calls[0].function.name == case["expected_tool"]
            if ok:
                args = json.loads(calls[0].function.arguments or "{}")
                ok = all(str(args.get(k, "")).lower() == v.lower() for k, v in case["expected_args"].items())
        passed += ok
    return f"{passed}/{len(cases)}"


def quality(client, model):
    """Give the model the right SOP and check that the answer contains the expected facts."""
    cases = [c for c in json.loads((fl.DATA / "eval" / "retrieval_eval.json").read_text(encoding="utf-8"))
             if c["expected_sop"]]
    sops = {p.name.split("_")[0]: p.read_text(encoding="utf-8") for p in (fl.DATA / "sops").glob("*.md")}
    passed = 0
    for case in cases:
        reply = client.chat.completions.create(
            model=model, temperature=0, max_tokens=200,
            messages=[{"role": "system", "content": "Answer briefly using only this SOP.\n\n" + sops[case["expected_sop"]]},
                      {"role": "user", "content": case["question"]}],
        ).choices[0].message.content
        answer = strip_thinking(reply).lower()
        passed += all(f.lower() in answer for f in case["must_include"])
    return f"{passed}/{len(cases)}"


if __name__ == "__main__":
    aliases = sys.argv[1:] or ["phi-4-mini", "qwen2.5-1.5b", "qwen3-1.7b"]
    client = fl.client()
    rows = []
    for alias in aliases:
        print(f"Benchmarking {alias} ...", flush=True)
        t = time.perf_counter()
        model = fl.load(alias)
        load_s = round(time.perf_counter() - t, 1)
        info = fl.loaded_models()[alias]
        ttft, tps = speed(client, model)
        rows.append({
            "model": alias, "device": info["device"], "size_mb": info["fileSizeMb"], "load_s": load_s,
            "first_token_s": ttft, "tokens_per_s": tps,
            "tools_auto": tool_calling(client, model, "auto"),
            "tools_required": tool_calling(client, model, "required"),
            "quality": quality(client, model),
        })
        _ = fl._foundry("model", "unload", alias, as_json=False)
    cols = list(rows[0])
    print("\n" + " | ".join(cols))
    for r in rows:
        print(" | ".join(str(r[c]) for c in cols))
    with open("benchmark_results.json", "w", encoding="utf-8") as f:
        json.dump(rows, f, indent=2)
