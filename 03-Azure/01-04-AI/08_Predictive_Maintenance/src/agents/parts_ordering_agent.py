#!/usr/bin/env python3
"""Parts Ordering Agent - Automated parts ordering using Microsoft Agent Framework.

Usage:
    python agents/parts_ordering_agent.py [WORK_ORDER_ID]

Example:
    python agents/parts_ordering_agent.py wo-2024-468
"""

import asyncio
import json
import logging
import os
import sys
import uuid
from datetime import datetime, timedelta
from typing import List

from agent_framework import Agent
from agent_framework.foundry import FoundryChatClient
from agent_framework.observability import create_resource, enable_instrumentation, get_tracer, configure_otel_providers
from azure.monitor.opentelemetry import configure_azure_monitor
from azure.ai.projects.aio import AIProjectClient
from azure.identity.aio import AzureCliCredential
from dotenv import load_dotenv
from opentelemetry.trace import SpanKind
from services.cosmos_db_service import (
    CosmosDbService,
    InventoryItem,
    OrderItem,
    PartsOrder,
    Supplier,
    WorkOrder,
)

logger = logging.getLogger(__name__)
load_dotenv(override=True)


# =============================================================================
# Agent Service
# =============================================================================


class PartsOrderingAgent:
    """AI Agent for parts ordering"""

    def __init__(self, project_endpoint: str, deployment_name: str, cosmos_service: CosmosDbService):
        self.project_endpoint = project_endpoint
        self.deployment_name = deployment_name
        self.cosmos_service = cosmos_service

    @get_tracer().start_as_current_span("generate_order")
    async def generate_order(
        self,
        work_order: WorkOrder,
        inventory: List[InventoryItem],
        suppliers: List[Supplier],
    ) -> PartsOrder:
        """Generate optimized parts order using AI"""

        context = self._build_context(work_order, inventory, suppliers)
        chat_history_json = await self.cosmos_service.get_work_order_chat_history(work_order.id)
        print(
            f"   Using persistent chat history for work order: {work_order.id}")

        instructions = """You are a parts ordering specialist for industrial tire manufacturing equipment.

Analyze inventory status and optimize parts ordering from suppliers considering:
1. Current inventory levels vs reorder points
2. Supplier reliability, lead time, and cost
3. Previous order history
4. Order urgency based on work order priority

Always respond in valid JSON format as requested."""

        # Build context with chat history if available
        full_context = context
        if chat_history_json:
            try:
                history_messages = json.loads(chat_history_json)
                history_text = "\n".join(
                    f"{msg['role']}: {msg['content']}" for msg in history_messages
                )
                full_context = f"Previous conversation:\n{history_text}\n\n{context}"
            except Exception as e:
                print(f"   Warning: Could not restore chat history: {e}")

        agent = Agent(
            client=FoundryChatClient(credential=AzureCliCredential(),
                                     project_endpoint=self.project_endpoint,
                                     model=self.deployment_name),
            name="PartsOrderingAgent",
            description="Parts ordering agent for industrial tire manufacturing equipment",
            instructions=instructions,
            id="PartsOrderingAgent"
        )

        print(f"   ✅ Using agent: {agent.id}")

        result = await agent.run(full_context)
        response_text = result.text

        await self._save_interaction_history(work_order.id, full_context, response_text)

        json_response = self._extract_json(response_text)
        data = json.loads(json_response)

        order_items = [
            OrderItem(
                part_number=item["partNumber"],
                part_name=item["partName"],
                quantity=item["quantity"],
                unit_cost=item.get("unitCost") or 0.0,
                total_cost=item.get("totalCost") or (
                    item["quantity"] * (item.get("unitCost") or 0.0)),
            )
            for item in data["orderItems"]
        ]
        # Fall back to summing item costs if the model omitted/nulled the order total
        total_cost = data.get("totalCost")
        if total_cost is None:
            total_cost = sum(item.total_cost for item in order_items)

        expected_delivery_raw = data.get("expectedDeliveryDate")
        if expected_delivery_raw:
            expected_delivery_date = datetime.fromisoformat(
                expected_delivery_raw.replace("Z", "+00:00"))
        else:
            # Model omitted the date; derive it from the chosen supplier's lead time
            supplier = next(
                (s for s in suppliers if s.id == data.get("supplierId")), None)
            lead_time_days = supplier.lead_time_days if supplier else 7
            expected_delivery_date = datetime.utcnow() + timedelta(days=lead_time_days)

        return PartsOrder(
            id=f"PO-{str(uuid.uuid4())[:8]}",
            work_order_id=work_order.id,
            order_items=order_items,
            supplier_id=data["supplierId"],
            supplier_name=data["supplierName"],
            total_cost=total_cost,
            expected_delivery_date=expected_delivery_date,
            order_status="Pending",
            created_at=datetime.utcnow(),
        )

    async def _save_interaction_history(self, work_order_id: str, user_context: str, assistant_response: str):
        """Save interaction history to Cosmos DB"""

        try:
            messages = [
                {"role": "user", "content": user_context},
                {"role": "assistant", "content": assistant_response},
            ]
            await self.cosmos_service.save_work_order_chat_history(work_order_id, json.dumps(messages))
        except Exception as e:
            print(f"   Warning: Could not save chat history: {e}")

    def _build_context(
        self,
        work_order: WorkOrder,
        inventory: List[InventoryItem],
        suppliers: List[Supplier],
    ) -> str:
        """Build analysis context for AI"""

        lines = [
            "# Parts Ordering Analysis Request",
            "",
            f"Today's date: {datetime.utcnow().strftime('%Y-%m-%d')}",
            "",
            "## Work Order Information",
            f"- Work Order ID: {work_order.id}",
            f"- Machine ID: {work_order.machine_id}",
            f"- Fault Type: {work_order.fault_type}",
            f"- Priority: {work_order.priority}",
            "",
            "## Required Parts",
        ]

        for part in work_order.required_parts:
            lines.append(f"- **{part.part_name}** (Part#: {part.part_number})")
            lines.append(f"  * Quantity needed: {part.quantity}")
            lines.append(
                f"  * Available in stock: {'YES' if part.is_available else 'NO'}")

        lines.extend(["", "## Current Inventory Status"])

        if inventory:
            for item in inventory:
                needs_order = item.current_stock <= item.reorder_point
                lines.append(
                    f"- **{item.part_name}** (Part#: {item.part_number})")
                lines.append(f"  * Current Stock: {item.current_stock}")
                lines.append(f"  * Minimum Stock: {item.min_stock}")
                lines.append(f"  * Reorder Point: {item.reorder_point}")
                lines.append(f"  * Unit Cost: ${item.unit_cost:.2f}")
                lines.append(
                    f"  * Status: {'⚠️  NEEDS ORDERING' if needs_order else '✓ Adequate'}")
                lines.append(f"  * Location: {item.location}")
        else:
            lines.append("⚠️  No inventory records found for required parts.")

        lines.extend(["", "## Available Suppliers"])

        if suppliers:
            for supplier in suppliers:
                lines.append(f"- **{supplier.name}** (ID: {supplier.id})")
                lines.append(f"  * Lead Time: {supplier.lead_time_days} days")
                lines.append(f"  * Reliability: {supplier.reliability}")
                lines.append(f"  * Contact: {supplier.contact_email}")
                parts_preview = ", ".join(supplier.parts[:5])
                if len(supplier.parts) > 5:
                    parts_preview += "..."
                lines.append(f"  * Parts Available: {parts_preview}")
        else:
            lines.append("⚠️  No suppliers found for required parts!")

        lines.extend(
            [
                "",
                "## Analysis Required",
                "Please provide a JSON response with:",
                "1. Parts to order",
                "2. Optimal supplier selection (reliability > lead time > cost)",
                "3. Expected delivery date",
                "4. Total order cost",
                "",
                "Use the exact 'Unit Cost' values listed above under 'Current Inventory Status' "
                "for unitCost/totalCost. Do not invent or estimate costs.",
                "",
                "```json",
                "{",
                '  "supplierId": "<supplier ID>",',
                '  "supplierName": "<supplier name>",',
                '  "orderItems": [',
                "    {",
                '      "partNumber": "<part number>",',
                '      "partName": "<part name>",',
                '      "quantity": <number>,',
                '      "unitCost": <decimal>,',
                '      "totalCost": <decimal>',
                "    }",
                "  ],",
                '  "totalCost": <decimal>,',
                '  "expectedDeliveryDate": "<ISO datetime>",',
                '  "reasoning": "<explanation>"',
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

    print("=== Parts Ordering Agent ===\n")

    cosmos_endpoint = os.getenv("COSMOS_ENDPOINT")
    cosmos_key = os.getenv("COSMOS_KEY")
    database_name = os.getenv("COSMOS_DATABASE_NAME")
    foundry_project_endpoint = os.getenv("AI_FOUNDRY_PROJECT_ENDPOINT")
    deployment_name = os.getenv("MODEL_DEPLOYMENT_NAME", "gpt-5.4")
    otel_exporter_endpoint = os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT")

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
                async for _ in project_client.agents.list_versions(agent_name="PartsOrderingAgent"):
                    version_count += 1
                print(f"   Found {version_count} existing versions")
            except Exception as e:
                print(f"   Error checking versions: {e}")

            print(
                f"   Creating new version (will be version #{version_count + 1})...")

            definition = PromptAgentDefinition(
                model=deployment_name,
                instructions="""You are a Parts Ordering Specialist for industrial tire manufacturing equipment.

Analyze inventory levels and optimize parts ordering from suppliers considering:
1. Current inventory levels vs reorder points
2. Supplier reliability, lead time, and cost
3. Previous order history
4. Order urgency based on work order priority

When generating orders:
- Prioritize suppliers with high reliability
- Balance lead time against urgency
- Consider total cost optimization
- Reference inventory data to determine quantities

Always respond in valid JSON format with: supplierId, supplierName, orderItems (partNumber, partName, quantity, unitCost, totalCost), totalCost, expectedDeliveryDate, and reasoning.""",
            )

            print("   Registering PartsOrderingAgent in Azure AI Foundry portal...")
            registered_agent = await project_client.agents.create_version(
                agent_name="PartsOrderingAgent",
                definition=definition,
                description="Parts ordering automation agent",
                metadata={
                    "framework": "agent-framework",
                    "purpose": "parts_ordering",
                    "timestamp": datetime.utcnow().isoformat(),
                },
            )
            print("   ✅ New version created!")
            print(
                f"      Agent ID: {registered_agent.id if hasattr(registered_agent, 'id') else 'N/A'}")

            print("   Verifying creation...")
            verify_count = 0
            async for _ in project_client.agents.list_versions(agent_name="PartsOrderingAgent"):
                verify_count += 1
            print(f"   Total versions now in portal: {verify_count}")
            print("   Check portal at: https://ai.azure.com\n")
        except Exception as e:
            print(f"   ⚠️  Could not register agent in portal: {e}\n")
            import traceback

            print(f"   Error details: {traceback.format_exc()}")
            logger.warning(f"Could not register agent in portal: {e}")

    agent_service = PartsOrderingAgent(
        foundry_project_endpoint, deployment_name, cosmos_service)

    with get_tracer().start_as_current_span("Scenario: Parts Ordering Agent", kind=SpanKind.CLIENT) as current_span:

        print("1. Retrieving work order...")
        work_order_id = sys.argv[1] if len(sys.argv) > 1 else "2024-468"

        try:
            work_order = await cosmos_service.get_work_order(work_order_id)
            print(f"   ✓ Work Order: {work_order.id}")
            print(f"   Machine: {work_order.machine_id}")
            print(f"   Required Parts: {len(work_order.required_parts)}")
            print(f"   Priority: {work_order.priority}\n")
        except Exception as e:
            print(f"   ✗ Error: {str(e)}")
            return

        print("2. Checking inventory status...")
        part_numbers = [p.part_number for p in work_order.required_parts]
        inventory = await cosmos_service.get_inventory_items(part_numbers)
        print(f"   ✓ Found {len(inventory)} inventory records\n")

        parts_needing_order = [
            p for p in work_order.required_parts if not p.is_available]

        if not parts_needing_order:
            print("✓ All required parts are available in stock!")
            print("No parts order needed.\n")

            print("3. Updating work order status...")
            await cosmos_service.update_work_order_status(work_order.id, "Ready")
            print("   ✓ Work order status updated to 'Ready'\n")

            print("✓ Parts Ordering Agent completed successfully!")
            return

        print(f"⚠️  {len(parts_needing_order)} part(s) need to be ordered:")
        for part in parts_needing_order:
            print(f"   - {part.part_name} (Qty: {part.quantity})")
        print()

        print("3. Finding suppliers...")
        needed_part_numbers = [p.part_number for p in parts_needing_order]
        suppliers = await cosmos_service.get_suppliers_for_parts(needed_part_numbers)
        print(f"   ✓ Found {len(suppliers)} potential suppliers\n")

        if not suppliers:
            print("✗ No suppliers found for required parts!")
            return

        print("4. Running AI parts ordering analysis...")
        try:
            order = await agent_service.generate_order(work_order, inventory, suppliers)
            print("   ✓ Parts order generated!\n")

            print("=== Parts Order ===")
            print(f"Order ID: {order.id}")
            print(f"Work Order: {order.work_order_id}")
            print(f"Supplier: {order.supplier_name} (ID: {order.supplier_id})")
            print(
                f"Expected Delivery: {order.expected_delivery_date.strftime('%Y-%m-%d')}")
            print(f"Total Cost: ${order.total_cost:.2f}")
            print(f"Status: {order.order_status}")
            print("\nOrder Items:")
            for item in order.order_items:
                print(f"  - {item.part_name} (#{item.part_number})")
                print(
                    f"    Qty: {item.quantity} @ ${item.unit_cost:.2f} = ${item.total_cost:.2f}")
            print()

            print("5. Saving parts order...")
            await cosmos_service.save_parts_order(order)
            print("   ✓ Order saved to SCM system\n")

            print("6. Updating work order status...")
            await cosmos_service.update_work_order_status(work_order.id, "PartsOrdered")
            print("   ✓ Work order status updated to 'PartsOrdered'\n")

            print("✓ Parts Ordering Agent completed successfully!")
        except Exception as e:
            print(f"   ✗ Error during parts ordering: {str(e)}")
            import traceback

            print(f"\nStack trace:\n{traceback.format_exc()}")


if __name__ == "__main__":
    asyncio.run(main())
