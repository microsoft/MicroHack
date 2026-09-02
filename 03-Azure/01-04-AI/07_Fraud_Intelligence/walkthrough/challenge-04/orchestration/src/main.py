# Copyright (c) Microsoft. All rights reserved.

import os

from agent_framework import AgentExecutor, WorkflowBuilder
from agent_framework.foundry import FoundryAgent
from agent_framework_foundry_hosting import ResponsesHostServer
from azure.ai.agentserver.core.tasks import set_resilient_tasks_enabled
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


def get_foundry_agent(
    *,
    project_endpoint: str,
    credential: DefaultAzureCredential,
    agent_name: str,
    agent_version: str,
) -> FoundryAgent:
    print(f"Getting Foundry agent: {agent_name} v{agent_version}")
    return FoundryAgent(
        project_endpoint=project_endpoint,
        agent_name=agent_name,
        agent_version=agent_version,
        credential=credential,
    )


def main():
    set_resilient_tasks_enabled(True)
    print("=== Fraud intelligence orchestration ===\n")

    project_endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
    credential = DefaultAzureCredential()

    evidence_enrichment_agent = get_foundry_agent(
        project_endpoint=project_endpoint,
        credential=credential,
        agent_name="evidenceenrichmentagent",
        agent_version="2",
    )

    regulatory_assessment_agent = get_foundry_agent(
        project_endpoint=project_endpoint,
        credential=credential,
        agent_name="RegulatoryAssessmentAgent",
        agent_version="3",
    )

    aml_report_agent = get_foundry_agent(
        project_endpoint=project_endpoint,
        credential=credential,
        agent_name="AMLReportAgent",
        agent_version="2",
    )

    # Set the context mode to `last_agent` so that each agent only sees the output of the
    # previous agent instead of the full conversation history
    evidence_enrichment_executor = AgentExecutor(evidence_enrichment_agent, context_mode="last_agent")
    regulatory_assessment_executor = AgentExecutor(regulatory_assessment_agent, context_mode="last_agent")
    aml_report_executor = AgentExecutor(aml_report_agent, context_mode="last_agent")

    workflow_agent = (
        WorkflowBuilder(
            start_executor=evidence_enrichment_executor,
            # Limiting the output to only the final formatted result.
            # If this is not set, all intermediate results will be included in the output.
            output_from=[aml_report_executor],
        )
        .add_edge(evidence_enrichment_executor, regulatory_assessment_executor)
        .add_edge(regulatory_assessment_executor, aml_report_executor)
        .build()
        .as_agent()
    )

    server = ResponsesHostServer(workflow_agent)
    server.run()


if __name__ == "__main__":
    main()
