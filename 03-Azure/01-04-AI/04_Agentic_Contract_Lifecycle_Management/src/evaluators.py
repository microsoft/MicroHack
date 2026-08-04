"""Challenge 3 — evaluation + cross-model bake-off + quality gate.

Runs the Foundry `azure-ai-evaluation` evaluators over
src/data/evaluation/evaluation_dataset.jsonl, using a *target* callable that
generates the agent's response for each row. Then it does the headline
**cross-model bake-off**: run the Intake & Drafting agent on the **gpt-5.4**
flagship vs the lighter **gpt-5.4-nano** deployment against the SAME scorecard, and
compare quality vs cost/latency. Finally, a **quality gate** fails the build if the
domain **CLM rubric** score drops below a threshold. The rubric is an LLM judge that
scores each response against weighted, contract-specific dimensions (cite the right
clause, flag the deviation, recommend the standard fallback, defer authority to a
human) — a truer measure of a drafting agent than any single generic metric. The gate
averages the rubric over the *groundable* rows only (grounded_qa + clause_risk); the
refusal and tool_call rows are validated by behaviour, so they don't skew it.

Usage:
    python src/evaluators.py                 # evaluate the drafting model (gpt-5.4)
    python src/evaluators.py --bakeoff       # gpt-5.4 vs gpt-5.4-nano comparison
    python src/evaluators.py --gate 3.0      # fail if mean CLM rubric score < 3.0
    python src/evaluators.py --explain       # print each row's score + the judge's reason
    python src/evaluators.py --workers 2     # throttle evaluator concurrency (429s)
"""
from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
import time
from pathlib import Path

# --- azure-ai-evaluation / NLTK import-guard workaround --------------------
# azure-ai-evaluation pulls in NLTK, which installs an import "security finder"
# (nltk/inisec.py) that BLOCKS importing its helper libs (regex, defusedxml,
# wordnet, ...) whenever the module resolves to a path *inside the current
# working directory*. This hack's virtualenv lives INSIDE the repo (./.venv), so
# every site-package counts as "inside cwd" and the finder raises
# "ImportError: Blocked import of <mod> from current working directory".
# NOTE: -P / PYTHONSAFEPATH do NOT help here -- the finder checks Path.cwd(),
# not sys.path. Work around it by importing the azure-ai-evaluation -> NLTK chain
# once from a throwaway temp dir (an ancestor of nothing), so the finder sees
# those modules as OUTSIDE cwd and caches them in sys.modules; later imports are
# cache hits and never re-trigger the guard. The cwd is restored immediately.
def _preload_eval_sdk() -> None:
    import shutil
    import tempfile

    cwd = os.getcwd()
    safe_dir = tempfile.mkdtemp(prefix="clm-eval-")
    try:
        os.chdir(safe_dir)
        import azure.ai.evaluation  # noqa: F401  (loads NLTK + regex/defusedxml/...)
    except Exception:
        pass  # let the real import below surface any genuine error
    finally:
        os.chdir(cwd)
        shutil.rmtree(safe_dir, ignore_errors=True)


_preload_eval_sdk()

# Enable tracing before importing the agents SDK (import has the side effect).
sys.path.insert(0, str(Path(__file__).resolve().parent))
import tracing_setup  # noqa: E402,F401  (sets content-recording env flag)

sys.path.insert(0, str(Path(__file__).resolve().parent / "agents"))  # agent modules

from clm_common.config import settings, credential, DATA_DIR  # noqa: E402
from clm_common.foundry import build_chat_client, function_tool, get_project_client, run_prompt  # noqa: E402

DATASET = DATA_DIR / "evaluation" / "evaluation_dataset.jsonl"


def _corpus_document_count() -> int | None:
    """Best-effort count of documents in the ``clm-corpus`` search index.

    Returns the document count, or ``None`` when it can't be determined (search
    endpoint not configured, or an SDK/auth/transient error). This never raises:
    a flaky preflight must not block an otherwise-valid evaluation run.
    """
    if not settings.search_endpoint:
        return None
    try:
        from azure.search.documents import SearchClient

        client = SearchClient(
            endpoint=settings.search_endpoint,
            index_name=settings.search_index,
            credential=credential(),
        )
        return client.get_document_count()
    except Exception:  # noqa: BLE001 — preflight is advisory, never fatal
        return None

# Retry budget for target calls that hit Azure OpenAI 429 (rate-limit) bursts.
MAX_TARGET_ATTEMPTS = 8
# Default evaluator batch concurrency when neither --workers nor PF_WORKER_COUNT
# is set. Kept low so the four LLM judges don't overwhelm a throttled deployment.
DEFAULT_WORKER_COUNT = 2

# Every dataset row is tagged with a `category`. Groundedness only makes sense
# where the correct answer is *drawn from the corpus*: the `refusal` rows
# (correct answer = "I can't give legal advice") and `tool_call` rows (correct
# answer = a live get_contract_status result, which is deliberately absent from
# the row's context snippet) are validated by *behaviour*, not grounding — so
# scoring them for groundedness would unfairly sink the gate. The gate therefore
# averages groundedness over the GROUNDABLE categories only.
GROUNDABLE_CATEGORIES = {"grounded_qa", "clause_risk"}


def _row_get(row: dict, *keys):
    """Return the first present, non-None value among dotted `keys` in an eval row."""
    for key in keys:
        if key in row and row[key] is not None:
            return row[key]
    return None


def _groundable_groundedness(result: dict) -> tuple[float | None, int, int]:
    """Mean groundedness over the groundable rows (grounded_qa + clause_risk).

    Reads per-row scores from ``result["rows"]`` and averages only rows whose
    ``category`` is groundable. Returns ``(mean, n_used, n_total)``; ``mean`` is
    ``None`` when per-row categories/scores aren't available (older SDKs) so the
    caller can fall back to the dataset-wide aggregate.
    """
    rows = result.get("rows") or []
    have_categories = any(
        _row_get(r, "inputs.category", "category") is not None for r in rows
    )
    if not rows or not have_categories:
        return None, 0, len(rows)
    scores: list[float] = []
    for row in rows:
        category = _row_get(row, "inputs.category", "category")
        score = _row_get(
            row,
            "outputs.groundedness.groundedness",
            "outputs.groundedness",
            "groundedness.groundedness",
            "groundedness",
        )
        if category is None or score is None:
            continue
        if str(category) in GROUNDABLE_CATEGORIES:
            scores.append(float(score))
    if not scores:
        return None, 0, len(rows)
    return round(sum(scores) / len(scores), 3), len(scores), len(rows)


def _groundable_rubric(result: dict) -> tuple[float | None, int, int]:
    """Mean CLM-rubric score over the groundable rows (grounded_qa + clause_risk).

    Mirrors ``_groundable_groundedness`` but reads the rubric metric. Returns
    ``(mean, n_used, n_total)``; ``mean`` is ``None`` when per-row scores/categories
    aren't available so the caller can fall back to the dataset-wide aggregate.
    """
    rows = result.get("rows") or []
    have_categories = any(
        _row_get(r, "inputs.category", "category") is not None for r in rows
    )
    if not rows or not have_categories:
        return None, 0, len(rows)
    scores: list[float] = []
    for row in rows:
        category = _row_get(row, "inputs.category", "category")
        score = _row_get(
            row,
            "outputs.clm_rubric.clm_rubric",
            "outputs.clm_rubric",
            "clm_rubric.clm_rubric",
            "clm_rubric",
        )
        if category is None or score is None:
            continue
        if str(category) in GROUNDABLE_CATEGORIES:
            scores.append(float(score))
    if not scores:
        return None, 0, len(rows)
    return round(sum(scores) / len(scores), 3), len(scores), len(rows)


def _print_row_explanations(result: dict) -> None:
    """Print each row's groundedness score + the judge's own reason (``--explain``).

    Turns the single aggregate gate number into a row-by-row diagnosis: for every
    dataset row it shows the category, the query, the agent's response (truncated)
    and — crucially — the LLM judge's ``groundedness_reason``. This is what tells
    you *why* a groundable row scored low: the reason string distinguishes the two
    usual culprits — the agent **over-answering** past the terse reference context
    (claims true but not in ``context``) vs. the agent **grounding on the wrong
    retrieved document** (claims that conflict with the standard clause).
    """
    rows = result.get("rows") or []
    if not rows:
        print("· --explain: no per-row results available from this SDK version.")
        return
    print("\n--- Per-row scores (--explain) ---")
    print("    GATED rows (grounded_qa + clause_risk) drive the quality gate; the")
    print("    CLM rubric is the gate metric — groundedness is shown for reference.\n")
    for i, row in enumerate(rows, 1):
        category = _row_get(row, "inputs.category", "category")
        query = _row_get(row, "inputs.query", "query")
        response = _row_get(row, "outputs.response", "response", "inputs.response") or ""
        score = _row_get(
            row,
            "outputs.groundedness.groundedness",
            "outputs.groundedness",
            "groundedness.groundedness",
            "groundedness",
        )
        reason = _row_get(
            row,
            "outputs.groundedness.groundedness_reason",
            "groundedness.groundedness_reason",
            "outputs.groundedness_reason",
            "groundedness_reason",
        )
        rubric = _row_get(
            row,
            "outputs.clm_rubric.clm_rubric",
            "outputs.clm_rubric",
            "clm_rubric.clm_rubric",
            "clm_rubric",
        )
        rubric_reason = _row_get(
            row,
            "outputs.clm_rubric.clm_rubric_reason",
            "clm_rubric.clm_rubric_reason",
            "outputs.clm_rubric_reason",
            "clm_rubric_reason",
        )
        tag = "GATED" if str(category) in GROUNDABLE_CATEGORIES else "info "
        oneline = lambda s: " ".join(str(s).split())  # noqa: E731
        print(f"[{i:>2}] {tag}  category={category}  clm_rubric={rubric}  groundedness={score}")
        print(f"     Q: {oneline(query)[:150]}")
        print(f"     A: {oneline(response)[:260]}")
        if rubric_reason:
            print(f"     rubric:   {oneline(rubric_reason)[:320]}")
        if reason:
            print(f"     grounded: {oneline(reason)[:320]}")
        print()


def _is_rate_limit(exc: BaseException) -> bool:
    """True if `exc` (or anything in its cause/context chain) is a 429 rate-limit.

    Azure OpenAI surfaces throttling as ``openai.RateLimitError`` (HTTP 429,
    ``code='rate_limit_exceeded'``), but retries can re-wrap it as an
    ``APIConnectionError`` whose ``__cause__`` is the original 429 — so we walk
    the chain and also fall back to matching the rendered message.
    """
    seen: set[int] = set()
    cur: BaseException | None = exc
    while cur is not None and id(cur) not in seen:
        seen.add(id(cur))
        status = getattr(cur, "status_code", None) or getattr(cur, "http_status", None)
        code = getattr(cur, "code", None)
        if status == 429 or code == "rate_limit_exceeded":
            return True
        text = str(cur).lower()
        if any(m in text for m in ("rate_limit_exceeded", "too_many_requests", "error code: 429")):
            return True
        cur = cur.__cause__ or cur.__context__
    return False


def judge_model_config():
    """AzureOpenAIModelConfiguration for the LLM judge (an Azure OpenAI GPT deployment).

    Reads AZURE_OPENAI_* if present, otherwise derives the endpoint from the
    Foundry project and uses the orchestrator GPT deployment as the judge.

    The config is assembled as a dict so ``api_key`` is only included when it is
    actually set. Passing ``api_key=None`` explicitly makes the SDK treat the
    request as key-based and rejects the AAD (keyless) path — omitting the key
    lets the evaluators authenticate with the ambient credential.
    """
    from azure.ai.evaluation import AzureOpenAIModelConfiguration

    endpoint = os.environ.get("AZURE_OPENAI_ENDPOINT")
    if not endpoint and settings.project_endpoint:
        # AI Services base endpoint also serves the Azure OpenAI surface.
        endpoint = settings.project_endpoint.split("/api/projects")[0]

    cfg: dict = {
        "azure_endpoint": endpoint,
        "azure_deployment": os.environ.get("AZURE_OPENAI_DEPLOYMENT", settings.model_orchestrator),
        "api_version": os.environ.get("AZURE_OPENAI_API_VERSION", "2024-10-21"),
    }
    api_key = os.environ.get("AZURE_OPENAI_API_KEY")
    if api_key:  # only pass when set → otherwise SDK uses AAD
        cfg["api_key"] = api_key
    return AzureOpenAIModelConfiguration(**cfg)


def build_target(model: str, connection_id: str):
    """Create an Intake & Drafting agent target on `model` and return a (fn, meta) pair.

    The returned callable maps a `query` to the agent's `response`, and records
    latency so the bake-off can compare cost/latency alongside quality. The agent
    is built once per worker thread (via thread-local storage) so the evaluation
    harness can invoke the target concurrently without sharing an event loop.
    """
    import threading

    from intake_drafting_agent import INSTRUCTIONS
    from agent_framework import Agent
    from clm_common.tools import get_contract_status
    from kb_setup import build_knowledge_tool

    meta = {"latencies": []}
    tls = threading.local()

    def _agent():
        agent = getattr(tls, "agent", None)
        if agent is None:
            agent = Agent(
                client=build_chat_client(model),
                name=f"eval-intake-{model}",
                instructions=INSTRUCTIONS,
                tools=[
                    build_knowledge_tool(connection_id=connection_id),
                    function_tool(get_contract_status),
                ],
            )
            tls.agent = agent
        return agent

    def target(query: str) -> dict:
        start = time.perf_counter()
        for attempt in range(1, MAX_TARGET_ATTEMPTS + 1):
            try:
                response = run_prompt(_agent(), query)
                break
            except Exception as exc:  # retry only on 429s; re-raise everything else
                if not _is_rate_limit(exc) or attempt == MAX_TARGET_ATTEMPTS:
                    raise
                # Exponential backoff with jitter to spread out retry bursts.
                delay = min(2 ** attempt, 60) + random.uniform(0, 1)
                print(f"  ⏳ 429 rate-limit on target (attempt {attempt}/"
                      f"{MAX_TARGET_ATTEMPTS}); backing off {delay:.1f}s")
                time.sleep(delay)
        meta["latencies"].append(time.perf_counter() - start)
        return {"response": response}

    return target, meta


# --- Domain rubric evaluator (Challenge 3, Task 6) -------------------------
# A *rubric evaluator* is Foundry's recommended primary measure of agent
# quality: an LLM judge scores each response against weighted, domain-specific
# dimensions you define, instead of one generic metric. For a CLM drafting agent
# "good" means citing the right clause, flagging the deviation, recommending the
# standard fallback, and deferring authority to a human — none of which a single
# groundedness number captures. These dimensions are lifted straight from the
# Intake & Drafting agent's own instructions, so the rubric scores the behaviour
# the agent was actually told to exhibit. This is the code twin of the portal
# "Rubric / custom (prompt-based) evaluator" you build in Task 6, and the same
# rubric drives the CI quality gate.
# Docs: https://learn.microsoft.com/azure/foundry/concepts/evaluation-evaluators/rubric-evaluators
CLM_RUBRIC: list[dict] = [
    {"id": "clause_identification", "weight": 9,
     "description": "Cites the correct governing clause(s) or template position from the "
                    "contract corpus for the question — the right Clause Library entry, "
                    "MSA/NDA template term, policy, or Delegation-of-Authority band — with a "
                    "source citation."},
    {"id": "deviation_flagging", "weight": 8,
     "description": "Correctly flags where the requested or counterparty term deviates from "
                    "the company standard (e.g. Net 30 vs the Net 60 standard, unlimited "
                    "liability vs the 12-month cap) and does not miss a material red flag."},
    {"id": "fallback_recommendation", "weight": 6,
     "description": "When a deviation is found, recommends the real standard or acceptable "
                    "fallback position from the negotiation playbook (preferred → walk-away), "
                    "not an invented one."},
    {"id": "authority_escalation", "weight": 5,
     "description": "Respects the contracting policy and Delegation of Authority: routes "
                    "sign-off to the correct approver by role/threshold, never self-approves, "
                    "and refuses to give definitive legal advice."},
    {"id": "grounded_no_fabrication", "weight": 4,
     "description": "Stays grounded in the retrieved corpus/context and does not fabricate "
                    "clauses, numbers, or obligations. If the corpus lacks the answer, says so."},
    {"id": "communication_clarity", "weight": 2,
     "description": "Clear, well-structured, professional response a contract manager can act on."},
    {"id": "general_quality", "weight": 5, "always_applicable": True,
     "description": "Overall response quality not already captured by the dimensions above."},
]


def _extract_json(text: str) -> dict:
    """Best-effort parse of a single JSON object from an LLM reply.

    Tolerates ```code fences``` and leading/trailing prose by slicing from the
    first ``{`` to the last ``}`` before parsing.
    """
    text = (text or "").strip()
    if text.startswith("```"):
        text = text.strip("`")
        newline = text.find("\n")
        if newline != -1 and text[:newline].strip().lower() in ("json", ""):
            text = text[newline + 1:]
    start, end = text.find("{"), text.rfind("}")
    if start != -1 and end != -1 and end > start:
        text = text[start:end + 1]
    return json.loads(text)


class ClmRubricEvaluator:
    """LLM-judge rubric evaluator for the CLM drafting agent (Challenge 3, Task 6).

    Scores each response against ``CLM_RUBRIC``'s weighted dimensions (1–5 each)
    and returns the weighted average on a 1–5 scale as ``clm_rubric`` plus the
    judge's ``clm_rubric_reason``. It plugs into ``azure-ai-evaluation``'s
    ``evaluate()`` exactly like the built-in evaluators (a callable that takes the
    mapped columns and returns a metrics dict), so no extra wiring is needed.

    The judge is the same Azure OpenAI deployment used by the built-in evaluators
    (``judge_model_config``); we call it directly via the ``openai`` client because
    a rubric is just one templated judge prompt.
    """

    _MIN, _MAX = 1.0, 5.0

    def __init__(self, model_config: dict):
        self._deployment = str(model_config.get("azure_deployment") or "")
        self._client = self._build_client(model_config)
        self._system = self._build_system_prompt()

    @staticmethod
    def _build_client(model_config: dict):
        from openai import AzureOpenAI

        endpoint = model_config.get("azure_endpoint")
        api_version = model_config.get("api_version") or "2024-10-21"
        api_key = model_config.get("api_key")
        if api_key:  # key auth only when explicitly configured
            return AzureOpenAI(azure_endpoint=endpoint, api_version=api_version, api_key=api_key)
        # Otherwise keyless (AAD) — the same ambient credential the rest of the hack uses.
        from azure.identity import get_bearer_token_provider

        token_provider = get_bearer_token_provider(
            credential(), "https://cognitiveservices.azure.com/.default"
        )
        return AzureOpenAI(
            azure_endpoint=endpoint,
            api_version=api_version,
            azure_ad_token_provider=token_provider,
        )

    @staticmethod
    def _build_system_prompt() -> str:
        lines = [
            "You are a meticulous contract-management QA reviewer scoring an AI drafting "
            "agent's response against a fixed rubric.",
            "Score EACH dimension below from 1 (poor) to 5 (excellent):",
        ]
        for d in CLM_RUBRIC:
            note = " (always applies)" if d.get("always_applicable") else ""
            lines.append(f"- {d['id']} (weight {d['weight']}){note}: {d['description']}")
        lines += [
            "",
            "If a dimension does not apply to this particular response, score it 3 and note "
            "'not applicable' in its reason.",
            "Judge only against the provided reference context and reference answer; do not use "
            "outside knowledge.",
            "Respond with ONLY a JSON object, no prose, in exactly this shape:",
            '{"dimensions": {"<id>": {"score": <1-5>, "reason": "<short>"}, ...}, '
            '"reason": "<one sentence naming the decisive dimensions>"}',
        ]
        return "\n".join(lines)

    @staticmethod
    def _build_user_prompt(query, response, context, ground_truth) -> str:
        return (
            f"# Question\n{query}\n\n"
            f"# Reference context (authoritative corpus passage)\n{context or '(none provided)'}\n\n"
            f"# Reference answer (ground truth)\n{ground_truth or '(none provided)'}\n\n"
            f"# Agent response to score\n{response or '(empty)'}\n"
        )

    def _weighted_score(self, data: dict) -> float:
        # Fixed denominator = the full rubric weight, so a truncated/degenerate judge
        # reply (e.g. only one dimension returned) can't renormalize its way to a high
        # score and slip past the gate. A missing, non-finite, or unparseable dimension
        # counts as the worst score rather than being dropped.
        dims = data.get("dimensions") or data.get("scores") or {}
        acc = 0.0
        total_w = sum(d["weight"] for d in CLM_RUBRIC)
        for d in CLM_RUBRIC:
            entry = dims.get(d["id"])
            raw = entry.get("score") if isinstance(entry, dict) else entry
            try:
                s = float(raw)
            except (TypeError, ValueError):
                s = self._MIN
            if not math.isfinite(s):
                s = self._MIN
            acc += max(self._MIN, min(self._MAX, s)) * d["weight"]
        return round(acc / total_w, 3) if total_w else self._MIN

    def __call__(self, *, response: str = "", query: str = "", context: str = "",
                 ground_truth: str = "", **kwargs) -> dict:
        user = self._build_user_prompt(query, response, context, ground_truth)
        for attempt in range(1, MAX_TARGET_ATTEMPTS + 1):
            try:
                completion = self._client.chat.completions.create(
                    model=self._deployment,
                    messages=[
                        {"role": "system", "content": self._system},
                        {"role": "user", "content": user},
                    ],
                )
                raw = completion.choices[0].message.content or ""
                data = _extract_json(raw)
                return {
                    "clm_rubric": self._weighted_score(data),
                    "clm_rubric_reason": str(data.get("reason") or "")[:600],
                }
            except Exception as exc:  # 429 → backoff & retry; otherwise floor the row
                if _is_rate_limit(exc) and attempt < MAX_TARGET_ATTEMPTS:
                    time.sleep(min(2 ** attempt, 60) + random.uniform(0, 1))
                    continue
                # A row we genuinely can't judge floors to the minimum (matching
                # Foundry's documented behaviour that an errored evaluator item scores
                # the low end), so a silent judge failure can't slip a bad build past
                # the gate. --explain surfaces the reason string below.
                return {
                    "clm_rubric": self._MIN,
                    "clm_rubric_reason": f"rubric judge error: {type(exc).__name__}: {exc}"[:300],
                }


def evaluators_dict():
    from azure.ai.evaluation import (
        GroundednessEvaluator,
        RelevanceEvaluator,
        CoherenceEvaluator,
        FluencyEvaluator,
    )

    cfg = judge_model_config()
    # gpt-5.x judges are reasoning models: tell the evaluators so they use the
    # reasoning-model prompt/parameters instead of the classic chat path.
    deployment = str(cfg.get("azure_deployment", "")).lower()
    is_reasoning = deployment.startswith("gpt-5")
    kwargs = {"model_config": cfg, "is_reasoning_model": is_reasoning}
    return {
        "groundedness": GroundednessEvaluator(**kwargs),
        "relevance": RelevanceEvaluator(**kwargs),
        "coherence": CoherenceEvaluator(**kwargs),
        "fluency": FluencyEvaluator(**kwargs),
        "clm_rubric": ClmRubricEvaluator(cfg),
    }


def run_eval(model: str, connection_id: str, *, explain: bool = False) -> dict:
    """Evaluate the agent on `model` over the dataset; return the metrics summary."""
    from azure.ai.evaluation import evaluate

    target, meta = build_target(model, connection_id)
    result = evaluate(
        data=str(DATASET),
        target=target,
        evaluators=evaluators_dict(),
        evaluator_config={
            "default": {
                "column_mapping": {
                    "query": "${data.query}",
                    "response": "${target.response}",
                    "context": "${data.context}",
                    "ground_truth": "${data.ground_truth}",
                }
            }
        },
    )

    if explain:
        _print_row_explanations(result)

    metrics = dict(result.get("metrics", {}))
    g_groundable, n_used, _ = _groundable_groundedness(result)
    if g_groundable is not None:
        metrics["_groundedness_groundable"] = g_groundable
        metrics["_groundedness_groundable_n"] = n_used
    r_groundable, r_used, _ = _groundable_rubric(result)
    if r_groundable is not None:
        metrics["_rubric_groundable"] = r_groundable
        metrics["_rubric_groundable_n"] = r_used
    lat = meta["latencies"]
    metrics["_mean_latency_s"] = round(sum(lat) / len(lat), 2) if lat else None
    metrics["_model"] = model
    return metrics


def print_scorecard(title: str, metrics: dict) -> None:
    print(f"\n=== {title} ({metrics.get('_model')}) ===")
    for k, v in sorted(metrics.items()):
        if k.startswith("_"):
            continue
        print(f"  {k:<40} {v}")
    groundable = metrics.get("_groundedness_groundable")
    if groundable is not None:
        print(f"  {'groundedness (groundable rows)':<40} {groundable}"
              f"  (n={metrics.get('_groundedness_groundable_n')})")
    rubric = metrics.get("_rubric_groundable")
    if rubric is not None:
        print(f"  {'CLM rubric (gate: groundable rows)':<40} {rubric}"
              f"  (n={metrics.get('_rubric_groundable_n')})")
    print(f"  {'mean latency (s)':<40} {metrics.get('_mean_latency_s')}")


def _configure_workers(workers: int | None) -> None:
    """Set PF_WORKER_COUNT (evaluator batch concurrency) and print the active value.

    Precedence: explicit --workers > existing PF_WORKER_COUNT env var > default.
    Lower concurrency spreads out the four LLM-judge calls per row so a throttled
    judge deployment is less likely to return HTTP 429.
    """
    if workers is not None:
        os.environ["PF_WORKER_COUNT"] = str(workers)
    elif not os.environ.get("PF_WORKER_COUNT"):
        os.environ["PF_WORKER_COUNT"] = str(DEFAULT_WORKER_COUNT)
    print(f"Evaluator worker concurrency (PF_WORKER_COUNT): {os.environ['PF_WORKER_COUNT']}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bakeoff", action="store_true",
                        help="compare the drafting model (gpt-5.4) vs gpt-5.4-nano")
    parser.add_argument("--gate", type=float, default=None,
                        help="fail if the mean CLM rubric score < THRESHOLD (1–5; e.g. 3.0)")
    parser.add_argument("--explain", action="store_true",
                        help="print each row's groundedness score + the judge's own "
                             "reason (diagnose WHY the gate score is what it is)")
    parser.add_argument("--workers", type=int, default=None,
                        help="override PF_WORKER_COUNT (evaluator batch concurrency); "
                             f"lower values reduce 429 rate-limit pressure "
                             f"(default: {DEFAULT_WORKER_COUNT})")
    args = parser.parse_args()

    _configure_workers(args.workers)

    if not DATASET.exists():
        print(f"✗ Missing dataset: {DATASET}")
        return 1

    # Preflight: evaluation grounds answers on the `clm-corpus` search index
    # (seeded in Challenge 1). If it's empty, every groundable row scores low and
    # the quality gate fails for a confusing reason — so fail fast with the fix
    # instead of burning a full LLM-judged run. Only a *definitive* zero blocks;
    # an unknown count (endpoint unset / transient error) never stops the run.
    corpus_docs = _corpus_document_count()
    if corpus_docs == 0:
        print(f"✗ The `{settings.search_index}` Azure AI Search index has 0 documents.")
        print("  Evaluation would score every grounded row low, so it's stopped early.")
        print("  Seed the corpus (Challenge 1), then re-run this evaluation:")
        print("      python src/scripts/seed_corpus.py   # SharePoint indexer, or auto local-PDF fallback")
        print("      python src/kb_setup.py               # verify the connection + index")
        print("      python src/evaluators.py --gate 3.0")
        return 4
    if corpus_docs is None and settings.search_endpoint:
        print(f"· Couldn't read the `{settings.search_index}` index document count "
              "(transient/auth) — continuing. If groundedness is low, re-seed with "
              "src/scripts/seed_corpus.py.")

    from kb_setup import get_search_connection_id

    with get_project_client() as project:
        tracing_setup.enable_tracing(project)
        connection_id = get_search_connection_id(project)

    primary = run_eval(settings.model_drafting, connection_id, explain=args.explain)
    print_scorecard("Intake & Drafting", primary)

    alt = None
    if args.bakeoff:
        alt = run_eval(settings.model_renewal, connection_id, explain=args.explain)
        print_scorecard("Intake & Drafting", alt)
        print(f"\n--- Bake-off ({settings.model_drafting} vs {settings.model_renewal}) ---")
        keys = [k for k in primary if not k.startswith("_")]
        for k in sorted(keys):
            print(f"  {k:<40} {settings.model_drafting}={primary.get(k)}   "
                  f"{settings.model_renewal}={alt.get(k)}")
        print(f"  {'mean latency (s)':<40} {settings.model_drafting}={primary['_mean_latency_s']}   "
              f"{settings.model_renewal}={alt['_mean_latency_s']}")

    if args.gate is not None:
        gated = primary.get("_rubric_groundable")
        overall = primary.get("clm_rubric.clm_rubric") or primary.get("clm_rubric")
        score = gated if gated is not None else overall
        scope = "groundable rows" if gated is not None else "all rows"
        print(f"\nQuality gate: CLM rubric={score} ({scope}) threshold={args.gate}")
        if score is None:
            print("⚠️  Could not read the CLM rubric metric — check evaluator output keys.")
            return 2
        if float(score) < args.gate:
            print("❌ GATE FAILED — CLM rubric below threshold. Blocking release.")
            if float(score) < 2.0:
                print("   ↳ A score this low usually means the `clm-corpus` Azure AI Search")
                print("     index is empty or not connected, so the agent can't cite the right")
                print("     clauses. Re-run Challenge 1 seeding, then verify with:")
                print("       python src/kb_setup.py")
            else:
                print("   ↳ The agent is grounding, but some rows miss rubric dimensions")
                print("     (wrong clause, missed deviation, no fallback, or self-approval).")
                print("     See which rows + the judge's reason with:")
                print("       python src/evaluators.py --explain")
            return 3
        print("✅ GATE PASSED.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
