import asyncio
import os

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import MCPTool, PromptAgentDefinition
from azure.identity import DefaultAzureCredential
from dotenv import load_dotenv

load_dotenv(override=True)
project_endpoint = os.environ.get("AZURE_AI_PROJECT_ENDPOINT")
model_name = os.environ.get("MODEL_DEPLOYMENT_NAME")

# Configuration
knowledge_base_name = 'machine-kb'
search_endpoint = os.environ.get("SEARCH_SERVICE_ENDPOINT")
machine_wiki_mcp_endpoint = f"{search_endpoint}knowledgebases/{knowledge_base_name}/mcp?api-version=2025-11-01-preview"
machine_data_mcp_endpoint = os.environ.get("MACHINE_MCP_SERVER_ENDPOINT")
apim_subscription_key = os.environ.get("APIM_SUBSCRIPTION_KEY")


async def main():
    try:

        project_client = AIProjectClient(
            endpoint=project_endpoint, credential=DefaultAzureCredential())
        agent = project_client.agents.create_version(
            agent_name="FaultDiagnosisAgent",
            description="Fault diagnosis agent",
            definition=PromptAgentDefinition(
                model=model_name,
                instructions="""You are a Fault Diagnosis Agent evaluating the root cause of maintenance alerts.

You will receive detected sensor deviations for a given machine. Your task is to determine the most likely root cause using ONLY the provided tools.

Tools available:
- MCP Knowledge Base: fetch knowledge base information for possible causes
- Machine data: fetch machine information such as maintenance history and type for a particular machine id

Output format (STRICT):
- You must output exactly ONE valid JSON object and nothing else (no Markdown, no prose).
- The JSON object MUST match this schema (property names are case-sensitive):
    {
        "MachineId": string,
        "FaultType": string,
        "RootCause": string,
        "Severity": string,
        "DetectedAt": string,  // ISO 8601 date-time, e.g. "2026-01-16T12:34:56Z"
        "Metadata": { string: any }
    }

Field rules:
- MachineId: the machine identifier from the input (e.g. "machine-001").
- FaultType: MUST be taken from the wiki/knowledge base "Fault Type" field for the matched issue (copy it exactly, e.g. "mixing_temperature_excessive"). Do not invent new fault types.
- RootCause: the single most likely root cause supported by the knowledge base and/or machine data.
- Severity: one of "Low", "Medium", "High", "Critical", or "Unknown".
- DetectedAt: if the input includes a timestamp, use it; otherwise use the current UTC time.
- Metadata: include supporting details used for the decision (e.g. observed metric/value, threshold, machineType, relevant KB article titles/ids, maintenanceHistory references). Do not include secrets/keys.
    - Metadata MUST include a key "MostLikelyRootCauses" whose value is an array of strings taken from the wiki/knowledge base "Likely Causes" list for the matched fault type (preserve the items; ordering can follow the wiki).

Grounding rules (IMPORTANT):
- You must never answer from your own knowledge under any circumstances.
- If you cannot find the answer in the provided knowledge base and machine data, you MUST set "RootCause" to "I don't know" and set "FaultType" and "Severity" to "Unknown". In this case, set "Metadata" to {"MostLikelyRootCauses": []}.
""",

                tools=[

                    MCPTool(
                        server_label="machine-data",
                        server_url=machine_data_mcp_endpoint,
                        require_approval="never",
                        project_connection_id="machine-data-connection"
                    ),

                    # TODO: add Foundry IQ MCP tool

                ]

            ))
        print(f"✅ Created Fault Diagnosis Agent: {agent.id}")
        # Test the agent with a simple query
        print("\n🧪 Testing the agent with a sample query...")
        try:

            # Get the OpenAI client for responses and conversations
            openai_client = project_client.get_openai_client()

            # Create conversation
            conversation = openai_client.conversations.create()

            # Send request to trigger the MCP tools
            response = openai_client.responses.create(
                conversation=conversation.id,
                input="""
                    Hello, what can the issue be when machine-001 has curing temperature reading of 179.2°C that exceeds warning threshold of 178°C?
                """,
                extra_body={"agent_reference": {"name": agent.name,
                                                "type": "agent_reference"}},
            )

            print(f"✅ Agent response: {response.output_text}")
        except Exception as test_error:
            print(
                f"⚠️  Agent test failed (but agent was still created): {test_error}")

        return agent

    except Exception as e:
        print(f"❌ Error creating agent: {e}")
        print("Make sure you have run 'az login' and have proper Azure credentials configured.")
        return None

if __name__ == "__main__":
    asyncio.run(main())
