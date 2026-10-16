#!/usr/bin/env python3
"""
Batch execution script for both agents to populate traces in Azure AI Foundry.

This script runs multiple work orders through both the Maintenance Scheduler
and Parts Ordering agents to generate comprehensive trace data for monitoring.

Usage:
    python run-batch.py
"""

import asyncio
import sys
from datetime import datetime

# Work orders to process (matching actual Cosmos DB data)
WORK_ORDERS = ["wo-2024-445", "wo-2024-456",
               "wo-2024-432", "wo-2024-468", "wo-2024-419"]


async def run_agent(script_name: str, work_order: str) -> tuple[bool, str]:
    """Run an agent script with a work order ID"""
    try:
        proc = await asyncio.create_subprocess_exec(
            sys.executable, script_name, work_order,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )

        stdout, stderr = await proc.communicate()
        output = stdout.decode() + stderr.decode()

        success = proc.returncode == 0
        return success, output
    except Exception as e:
        return False, str(e)


async def run_maintenance_scheduler_batch():
    """Run all work orders through Maintenance Scheduler Agent"""
    print("┌─────────────────────────────────────────────────────────────┐")
    print("│  PART 1: Maintenance Scheduler Agent                       │")
    print("└─────────────────────────────────────────────────────────────┘")
    print()

    results = []
    total = len(WORK_ORDERS)

    for idx, wo in enumerate(WORK_ORDERS, 1):
        print(f"[{idx}/{total}] Processing {wo} with Maintenance Scheduler...")

        success, output = await run_agent("agents/maintenance_scheduler_agent.py", wo)
        results.append((wo, success))

        # Show key output lines
        for line in output.split('\n'):
            if any(marker in line for marker in ['✓', '✗', '===', 'Schedule ID:', 'Risk Score:']):
                print(f"   {line.strip()}")

        if success:
            print(f"   ✅ Completed {wo}\n")
        else:
            print(f"   ⚠️  {wo} had errors\n")

        # Small delay between runs
        await asyncio.sleep(1)

    return results


async def run_parts_ordering_batch():
    """Run all work orders through Parts Ordering Agent"""
    print()
    print("┌─────────────────────────────────────────────────────────────┐")
    print("│  PART 2: Parts Ordering Agent                              │")
    print("└─────────────────────────────────────────────────────────────┘")
    print()

    results = []
    total = len(WORK_ORDERS)

    for idx, wo in enumerate(WORK_ORDERS, 1):
        print(f"[{idx}/{total}] Processing {wo} with Parts Ordering Agent...")

        success, output = await run_agent("agents/parts_ordering_agent.py", wo)
        results.append((wo, success))

        # Show key output lines
        for line in output.split('\n'):
            if any(marker in line for marker in ['✓', '✗', '===', 'Order ID:', 'Total Cost:']):
                print(f"   {line.strip()}")

        if success:
            print(f"   ✅ Completed {wo}\n")
        else:
            print(f"   ⚠️  {wo} had errors\n")

        # Small delay between runs
        await asyncio.sleep(1)

    return results


async def main():
    """Main batch execution"""
    start_time = datetime.now()

    print("=" * 64)
    print("  Batch Agent Execution for Trace Data")
    print("=" * 64)
    print()
    print(f"📊 Processing {len(WORK_ORDERS)} work orders through both agents")
    print("   This will generate traces visible in Azure AI Foundry portal")
    print()

    # Run both agents
    scheduler_results = await run_maintenance_scheduler_batch()
    ordering_results = await run_parts_ordering_batch()

    # Summary
    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds()

    scheduler_success = sum(1 for _, s in scheduler_results if s)
    ordering_success = sum(1 for _, s in ordering_results if s)
    total_runs = len(scheduler_results) + len(ordering_results)
    total_success = scheduler_success + ordering_success

    print()
    print("=" * 64)
    print("  ✅ Batch Execution Complete!")
    print("=" * 64)
    print()
    print("📊 Results:")
    print(
        f"   - Maintenance Scheduler: {scheduler_success}/{len(WORK_ORDERS)} successful")
    print(
        f"   - Parts Ordering Agent: {ordering_success}/{len(WORK_ORDERS)} successful")
    print(f"   - Total: {total_success}/{total_runs} successful")
    print(f"   - Duration: {duration:.1f} seconds")
    print()
    print("View traces in Azure AI Foundry:")
    print("1. Navigate to: https://ai.azure.com")
    print("2. Select your project")
    print("3. Go to: Tracing → View traces")
    print("4. Filter by agent name:")
    print("   - MaintenanceSchedulerAgent")
    print("   - PartsOrderingAgent")
    print()
    print(f"You should see approximately {total_runs} traces total")
    print()


if __name__ == "__main__":
    asyncio.run(main())
