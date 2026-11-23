"""Three ways to answer the same questions about a listing.

| Mode       | Model                  | API                                              |
|------------|------------------------|--------------------------------------------------|
| `decision` | Microsoft-Decision-1.1 | POST {DECISION_ENDPOINT}/providers/microsoft/v1/systemone |
| `luna`     | gpt-6-luna             | POST {OPENAI_ENDPOINT}/openai/v1/decisions (OpenAI SDK `client.decisions.create`) |
| `llm`      | gpt-6-luna             | Responses API, JSON output — a *generative* baseline, no probabilities |

`luna` and `llm` use the same deployment: comparing them compares two ways of *using* one
model, not two models.

All three sign in with your Entra ID (`az login`) — there are no keys. Each request bundles
every question about one listing, so one listing = one request.
"""

from __future__ import annotations

import functools
import json
import random
import threading
import time
from typing import Callable

import httpx
import openai
from azure.identity import AzureCliCredential, ChainedTokenCredential, DefaultAzureCredential, get_bearer_token_provider

import config
from gate.evidence import Evidence
from gate.spec import Answer, Choice, GateCall, Question, Score, YesNo

MODES = ("decision", "luna", "llm")
RETRYABLE = {408, 409, 429, 500, 502, 503, 504}


@functools.lru_cache(maxsize=1)
def token_provider() -> Callable[[], str]:
    """Returns a function that gives a fresh Entra token for Azure AI (refreshed automatically)."""
    credential = ChainedTokenCredential(
        AzureCliCredential(),
        DefaultAzureCredential(exclude_cli_credential=True, exclude_interactive_browser_credential=True),
    )
    return get_bearer_token_provider(credential, config.TOKEN_SCOPE)


class Retry(Exception):
    def __init__(self, status: int | str, wait_s: float | None, detail: str):
        super().__init__(detail)
        self.status, self.wait_s, self.detail = status, wait_s, detail


class Pacer:
    """Spaces requests so a deployment's requests-per-minute AND tokens-per-minute limits hold.

    Azure estimates a request's tokens from its size (a base64 photo counts in full), so we
    estimate the same way: characters of the request body / 4.
    """

    def __init__(self, capacity: float):
        capacity = max(capacity, 1.0)
        self.request_interval = 60.0 / capacity * 1.05  # 5% headroom
        self.tokens_per_second = capacity * 1000 / 60 * 0.9  # 10% headroom
        self._next = 0.0
        self._lock = threading.Lock()

    def wait(self, estimated_tokens: int = 0) -> None:
        cost = max(self.request_interval, estimated_tokens / self.tokens_per_second)
        with self._lock:
            now = time.monotonic()
            slot = max(now, self._next)
            self._next = slot + cost
        if slot > now:
            time.sleep(slot - now)


def estimate_tokens(body: object) -> int:
    return len(json.dumps(body)) // 4


# `luna` and `llm` call the same gpt-6-luna deployment, so they share one budget.
PACERS = {"decision": Pacer(config.DECISION_CAPACITY), "luna": Pacer(config.LUNA_CAPACITY)}
PACERS["llm"] = PACERS["luna"]


def _retry_after(headers) -> float | None:
    if not headers:
        return None
    for key, scale in (("retry-after-ms", 0.001), ("x-ms-retry-after-ms", 0.001), ("retry-after", 1.0)):
        value = headers.get(key)
        if value:
            try:
                return float(value) * scale
            except ValueError:
                pass
    return None


def with_retries(model: str, attempt: Callable[[], GateCall], estimated_tokens: int = 0) -> GateCall:
    """Call `attempt()` until it succeeds, backing off on 429/5xx/timeouts, within a time budget."""
    started = time.perf_counter()
    tries = 0
    while True:
        tries += 1
        PACERS[model].wait(estimated_tokens)
        t0 = time.perf_counter()
        try:
            call = attempt()
            call.latency_ms = (time.perf_counter() - t0) * 1000
            call.wait_ms = (t0 - started) * 1000
            call.attempts = tries
            return call
        except Retry as r:
            elapsed = time.perf_counter() - started
            backoff = r.wait_s if r.wait_s is not None else min(30.0, 2 ** tries)
            backoff += random.uniform(0, 1.0)  # jitter, so a room full of laptops doesn't retry in step
            if elapsed + backoff > config.MAX_RETRY_SECONDS:
                return GateCall(model=model, answers={}, attempts=tries, wait_ms=elapsed * 1000,
                                error=f"gave up after {tries} attempts: {r.status} {r.detail[:200]}")
            time.sleep(backoff)


def not_asked(questions: list[Question], ev: Evidence) -> tuple[list[Question], dict[str, Answer]]:
    """Photo questions are skipped when there is no photo (the rules send those listings to review)."""
    ask, skipped = [], {}
    for q in questions:
        if q.requires_photo and not ev.photo_b64:
            skipped[q.name] = Answer(name=q.name, kind=q.kind, status="not_asked", detail="no photo")
        else:
            ask.append(q)
    return ask, skipped


def missing(questions: list[Question], answers: dict[str, Answer]) -> dict[str, Answer]:
    """Any question the provider didn't answer gets an explicit error answer, never a default."""
    for q in questions:
        answers.setdefault(q.name, Answer(name=q.name, kind=q.kind, status="error", detail="no answer returned"))
    return answers


# --------------------------------------------------------------------------------------------
# Microsoft-Decision-1.1 (the "system one" request format, shared with TypeSafe's Jev)
# --------------------------------------------------------------------------------------------

def systemone_question(q: Question) -> dict:
    if isinstance(q, YesNo):
        return {"type": "noul", "instructions": q.instructions}
    if isinstance(q, Choice):
        return {"type": "choice", "instructions": q.instructions,
                "criteria": {o.value: o.description for o in q.options}}
    if isinstance(q, Score):
        return {"type": "score", "instructions": q.instructions,
                "criteria": [f"{o.value}: {o.description}" for o in q.levels]}
    raise TypeError(q)


def parse_systemone(q: Question, raw: dict) -> Answer:
    if raw.get("type") == "noul":
        p = float(raw["noul"])
        return Answer(name=q.name, kind=q.kind, probability=p, distribution={"yes": p, "no": 1 - p})
    if raw.get("type") == "choice":
        dist = {k: float(v) for k, v in raw.get("probabilities", {}).items()}
        choice = raw.get("choice")
        return Answer(name=q.name, kind=q.kind, value=choice, probability=dist.get(choice),
                      distribution=dist, provider_confidence=raw.get("confidence"))
    if raw.get("type") == "score":
        dist = {str(k): float(v) for k, v in raw.get("probabilities", {}).items()}
        top = max(dist, key=dist.get) if dist else None
        return Answer(name=q.name, kind=q.kind, value=int(top) if top is not None else None,
                      probability=dist.get(top), distribution=dist, expected_score=raw.get("score"),
                      provider_confidence=raw.get("confidence"))
    return Answer(name=q.name, kind=q.kind, status="refused", detail=json.dumps(raw)[:300])


@functools.lru_cache(maxsize=1)
def _http() -> httpx.Client:
    return httpx.Client(timeout=httpx.Timeout(60.0, connect=10.0))


def systemone_body(ev: Evidence, ask: list[Question]) -> dict:
    state = ev.state
    body: dict = {"model": config.DECISION_DEPLOYMENT,
                  "questions": {q.name: systemone_question(q) for q in ask}}
    if ev.photo_b64:
        # The photo is an asset; the state refers to it by name.
        body["assets"] = {"photo.jpg": {"type": "image", "format": "jpeg", "data_base64": ev.photo_b64}}
        state = {**state, "photo": "image:photo.jpg"} if isinstance(state, dict) else f"{state}\nimage:photo.jpg"
    body["state"] = state
    return body


def ask_decision(ev: Evidence, questions: list[Question]) -> GateCall:
    endpoint = config.require("DECISION_ENDPOINT", config.DECISION_ENDPOINT)
    ask, skipped = not_asked(questions, ev)
    body = systemone_body(ev, ask)

    def attempt() -> GateCall:
        try:
            r = _http().post(f"{endpoint}/providers/microsoft/v1/systemone", json=body,
                             headers={"Authorization": f"Bearer {token_provider()()}"})
        except httpx.TimeoutException as exc:
            raise Retry("timeout", None, str(exc)) from exc
        except httpx.TransportError as exc:
            raise Retry("network", None, str(exc)) from exc
        if r.status_code in RETRYABLE:
            raise Retry(r.status_code, _retry_after(r.headers), r.text)
        if r.status_code != 200:
            return GateCall(model="decision", answers={}, error=f"HTTP {r.status_code}: {r.text[:300]}")
        payload = r.json()
        raw_answers = payload.get("answers", {})
        answers = {q.name: parse_systemone(q, raw_answers[q.name]) for q in ask if q.name in raw_answers}
        usage = payload.get("usage", {})
        return GateCall(model="decision", answers=missing(ask, answers) | skipped,
                        input_tokens=usage.get("input_tokens", 0), output_tokens=usage.get("output_tokens", 0))

    call = with_retries("decision", attempt, estimate_tokens(body))
    if call.error and not call.answers:
        call.answers = {q.name: Answer(name=q.name, kind=q.kind, status="error", detail=call.error) for q in ask} | skipped
    return call


# --------------------------------------------------------------------------------------------
# Azure OpenAI Decisions API (gpt-6-luna) and the generative baseline (Responses API)
# --------------------------------------------------------------------------------------------

@functools.lru_cache(maxsize=1)
def openai_client() -> openai.OpenAI:
    endpoint = config.require("OPENAI_ENDPOINT", config.OPENAI_ENDPOINT)
    # api_key accepts a callable: the SDK asks for a fresh Entra token on every request.
    # max_retries=0 because with_retries() handles retries and reports the waiting time.
    return openai.OpenAI(base_url=f"{endpoint}/openai/v1/", api_key=token_provider(), max_retries=0, timeout=60)


def decisions_question(q: Question) -> dict:
    if isinstance(q, YesNo):
        return {"type": "predicate", "name": q.name, "instructions": q.instructions}
    if isinstance(q, Choice):
        return {"type": "choice", "name": q.name, "instructions": q.instructions,
                "choices": [{"value": o.value, "description": o.description} for o in q.options]}
    if isinstance(q, Score):
        return {"type": "score", "name": q.name, "instructions": q.instructions,
                "levels": [{"label": o.value, "description": o.description} for o in q.levels]}
    raise TypeError(q)


def parse_decisions(q: Question, raw: dict) -> Answer:
    kind = raw.get("type")
    if kind == "predicate":
        p = float(raw["probability"])
        return Answer(name=q.name, kind=q.kind, probability=p, distribution={"yes": p, "no": 1 - p})
    if kind == "choice":
        dist = {d["value"]: float(d["probability"]) for d in raw.get("probabilities", [])}
        choice = raw.get("choice")
        return Answer(name=q.name, kind=q.kind, value=choice, probability=dist.get(choice),
                      distribution=dist, provider_confidence=raw.get("confidence"))
    if kind == "score":
        dist = {str(d["value"]): float(d["probability"]) for d in raw.get("probabilities", [])}
        top = max(dist, key=dist.get) if dist else None
        return Answer(name=q.name, kind=q.kind, value=int(top) if top is not None else None,
                      probability=dist.get(top), distribution=dist, expected_score=raw.get("score"),
                      provider_confidence=raw.get("confidence"))
    # "refusal" — the model declined to answer this question.
    return Answer(name=q.name, kind=q.kind, status="refused", detail=json.dumps(raw)[:300])


def openai_input(ev: Evidence, preamble: str = "") -> list[dict]:
    content: list[dict] = [{"type": "input_text", "text": f"{preamble}{ev.text()}"}]
    if ev.photo_b64:
        content.append({"type": "input_text", "text": "Photo:"})
        content.append({"type": "input_image", "image_url": f"data:image/jpeg;base64,{ev.photo_b64}"})
    return [{"role": "user", "content": content}]


def _openai_attempt(model: str, fn: Callable[[], GateCall]) -> GateCall:
    try:
        return fn()
    except openai.APITimeoutError as exc:
        raise Retry("timeout", None, str(exc)) from exc
    except openai.APIConnectionError as exc:
        raise Retry("network", None, str(exc)) from exc
    except openai.APIStatusError as exc:
        if exc.status_code in RETRYABLE:
            raise Retry(exc.status_code, _retry_after(exc.response.headers), str(exc)) from exc
        return GateCall(model=model, answers={}, error=f"HTTP {exc.status_code}: {str(exc)[:300]}")


def ask_luna(ev: Evidence, questions: list[Question]) -> GateCall:
    ask, skipped = not_asked(questions, ev)

    def attempt() -> GateCall:
        def call() -> GateCall:
            resp = openai_client().decisions.create(
                model=config.LUNA_DEPLOYMENT, input=openai_input(ev),
                questions=[decisions_question(q) for q in ask])
            payload = resp.model_dump()
            by_name = {a.get("name"): a for a in payload.get("answers", [])}
            answers = {q.name: parse_decisions(q, by_name[q.name]) for q in ask if q.name in by_name}
            usage = payload.get("usage") or {}
            return GateCall(model="luna", answers=missing(ask, answers) | skipped,
                            input_tokens=usage.get("input_tokens", 0), output_tokens=usage.get("output_tokens", 0))
        return _openai_attempt("luna", call)

    call = with_retries("luna", attempt,
                        estimate_tokens([openai_input(ev), [decisions_question(q) for q in ask]]))
    if call.error and not call.answers:
        call.answers = {q.name: Answer(name=q.name, kind=q.kind, status="error", detail=call.error) for q in ask} | skipped
    return call


def llm_schema(questions: list[Question]) -> dict:
    props: dict = {}
    for q in questions:
        if isinstance(q, YesNo):
            props[q.name] = {"type": "boolean"}
        elif isinstance(q, Choice):
            props[q.name] = {"type": "string", "enum": [o.value for o in q.options]}
        else:
            props[q.name] = {"type": "integer", "enum": list(range(len(q.levels)))}
    return {"type": "object", "properties": props, "required": list(props), "additionalProperties": False}


def llm_instructions(questions: list[Question]) -> str:
    lines = ["You review marketplace listings. Answer every question about the listing below. "
             "Return only JSON that matches the schema."]
    for q in questions:
        lines.append(f"\n- {q.name}: {q.instructions}")
        if isinstance(q, YesNo):
            lines.append("  Answer true or false.")
        elif isinstance(q, Choice):
            lines += [f"  * {o.value}: {o.description}" for o in q.options]
        else:
            lines += [f"  {i} = {o.value}: {o.description}" for i, o in enumerate(q.levels)]
    return "\n".join(lines)


def ask_llm(ev: Evidence, questions: list[Question]) -> GateCall:
    """Generative baseline: the same questions as one JSON answer. No probabilities come back,
    so `probability` is left empty — that difference is the point of Challenge 3."""
    ask, skipped = not_asked(questions, ev)

    def attempt() -> GateCall:
        def call() -> GateCall:
            resp = openai_client().responses.create(
                model=config.LUNA_DEPLOYMENT,
                instructions=llm_instructions(ask),
                input=openai_input(ev),
                text={"format": {"type": "json_schema", "name": "gate_answers",
                                 "schema": llm_schema(ask), "strict": True}},
            )
            try:
                data = json.loads(resp.output_text)
            except json.JSONDecodeError:
                return GateCall(model="llm", answers={}, error=f"not JSON: {resp.output_text[:200]}")
            answers: dict[str, Answer] = {}
            for q in ask:
                if q.name not in data:
                    continue
                v = data[q.name]
                if isinstance(q, YesNo):
                    answers[q.name] = Answer(name=q.name, kind=q.kind, value=bool(v))
                elif isinstance(q, Choice):
                    answers[q.name] = Answer(name=q.name, kind=q.kind, value=str(v))
                else:
                    answers[q.name] = Answer(name=q.name, kind=q.kind, value=int(v))
            u = resp.usage
            return GateCall(model="llm", answers=missing(ask, answers) | skipped,
                            input_tokens=u.input_tokens if u else 0, output_tokens=u.output_tokens if u else 0)
        return _openai_attempt("llm", call)

    call = with_retries("llm", attempt,
                        estimate_tokens([openai_input(ev), llm_instructions(ask), llm_schema(ask)]))
    if call.error and not call.answers:
        call.answers = {q.name: Answer(name=q.name, kind=q.kind, status="error", detail=call.error) for q in ask} | skipped
    return call


ASKERS: dict[str, Callable[[Evidence, list[Question]], GateCall]] = {
    "decision": ask_decision,
    "luna": ask_luna,
    "llm": ask_llm,
}


def ask(mode: str, ev: Evidence, questions: list[Question]) -> GateCall:
    if mode not in ASKERS:
        raise ValueError(f"Unknown model mode {mode!r}. Use one of: {', '.join(MODES)}")
    return ASKERS[mode](ev, questions)


def request_preview(mode: str, ev: Evidence, questions: list[Question]) -> dict:
    """The exact request each mode sends, for the console's "Show me the code" panel.
    The photo's base64 is shortened so the JSON stays readable."""
    ask_qs, _ = not_asked(questions, ev)
    short = f"{ev.photo_b64[:40]}... ({len(ev.photo_b64):,} characters)" if ev.photo_b64 else None
    shown = Evidence(state=ev.state, photo_b64=short)
    if mode == "decision":
        return {"method": "POST", "url": f"{config.DECISION_ENDPOINT}/providers/microsoft/v1/systemone",
                "headers": {"Authorization": "Bearer <Entra ID token>"}, "body": systemone_body(shown, ask_qs)}
    url = f"{config.OPENAI_ENDPOINT}/openai/v1/" + ("decisions" if mode == "luna" else "responses")
    if mode == "luna":
        body = {"model": config.LUNA_DEPLOYMENT, "input": openai_input(shown),
                "questions": [decisions_question(q) for q in ask_qs]}
    else:
        body = {"model": config.LUNA_DEPLOYMENT, "instructions": llm_instructions(ask_qs), "input": openai_input(shown),
                "text": {"format": {"type": "json_schema", "name": "gate_answers",
                                    "schema": llm_schema(ask_qs), "strict": True}}}
    return {"method": "POST", "url": url, "headers": {"Authorization": "Bearer <Entra ID token>"}, "body": body}
