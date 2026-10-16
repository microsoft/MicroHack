import asyncio
import os

from agent_framework.openai import OpenAIChatClient
from azure.cosmos import CosmosClient
from azure.identity.aio import AzureCliCredential
from dotenv import load_dotenv

# TODO: add HostedMCPTool import

load_dotenv(override=True)

# Configuration
project_endpoint = os.environ.get("AZURE_AI_PROJECT_ENDPOINT")

# Initialize Cosmos DB clients globally for function tools
cosmos_endpoint = os.environ.get("COSMOS_ENDPOINT")
cosmos_key = os.environ.get("COSMOS_KEY")
cosmos_client = CosmosClient(cosmos_endpoint, cosmos_key)
database = cosmos_client.get_database_client("FactoryOpsDB")
thresholds_container = database.get_container_client("Thresholds")
machines_container = database.get_container_client("Machines")

# MCP configuration
# TODO: add subscription key and MCP endpoint


def get_thresholds(machine_type: str) -> list:
    """Get all thresholds for a machine type from Cosmos DB"""
    try:
        query = f"SELECT * FROM c WHERE c.machineType = '{machine_type}'"
        items = list(thresholds_container.query_items(
            query=query,
            enable_cross_partition_query=True
        ))
        return items
    except Exception as e:
        return [{"error": str(e)}]


def get_machine_data(machine_id: str) -> dict:
    """Get machine data from Cosmos DB"""
    try:
        query = f"SELECT * FROM c WHERE c.id = '{machine_id}'"
        items = list(machines_container.query_items(
            query=query,
            enable_cross_partition_query=True
        ))
        return items[0] if items else {"error": f"Machine {machine_id} not found"}
    except Exception as e:
        return {"error": str(e)}


async def main():
    try:
        async with AzureCliCredential() as credential:
            async with (
                OpenAIChatClient(credential=credential).as_agent(
                    name="AnomalyClassificationAgent",
                    description="Anomaly classification agent",
                    instructions="""You are a Anomaly Classification Agent evaluating machine anomalies for warning and critical threshold violations.
                            You will receive anomaly data for a given machine. Your task is to:
                            - Validate each metric against the threshold values 
                            - Raise an alert for maintenance if any critical or warning violations were found

                            You have access to the following tools:
                            - get_machine_data: fetch machine information such as type for a particular machine id
                            - get_thresholds: fetch threshold rules for different metrics per machine type

                            Use these functions to extract and validate the anomaly data.

                            Output should be:
                            - alerts with format:
                                {
                                "machineId": "<machine_id>",
                                "status": "high" | "medium",
                                "alerts": [ {"name": "metricName1", "severity": "threshold", "description": "metric1 exceeded value x}, { "name": "metricName2", ... ],
                                "summary": {
                                    "totalRecordsProcessed": <int>,
                                    "violations": { "critical": <int>, "warning": <int> }
                                }
                                }
                            - summary: human readable summary of the anomalies 

                            """,
                    tools=[
                        get_machine_data,
                        get_thresholds]

                ) as agent,
            ):

                print(f"✅ Created Anomaly Classification Agent: {agent.id}")

                # Test the agent with a simple query
                print("\n🧪 Testing the agent with a sample query...")
                try:
                    result = await agent.run('Hello, can you classify the following anomalies for machine-001: [{"metric": "curing_temperature", "value": 179.2},{"metric": "cycle_time", "value": 14.5}]')
                    print(f"✅ Agent response: {result.text}")
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
