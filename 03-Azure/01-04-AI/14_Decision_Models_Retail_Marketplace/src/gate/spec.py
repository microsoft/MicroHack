"""Model-neutral question and answer types.

A decision model answers a fixed set of questions about one piece of evidence. There are
three kinds of question, and every provider supports them under different names:

| Here      | Microsoft-Decision-1.1 / Jev | Azure OpenAI Decisions (gpt-6-luna) |
|-----------|------------------------------|-------------------------------------|
| `YesNo`   | `noul`                       | `predicate`                         |
| `Choice`  | `choice` + `criteria{}`      | `choice` + `choices[]`              |
| `Score`   | `score` + `criteria[]`       | `score` + `levels[]`                |

You write questions once with these classes; `gate/clients.py` translates them for each API.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal, Union


@dataclass(frozen=True)
class Option:
    """One allowed answer: a stable `value` your code relies on, and a description the model reads."""

    value: str
    description: str


@dataclass(frozen=True)
class YesNo:
    """Is a condition true? The model returns the probability that the answer is yes."""

    name: str
    instructions: str
    requires_photo: bool = False
    kind: Literal["yes_no"] = field(default="yes_no", init=False)


@dataclass(frozen=True)
class Choice:
    """Pick exactly one option from an unordered set. Add a `cannot_tell` option when the
    evidence may not be enough — but remember the model can still pick a wrong option."""

    name: str
    instructions: str
    options: tuple[Option, ...]
    requires_photo: bool = False
    kind: Literal["choice"] = field(default="choice", init=False)


@dataclass(frozen=True)
class Score:
    """Rate against ORDERED levels (index 0 = lowest). A score is a position on your scale,
    not a measurement and not a probability."""

    name: str
    instructions: str
    levels: tuple[Option, ...]
    requires_photo: bool = False
    kind: Literal["score"] = field(default="score", init=False)


Question = Union[YesNo, Choice, Score]

Status = Literal["ok", "refused", "not_asked", "error"]


@dataclass
class Answer:
    """One answer, normalised across providers.

    * `probability` — for YesNo: P(yes). For Choice: P(chosen option). For Score: P(most
      likely level). This is what you threshold.
    * `value` — Choice: the chosen option value. Score: the most likely level index.
      YesNo: None (your thresholds decide yes / no / unsure — see `rules.py`).
    * `distribution` — every option's probability, exactly as the provider returned it.
    * `provider_confidence` — the provider's own `confidence` field, kept for comparison.
      Providers define it differently, so the gate does not threshold it.
    * `status` — anything other than "ok" means "no usable answer". Never treat it as "no".
    """

    name: str
    kind: str
    status: Status = "ok"
    probability: float | None = None
    value: str | int | bool | None = None
    distribution: dict[str, float] = field(default_factory=dict)
    expected_score: float | None = None
    provider_confidence: float | None = None
    detail: str | None = None

    def to_dict(self) -> dict:
        return {k: v for k, v in self.__dict__.items() if v not in (None, {}) or k in ("name", "status")}

    @classmethod
    def from_dict(cls, d: dict) -> "Answer":
        return cls(**{k: d.get(k) for k in cls.__dataclass_fields__ if k in d})


@dataclass
class GateCall:
    """Everything one request to a model produced, plus timings for the evaluation report."""

    model: str
    answers: dict[str, Answer]
    latency_ms: float | None = None  # time of the successful attempt only
    wait_ms: float = 0.0  # time spent waiting on 429s and retries
    attempts: int = 1
    input_tokens: int = 0
    output_tokens: int = 0
    error: str | None = None

    def to_dict(self) -> dict:
        d = {k: v for k, v in self.__dict__.items() if k != "answers"}
        d["answers"] = {k: a.to_dict() for k, a in self.answers.items()}
        return d

    @classmethod
    def from_dict(cls, d: dict) -> "GateCall":
        answers = {k: Answer.from_dict(a) for k, a in d.get("answers", {}).items()}
        return cls(**{**{k: d[k] for k in cls.__dataclass_fields__ if k in d and k != "answers"},
                      "answers": answers})


def spec_signature(questions: list[Question]) -> list[dict]:
    """A plain-data view of the questions, used in cache keys and run files."""
    out = []
    for q in questions:
        d = {"name": q.name, "kind": q.kind, "instructions": q.instructions, "requires_photo": q.requires_photo}
        if isinstance(q, Choice):
            d["options"] = [[o.value, o.description] for o in q.options]
        if isinstance(q, Score):
            d["levels"] = [[o.value, o.description] for o in q.levels]
        out.append(d)
    return out
