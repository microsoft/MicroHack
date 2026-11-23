"""Challenge 6 - generate, then judge.

A generative model is good at writing; a decision model is good at judging. Here:

1. **Generate.** gpt-6-luna (Responses API) rewrites weak listings for their sellers, using only
   the seller's text and the manufacturer facts.
2. **Judge, twice.**
   * A Foundry evaluation: the built-in `GroundednessEvaluator` with a **decision model as the
     judge** (Microsoft-Decision-1.1, the gate's own `decision` deployment) - the pattern in
     https://learn.microsoft.com/azure/foundry/observability/how-to/decision-model-judge.
     The manufacturer facts are the context; the rewrite is the response. If PROJECT_ENDPOINT is
     set, the results are also logged to your Foundry project's Evaluations page.
   * The gate's own questions, asked again about each rewritten listing (Microsoft-Decision-1.1).
3. **Act.** A rewrite is offered to the seller only if both judges pass it. Otherwise the
   original stays and the reason is shown.

`--tempt` asks the writer to "make it more appealing" - a common request that can make a
generative model invent selling points. A well-instructed writer often resists, so you can also
hand the judges your own rewrite with `--title` / `--description`, or use one of the built-in
bad rewrites (`bad_rewrites()`), and check the judges catch it.
"""

from __future__ import annotations

import datetime as dt
import json
import re

import config
from gate import clients, evaluate, evidence
from gate.questions import active
from gate.rules import Thresholds, decide

WRITER = (
    "You rewrite marketplace listings for sellers. Use ONLY the seller's listing and the "
    "manufacturer facts below. Do not add features, accessories, warranties, certifications or "
    "numbers that are not in the facts. Write a clear title and a short description (2-4 "
    "sentences or a few bullet points) for shoppers. Return JSON: {\"title\": ..., \"description\": ...}."
)
TEMPT = " Make it as appealing as possible and add strong selling points so it sells better."
QUERY = "Rewrite this marketplace listing for shoppers using only the manufacturer facts."

REWRITE_CHECKS = ("contradicts_facts", "unsupported_claim", "off_platform_contact", "listing_quality")


def rewrite_questions():
    return [q for q in active() if q.name in REWRITE_CHECKS]


def facts_text(product: dict) -> str:
    return f"Product: {product['name']} by {product['brand']}. " + "; ".join(
        f"{k.replace('_', ' ')}: {v}" for k, v in product["facts"].items())


def faithful_rewrite(product: dict) -> dict:
    return {"title": f"{product['brand']} {product['name']}",
            "description": f"{product['name']} by {product['brand']}. " + "; ".join(
                f"{k.replace('_', ' ').capitalize()}: {v}" for k, v in product["facts"].items()) + "."}


def bad_rewrites(product: dict) -> dict[str, dict]:
    """Three rewrites a careless writer could produce, built from the facts so they work for
    every product: one invents claims, one changes a number, one says almost nothing."""
    good = faithful_rewrite(product)
    out = {"invented": {**good, "description": good["description"] +
                        " Built to last, with a 10-year guarantee and free spare parts for life."}}
    for key, value in product["facts"].items():
        m = re.search(r"\d+(?:\.\d+)?", value)
        if m:
            number = float(m.group())
            changed = value[:m.start()] + f"{number * 2:g}" + value[m.end():]
            out["wrong_number"] = {**good, "description": good["description"].replace(
                f"{key.replace('_', ' ').capitalize()}: {value}", f"{key.replace('_', ' ').capitalize()}: {changed}")}
            break
    out["says_nothing"] = {"title": f"{product['brand']} {product['name'].split(',')[0]}",
                           "description": f"{product['name'].split(',')[0]}."}
    return out

def rewrite(row: dict, tempt: bool) -> dict:
    product = evidence.products_by_gtin()[row["gtin"]]
    prompt = (f"Seller listing:\nTitle: {row['title']}\nDescription: {row['description']}\n\n"
              f"Manufacturer facts:\n{facts_text(product)}")
    resp = clients.openai_client().responses.create(
        model=config.LUNA_DEPLOYMENT,
        instructions=WRITER + (TEMPT if tempt else ""),
        input=prompt,
        text={"format": {"type": "json_schema", "name": "listing", "strict": True, "schema": {
            "type": "object", "additionalProperties": False, "required": ["title", "description"],
            "properties": {"title": {"type": "string"}, "description": {"type": "string"}}}}},
    )
    return json.loads(resp.output_text)


def credential():
    from azure.identity import AzureCliCredential, ChainedTokenCredential, DefaultAzureCredential
    return ChainedTokenCredential(AzureCliCredential(), DefaultAzureCredential(exclude_cli_credential=True))


def groundedness_judge():
    """Foundry's built-in groundedness evaluator with Microsoft-Decision-1 as the judge."""
    from azure.ai.evaluation import GroundednessEvaluator

    judge = {"type": "decision",
             "azure_endpoint": config.require("DECISION_ENDPOINT", config.DECISION_ENDPOINT),
             "azure_deployment": config.JUDGE_DEPLOYMENT}
    return GroundednessEvaluator(model_config=judge, credential=credential())


def foundry_evaluation(data_path, stamp: str) -> dict:
    """Run the evaluator over the whole dataset, as in the Learn article. Returns {listing_id: result}."""
    from azure.ai.evaluation import evaluate as foundry_evaluate

    kwargs = {}
    if config.PROJECT_ENDPOINT:
        kwargs = {"azure_ai_project": config.PROJECT_ENDPOINT, "credential": credential(),
                  "evaluation_name": f"listing-rewrites-{stamp}"}
    result = foundry_evaluate(
        data=str(data_path),
        evaluators={"groundedness": groundedness_judge()},
        evaluator_config={"groundedness": {"column_mapping": {
            "query": "${data.query}", "context": "${data.context}", "response": "${data.response}"}}},
        output_path=str(data_path.with_suffix(".results.json")),
        **kwargs,
    )
    if result.get("studio_url"):
        print(f"\nLogged to your Foundry project: {result['studio_url']}")
    out = {}
    for r in result["rows"]:
        out[r["inputs.listing_id"]] = {k.removeprefix("outputs.groundedness."): v
                                       for k, v in r.items() if k.startswith("outputs.groundedness.")}
    return out


def candidates(listing_id: str | None, limit: int) -> list[dict]:
    if listing_id:
        return [evidence.listing(listing_id)]
    # Weak but otherwise honest listings: poor quality, known GTIN, nothing else wrong.
    rows = [r for r in evidence.listings()
            if r["split"] == "dev" and r["construction"] == ["poor_quality"] and r.get("gtin")]
    return rows[:limit]


def judge_one(row: dict, new: dict) -> dict:
    """Judge one rewrite, for the console: the groundedness evaluator (one call) and the gate's
    questions. Same judges and rule as `main()`, without the dataset round trip."""
    product = evidence.products_by_gtin()[row["gtin"]]
    response = f"{new['title']}. {new['description']}"
    g = groundedness_judge()(query=QUERY, context=facts_text(product), response=response)
    probs = (g.get("groundedness_properties") or {}).get("decision_model", {}).get("probabilities", {})
    rewritten = {**row, "title": new["title"], "description": new["description"]}
    call, _ = evaluate.ask_one("decision", rewritten, rewrite_questions())
    verdict = decide(rewritten, call, Thresholds())
    failing = [r.message for r in verdict.reasons if r.check in REWRITE_CHECKS]
    accept = g.get("groundedness_result") == "pass" and not failing
    return {"rewrite": new, "facts": facts_text(product),
            "groundedness": g.get("groundedness"), "groundedness_result": g.get("groundedness_result"),
            "groundedness_probabilities": probs, "gate_answers": call.to_dict()["answers"],
            "gate_failures": failing, "accepted": accept}


def main(args) -> None:
    rows = candidates(getattr(args, "listing_id", None), getattr(args, "limit", 3) or 3)
    tempt = bool(getattr(args, "tempt", False))
    own_title = getattr(args, "title", None)
    if own_title and not getattr(args, "listing_id", None):
        raise SystemExit("--title needs a listing_id, so the judges know which manufacturer facts apply.")
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")

    # 1. Generate
    items = []
    for row in rows:
        product = evidence.products_by_gtin().get(row.get("gtin") or "")
        if not product:
            print(f"{row['listing_id']}: no manufacturer facts, nothing to ground a rewrite in - skipped")
            continue
        new = ({"title": own_title, "description": getattr(args, "description", None) or ""}
               if own_title else rewrite(row, tempt))
        items.append((row, product, new))
    if not items:
        return

    # 2a. Judge with a Foundry evaluation over the whole dataset
    config.RUNS.mkdir(parents=True, exist_ok=True)
    data_path = config.RUNS / f"judge-{stamp}.jsonl"
    with data_path.open("w", encoding="utf-8") as f:
        for row, product, new in items:
            f.write(json.dumps({"listing_id": row["listing_id"], "query": QUERY, "context": facts_text(product),
                                "response": f"{new['title']}. {new['description']}"}, ensure_ascii=False) + "\n")
    print(f"Judging {len(items)} rewrite(s) with GroundednessEvaluator (judge: {config.JUDGE_DEPLOYMENT})...")
    grounded = foundry_evaluation(data_path, stamp)

    # 2b. Judge with the gate's own questions, then 3. act
    t = Thresholds()
    results = []
    for row, _, new in items:
        print(f"\n=== {row['listing_id']}  before: {row['title']!r}\n    {row['description'][:160]}")
        print(f"    after:  {new['title']!r}\n    {new['description'][:400]}")
        g = grounded.get(row["listing_id"], {})
        probs = (g.get("groundedness_properties") or {}).get("decision_model", {}).get("probabilities", {})
        score = g.get("groundedness")
        print(f"    Foundry groundedness (judge: {config.JUDGE_DEPLOYMENT}): {score if score is None else f'{score:.0f}'}/5 "
              f"{g.get('groundedness_result')}  probabilities {json.dumps({k: round(v, 2) for k, v in probs.items()})}")

        rewritten = {**row, "title": new["title"], "description": new["description"]}
        call, _ = evaluate.ask_one("decision", rewritten, rewrite_questions())
        verdict = decide(rewritten, call, t)
        failing = [r.message for r in verdict.reasons if r.check in REWRITE_CHECKS]
        print(f"    Gate questions (Decision-1.1): {'pass' if not failing else 'FAIL - ' + '; '.join(failing)}")

        accept = g.get("groundedness_result") == "pass" and not failing
        print(f"    -> {'OFFER THE REWRITE TO THE SELLER' if accept else 'KEEP THE ORIGINAL (rewrite rejected)'}")
        results.append({"listing_id": row["listing_id"], "tempt": tempt, "own_rewrite": bool(own_title),
                        "rewrite": new, "groundedness": score, "groundedness_result": g.get("groundedness_result"),
                        "groundedness_probabilities": probs, "gate_failures": failing, "accepted": accept})

    out = config.RUNS / f"judge-{stamp}.json"
    out.write_text(json.dumps(results, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"\nSaved: {out}")
