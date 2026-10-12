#!/usr/bin/env python3
"""Maintenance Scheduler Agent - Predictive maintenance scheduling using Microsoft Agent Framework.

Usage:
    python agents/maintenance_scheduler_agent.py [WORK_ORDER_ID]

Example:
    python agents/maintenance_scheduler_agent.py wo-2024-468
"""

import asyncio
import json
import logging
import os
import sys
from datetime import datetime
from typing import List

from agent_framework import Agent
from agent_framework.foundry import FoundryChatClient, FoundryAgent
from agent_framework.observability import create_resource, enable_instrumentation, get_tracer, configure_otel_providers
from azure.monitor.opentelemetry import configure_azure_monitor
from azure.ai.projects.aio import AIProjectClient
from azure.identity.aio import AzureCliCredential
from opentelemetry.trace import SpanKind
from dotenv import load_dotenv
from services.cosmos_db_service import (
    CosmosDbService,
    MaintenanceHistory,
    MaintenanceSchedule,
    MaintenanceWindow,
    WorkOrder,
)

logger = logging.getLogger(__name__)
load_dotenv(override=True)

# =============================================================================
# Agent Service
# =============================================================================


class MaintenanceSchedulerAgent:
    """AI Agent for predictive maintenance scheduling"""

    def __init__(self, project_endpoint: str, deployment_name: str, cosmos_service: CosmosDbService):
        self.project_endpoint = project_endpoint
        self.deployment_name = deployment_name
        self.cosmos_service = cosmos_service

    @get_tracer().start_as_current_span("predict_schedule")
    async def predict_schedule(
        self,
        work_order: WorkOrder,
        history: List[MaintenanceHistory],
        windows: List[MaintenanceWindow],
    ) -> MaintenanceSchedule:
        """Predict optimal maintenance schedule using AI"""

        context = self._build_context(work_order, history, windows)
        chat_history_json = await self.cosmos_service.get_machine_chat_history(work_order.machine_id)
        print(
            f"   Using persistent chat history for machine: {work_order.machine_id}")

        instructions = """You are a predictive maintenance expert specializing in industrial tire manufacturing equipment.

Analyze historical maintenance data and recommend optimal maintenance schedules based on:
1. Historical failure patterns
2. Risk scores (time since last maintenance, fault frequency, downtime costs, criticality)
3. Optimal maintenance windows considering production impact
4. Detailed reasoning

Always respond in valid JSON format as requested."""

        # Build full prompt including any chat history context
        full_prompt = context
        if chat_history_json:
            try:
                history_msgs = json.loads(chat_history_json)
                history_context = "\n".join(
                    [f"{msg['role']}: {msg['content']}" for msg in history_msgs[-5:]]
                )
                full_prompt = f"Previous conversation context:\n{history_context}\n\n{context}"
            except Exception as e:
                print(f"   Warning: Could not restore chat history: {e}")

        agent = Agent(
            client=FoundryChatClient(credential=AzureCliCredential(),
                                     project_endpoint=self.project_endpoint,
                                     model=self.deployment_name),
            name="MaintenanceSchedulerAgent",
            description="Predictive maintenance scheduling agent for tire manufacturing",
            instructions=instructions,
            id="MaintenanceSchedulerAgent"
        )

        # Use the Foundry PromptAgent
        # agent = FoundryAgent(
        #     project_endpoint=self.project_endpoint,
        #     name="MaintenanceSchedulerAgent",
        #     agent_name="MaintenanceSchedulerAgent",
        #     credential=AzureCliCredential(),
        #     default_options={
        #         "model": "gpt-5.4",
        #         "extra_body": {"model": "gpt-5.4"},
        #     }
        # )

        print(f"   ✅ Using agent: {agent.id}")

        result = await agent.run(full_prompt)
        response_text = result.text

        # Save interaction to chat history
        await self._save_interaction_history(work_order.machine_id, context, response_text)

        json_response = self._extract_json(response_text)
        data = json.loads(json_response)

        return MaintenanceSchedule(
            id=f"sched-{datetime.utcnow().timestamp()}",
            work_order_id=work_order.id,
            machine_id=work_order.machine_id,
            scheduled_date=datetime.fromisoformat(
                data["scheduledDate"].replace("Z", "+00:00")),
            maintenance_window=MaintenanceWindow(
                id=data["maintenanceWindow"]["id"],
                start_time=datetime.fromisoformat(
                    data["maintenanceWindow"]["startTime"].replace("Z", "+00:00")),
                end_time=datetime.fromisoformat(
                    data["maintenanceWindow"]["endTime"].replace("Z", "+00:00")),
                production_impact=data["maintenanceWindow"]["productionImpact"],
                is_available=data["maintenanceWindow"]["isAvailable"],
            ),
            risk_score=data["riskScore"],
            predicted_failure_probability=data["predictedFailureProbability"],
            recommended_action=data["recommendedAction"],
            reasoning=data["reasoning"],
            created_at=datetime.utcnow(),
        )

    async def _save_interaction_history(self, machine_id: str, user_prompt: str, assistant_response: str):
        """Save interaction to Cosmos DB chat history"""

        try:
            # Get existing history
            existing_json = await self.cosmos_service.get_machine_chat_history(machine_id)
            messages = json.loads(existing_json) if existing_json else []

            # Append new interaction
            messages.append({"role": "user", "content": user_prompt})
            messages.append(
                {"role": "assistant", "content": assistant_response})

            # Keep only last 10 messages
            messages = messages[-10:]

            await self.cosmos_service.save_machine_chat_history(machine_id, json.dumps(messages))
        except Exception as e:
            print(f"   Warning: Could not save chat history: {e}")

    def _build_context(self, work_order: WorkOrder, history: List[MaintenanceHistory], windows: List[MaintenanceWindow]) -> str:
        """Build analysis context for AI"""

        lines = [
            "# Predictive Maintenance Analysis Request",
            "",
            "## Work Order Information",
            f"- Work Order ID: {work_order.id}",
            f"- Machine ID: {work_order.machine_id}",
            f"- Fault Type: {work_order.fault_type}",
            f"- Priority: {work_order.priority}",
            f"- Estimated Duration: {work_order.estimated_duration} minutes",
            "",
            "## Historical Maintenance Data",
        ]

        if history:
            lines.append(f"Total maintenance events: {len(history)}")
            lines.append("")

            relevant_history = [
                h for h in history if h.fault_type == work_order.fault_type]
            if relevant_history:
                lines.append(
                    f"**Similar fault type ({work_order.fault_type}):**")
                lines.append(f"- Occurrences: {len(relevant_history)}")
                avg_downtime = sum(
                    h.downtime for h in relevant_history) / len(relevant_history)
                avg_cost = sum(h.cost for h in relevant_history) / \
                    len(relevant_history)
                lines.append(f"- Average downtime: {avg_downtime:.0f} minutes")
                lines.append(f"- Average cost: ${avg_cost:.2f}")

                if len(relevant_history) >= 2:
                    dates = sorted(
                        [h.occurrence_date for h in relevant_history if h.occurrence_date])
                    if len(dates) >= 2:
                        intervals = [
                            (dates[i] - dates[i - 1]).days for i in range(1, len(dates))]
                        avg_interval = sum(intervals) / len(intervals)
                        lines.append(
                            f"- Mean Time Between Failures (MTBF): {avg_interval:.0f} days")

                        last_occurrence = max(
                            h.occurrence_date for h in relevant_history if h.occurrence_date)
                        days_since_last = (
                            datetime.utcnow() - last_occurrence).days
                        lines.append(
                            f"- Days since last occurrence: {days_since_last:.0f}")
                        lines.append(
                            f"- Failure cycle progress: {(days_since_last / avg_interval * 100):.1f}%")
            else:
                lines.append(
                    f"**No previous occurrences of {work_order.fault_type} fault type.**")

            lines.append("")
            lines.append("**Recent maintenance events (all types):**")
            for record in history[:5]:
                if record.occurrence_date:
                    lines.append(
                        f"- {record.occurrence_date.strftime('%Y-%m-%d')}: {record.fault_type} ({record.downtime}min, ${record.cost})"
                    )
        else:
            lines.append("⚠️  No historical maintenance data available.")
            lines.append(
                "Risk assessment will be based on fault type and priority only.")

        lines.extend(["", "## Available Maintenance Windows (Next 14 Days)"])

        if windows:
            for window in windows[:10]:
                if window.start_time and window.end_time:
                    duration = (window.end_time -
                                window.start_time).total_seconds() / 3600
                    lines.append(
                        f"- **{window.start_time.strftime('%Y-%m-%d %H:%M')} to {window.end_time.strftime('%H:%M')}** ({duration:.1f}h)"
                    )
                    lines.append(
                        f"  * Production Impact: {window.production_impact}")
                    lines.append(f"  * Window ID: {window.id}")
        else:
            lines.append("⚠️  No maintenance windows available!")

        lines.extend(
            [
                "",
                "## Analysis Required",
                "Please provide a JSON response with:",
                "1. Risk score (0-100): Priority base + MTBF progress + historical impact",
                "2. Failure probability (0.0-1.0)",
                "3. Optimal maintenance window selection",
                "4. Recommended action: IMMEDIATE, URGENT, or SCHEDULED",
                "5. Detailed reasoning",
                "",
                "```json",
                "{",
                '  "scheduledDate": "<ISO datetime>",',
                '  "maintenanceWindow": {',
                '    "id": "<window ID>",',
                '    "startTime": "<ISO datetime>",',
                '    "endTime": "<ISO datetime>",',
                '    "productionImpact": "<Low|Medium|High>",',
                '    "isAvailable": true',
                "  },",
                '  "riskScore": <0-100>,',
                '  "predictedFailureProbability": <0.0-1.0>,',
                '  "recommendedAction": "<IMMEDIATE|URGENT|SCHEDULED>",',
                '  "reasoning": "<detailed explanation>"',
                "}",
                "```",
            ]
        )

        return "\n".join(lines)

    def _extract_json(self, response: str) -> str:
        """Extract JSON from response"""

        if "```json" in response:
            start = response.index("```json") + 7
            end = response.index("```", start)
            return response[start:end].strip()

        start = response.find("{")
        if start >= 0:
            end = response.rfind("}")
            return response[start: end + 1]

        raise Exception("Could not extract JSON from agent response")


# =============================================================================
# Main Program
# =============================================================================


async def main():
    """Main program"""

    print("=== Predictive Maintenance Agent ===\n")

    # Load configuration (use AI_FOUNDRY_PROJECT_ENDPOINT for consistency with other challenge scripts)
    cosmos_endpoint = os.getenv("COSMOS_ENDPOINT")
    cosmos_key = os.getenv("COSMOS_KEY")
    database_name = os.getenv("COSMOS_DATABASE_NAME")
    foundry_project_endpoint = os.getenv("AI_FOUNDRY_PROJECT_ENDPOINT")
    deployment_name = os.getenv("MODEL_DEPLOYMENT_NAME", "gpt-5.4")
    otel_exporter_endpoint = os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT")

    # Validate
    if not all([cosmos_endpoint, cosmos_key, database_name, foundry_project_endpoint]):
        print("Error: Missing required environment variables.")
        print("Required: COSMOS_ENDPOINT, COSMOS_KEY, COSMOS_DATABASE_NAME, AI_FOUNDRY_PROJECT_ENDPOINT")
        return

    if otel_exporter_endpoint:
        configure_otel_providers()
    else:
        configure_azure_monitor(
            connection_string=os.getenv(
                "APPLICATIONINSIGHTS_CONNECTION_STRING"),
            resource=create_resource(),  # Uses OTEL_SERVICE_NAME, etc.
        )
        enable_instrumentation(enable_sensitive_data=True)

    cosmos_service = CosmosDbService(
        cosmos_endpoint, cosmos_key, database_name)

    # Register agent in Azure AI Foundry portal
    async with (
        AzureCliCredential() as credential,
        AIProjectClient(endpoint=foundry_project_endpoint, credential=credential) as project_client,
    ):
        try:
            from azure.ai.projects.models import PromptAgentDefinition

            print("   Checking existing agent versions in portal...")
            version_count = 0
            try:
                async for _ in project_client.agents.list_versions(agent_name="MaintenanceSchedulerAgent"):
                    version_count += 1
                print(f"   Found {version_count} existing versions")
            except Exception as e:
                print(f"   Error checking versions: {e}")

            print(
                f"   Creating new version (will be version #{version_count + 1})...")

            definition = PromptAgentDefinition(
                model=deployment_name,
                instructions="""You are a Predictive Maintenance Scheduler for industrial tire manufacturing equipment.

Analyze work orders, historical maintenance data, and available maintenance windows to:
1. Assess equipment failure risk based on historical patterns and work order priority
2. Identify optimal maintenance windows that minimize production disruption
3. Generate predictive maintenance schedules with risk scores and recommendations

Consider factors like:
- Work order priority (high/medium/low)
- Historical maintenance frequency and patterns
- Production impact of maintenance windows
- Equipment estimated repair duration

Output JSON with: scheduled_date, risk_score (0-100), predicted_failure_probability (0-1), recommended_action (IMMEDIATE/URGENT/SCHEDULED/MONITOR), and reasoning.""",
            )

            print(
                "   Registering MaintenanceSchedulerAgent in Azure AI Foundry portal...")
            registered_agent = await project_client.agents.create_version(
                agent_name="MaintenanceSchedulerAgent",
                definition=definition,
                description="Predictive maintenance scheduling agent",
                metadata={
                    "framework": "agent-framework",
                    "purpose": "maintenance_scheduling",
                    "timestamp": datetime.utcnow().isoformat(),
                },
            )
            print("   ✅ New version created!")
            print(
                f"      Agent ID: {registered_agent.id if hasattr(registered_agent, 'id') else 'N/A'}")

            print("   Verifying creation...")
            verify_count = 0
            async for _ in project_client.agents.list_versions(agent_name="MaintenanceSchedulerAgent"):
                verify_count += 1
            print(f"   Total versions now in portal: {verify_count}")
            print("   Check portal at: https://ai.azure.com\n")
        except Exception as e:
            print(f"   ⚠️  Could not register agent in portal: {e}\n")
            logger.warning(f"Could not register agent in portal: {e}")

    with get_tracer().start_as_current_span("Scenario: Predictive Maintenance Agent", kind=SpanKind.CLIENT) as current_span:

        agent_service = MaintenanceSchedulerAgent(
            foundry_project_endpoint, deployment_name, cosmos_service)

        # Get work order
        print("1. Retrieving work order...")
        work_order_id = sys.argv[1] if len(sys.argv) > 1 else "wo-2024-468"

        try:
            work_order = await cosmos_service.get_work_order(work_order_id)
            print(f"   ✓ Work Order: {work_order.id}")
            print(f"   Machine: {work_order.machine_id}")
            print(f"   Fault: {work_order.fault_type}")
            print(f"   Priority: {work_order.priority}\n")
        except Exception as e:
            print(f"   ✗ Error: {str(e)}")
            return

        print("2. Analyzing historical maintenance data...")
        history = await cosmos_service.get_maintenance_history(work_order.machine_id)
        print(f"   ✓ Found {len(history)} historical maintenance records\n")

        print("3. Checking available maintenance windows...")
        windows = await cosmos_service.get_available_maintenance_windows(14)
        print(f"   ✓ Found {len(windows)} available windows in next 14 days\n")

        print("4. Running AI predictive analysis...")
        try:
            schedule = await agent_service.predict_schedule(work_order, history, windows)
            print("   ✓ Analysis complete!\n")

            print("=== Predictive Maintenance Schedule ===")
            print(f"Schedule ID: {schedule.id}")
            print(f"Machine: {schedule.machine_id}")
            print(
                f"Scheduled Date: {schedule.scheduled_date.strftime('%Y-%m-%d %H:%M')}")
            print(
                f"Window: {schedule.maintenance_window.start_time.strftime('%H:%M')} - {schedule.maintenance_window.end_time.strftime('%H:%M')}"
            )
            print(
                f"Production Impact: {schedule.maintenance_window.production_impact}")
            print(f"Risk Score: {schedule.risk_score}/100")
            print(
                f"Failure Probability: {schedule.predicted_failure_probability * 100:.1f}%")
            print(f"Recommended Action: {schedule.recommended_action}")
            print("\nReasoning:")
            print(f"{schedule.reasoning}")
            print()

            print("5. Saving maintenance schedule...")
            await cosmos_service.save_maintenance_schedule(schedule)
            print("   ✓ Schedule saved to Cosmos DB\n")

            print("6. Updating work order status...")
            await cosmos_service.update_work_order_status(work_order.id, "Scheduled")
            print("   ✓ Work order status updated to 'Scheduled'\n")

            print("✓ Predictive Maintenance Agent completed successfully!")
        except Exception as e:
            print(f"   ✗ Error during predictive analysis: {str(e)}")
            import traceback

            print(f"\nStack trace:\n{traceback.format_exc()}")


if __name__ == "__main__":
    asyncio.run(main())
