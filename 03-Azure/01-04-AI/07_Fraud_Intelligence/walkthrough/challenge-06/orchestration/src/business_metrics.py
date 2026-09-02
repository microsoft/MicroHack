import json
import logging
from collections.abc import Callable
from typing import Any

from agent_framework import AgentExecutorResponse, WorkflowContext, executor
from agent_framework.observability import get_meter

logger = logging.getLogger(__name__)
meter = get_meter("fraud_intelligence.business")

transaction_amount = meter.create_histogram(
    "fraud.transaction.amount",
    unit="{currency}",
    description="Transaction amount in its original currency",
)
transactions_processed = meter.create_counter(
    "fraud.transactions.processed",
    unit="{transaction}",
)
historical_context_level = meter.create_histogram(
    "fraud.aml.historical_context_level",
    unit="1",
)
evidence_count = meter.create_histogram(
    "fraud.aml.evidence_count",
    unit="{record}",
)
typology_detected = meter.create_counter(
    "fraud.aml.typology_detected",
    unit="{detection}",
)
rules_evaluated = meter.create_counter(
    "fraud.regulatory.rules_evaluated",
    unit="{rule}",
)
missing_data_count = meter.create_histogram(
    "fraud.regulatory.missing_data_count",
    unit="{field}",
)
priority_score = meter.create_histogram(
    "fraud.investigation.priority_score",
    unit="1",
)
workflow_classifications = meter.create_counter(
    "fraud.workflow.classifications",
    unit="{transaction}",
)
review_required = meter.create_counter(
    "fraud.workflow.review_required",
    unit="{transaction}",
)
alert_status = meter.create_counter(
    "fraud.alert.status",
    unit="{alert}",
)
metric_extraction_failures = meter.create_counter(
    "fraud.metrics.extraction_failures",
    unit="{failure}",
)


def parse_agent_json(text: str) -> dict[str, Any]:
    content = text.strip()
    if content.startswith("```"):
        lines = content.splitlines()[1:]
        if lines and lines[-1].strip() == "```":
            lines.pop()
        content = "\n".join(lines)
    return json.loads(content)


def record_evidence_metrics(payload: dict[str, Any]) -> None:
    transaction = payload["original_transaction"]
    data_response = payload["data_agent_response"]
    features = payload["derived_features"]
    origin = data_response["origin_account"]
    destination = data_response["destination_account"]

    attributes = {
        "currency": transaction["currency"],
        "cross_border": origin.get("country") != destination.get("country"),
        "history_detected": features["origin_has_history"] or features["destination_has_history"],
    }
    transaction_amount.record(transaction["amount"], attributes)
    transactions_processed.add(1, attributes)

    for account_role, account in (("origin", origin), ("destination", destination)):
        enrichment = payload[f"{account_role}_account_enrichment"]
        historical_context_level.record(
            enrichment["historical_context_level"],
            {"account_role": account_role},
        )
        evidence_count.record(len(account.get("evidence", [])), {"account_role": account_role})

    pattern_types = set(origin.get("pattern_types", []) + destination.get("pattern_types", []))
    for pattern_type in pattern_types:
        typology_detected.add(1, {"pattern_type": pattern_type})


def record_regulatory_metrics(payload: dict[str, Any]) -> None:
    assessment = payload["aml_regulatory_assessment"]
    compliance = assessment["overall_compliance"]
    decision_support = assessment["decision_support"]
    priority = decision_support["investigation_priority"]
    classification = decision_support["workflow_classification"]

    for rule in assessment["rule_evaluations"]:
        rules_evaluated.add(
            1,
            {
                "status": rule["compliance_status"],
                "scope": rule["scope"],
            },
        )

    missing_data_count.record(
        len(assessment.get("missing_data", [])),
        {"overall_status": compliance["overall_status"]},
    )
    priority_score.record(priority["score"], {"priority_band": priority["priority_band"]})
    workflow_classifications.add(
        1,
        {
            "verdict": classification["final_verdict"],
            "priority_band": priority["priority_band"],
            "overall_status": compliance["overall_status"],
        },
    )
    review_required.add(
        1,
        {"required": assessment["downstream_inputs"]["requires_case_recommendation_review"]},
    )


def record_alert_metrics(payload: dict[str, Any]) -> None:
    result = payload["alert_manager_result"]
    alert_status.add(
        1,
        {
            "status": result["status"],
            "threshold_status": result["threshold_status"],
            "mcp_invoked": result["mcp_invoked"],
        },
    )


async def observe_metrics(
    response: AgentExecutorResponse,
    ctx: WorkflowContext[AgentExecutorResponse, None],
    *,
    stage: str,
    recorder: Callable[[dict[str, Any]], None],
) -> None:
    try:
        recorder(parse_agent_json(response.agent_response.text))
    except Exception:
        logger.exception("Could not extract business metrics from %s response", stage)
        metric_extraction_failures.add(1, {"stage": stage})
    finally:
        await ctx.send_message(response)


@executor(id="evidence_metrics", input=AgentExecutorResponse, output=AgentExecutorResponse)
async def evidence_metrics_executor(
    response: AgentExecutorResponse,
    ctx: WorkflowContext[AgentExecutorResponse, None],
) -> None:
    await observe_metrics(response, ctx, stage="evidence_enrichment", recorder=record_evidence_metrics)


@executor(id="regulatory_metrics", input=AgentExecutorResponse, output=AgentExecutorResponse)
async def regulatory_metrics_executor(
    response: AgentExecutorResponse,
    ctx: WorkflowContext[AgentExecutorResponse, None],
) -> None:
    await observe_metrics(response, ctx, stage="regulatory_assessment", recorder=record_regulatory_metrics)


@executor(id="alert_metrics", input=AgentExecutorResponse)
async def alert_metrics_executor(
    response: AgentExecutorResponse,
    ctx: WorkflowContext[None, None],
) -> None:
    try:
        record_alert_metrics(parse_agent_json(response.agent_response.text))
    except Exception:
        logger.exception("Could not extract business metrics from alert_manager response")
        metric_extraction_failures.add(1, {"stage": "alert_manager"})
