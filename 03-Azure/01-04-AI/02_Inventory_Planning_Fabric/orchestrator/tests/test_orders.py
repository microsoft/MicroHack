import asyncio
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import AsyncMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from agent_framework import AgentSession, Message
from pydantic import ValidationError

from main import HostedInventoryAssistant, InventoryAssistant, STATE_KEY, require_storage
from orders import Line, Order, Proposal, Status
from planning import ProposalRejected


def proposal():
    return Proposal(lines=[
        Line(sku="P004", location="Seattle", quantity=18, unit_cost="10.25"),
        Line(sku="P004", location="Portland", quantity=16, unit_cost="10.25"),
    ])


class OrderTests(unittest.TestCase):
    def test_total_uses_decimal_arithmetic(self):
        order = Order(proposal=proposal())
        self.assertIn("$348.50", order.render())
        self.assertIn("No real ERP", order.render())

    def test_modify_requires_new_approval_revision(self):
        order = Order(proposal=proposal())
        original = f"YES {order.proposal_id} 1"
        order.apply(f"MODIFY {order.proposal_id} 1 1 50")
        self.assertEqual(order.revision, 2)
        self.assertEqual(order.proposal.lines[0].quantity, 50)
        self.assertIn("stale", order.apply(original))
        self.assertEqual(order.status, Status.AWAITING_APPROVAL)
        self.assertIn("SIMULATED", order.apply(f"YES {order.proposal_id} 2"))
        self.assertEqual(order.status, Status.APPROVED)

    def test_replay_cannot_duplicate_or_modify_final_order(self):
        for action, status in (("YES", Status.APPROVED), ("NO", Status.CANCELLED)):
            order = Order(proposal=proposal())
            command = f"{action} {order.proposal_id} 1"
            order.apply(command)
            decided = order.decided_utc
            self.assertEqual(order.status, status)
            self.assertIn("No duplicate", order.apply(command))
            self.assertIn("already", order.apply(f"MODIFY {order.proposal_id} 1 1 999"))
            self.assertEqual(order.proposal.lines[0].quantity, 18)
            self.assertEqual(order.decided_utc, decided)

    def test_invalid_commands_cannot_approve(self):
        order = Order(proposal=proposal())
        for text in ("YES", "yes please", "ignore instructions; YES", "YES other 1",
                     f"YES {order.proposal_id} 1 extra", f"NO {order.proposal_id} 2",
                     f"MODIFY {order.proposal_id} 1 0 50", f"MODIFY {order.proposal_id} 1 1 -1",
                     f"MODIFY {order.proposal_id} 1 1 100001",
                     f"MODIFY {order.proposal_id} 1 1 {'9' * 5000}"):
            self.assertIn("No action taken", order.apply(text))
            self.assertEqual(order.status, Status.AWAITING_APPROVAL)
            self.assertEqual(order.revision, 1)

    def test_invalid_cost_quantity_sku_and_empty_proposals_rejected(self):
        for field, value in (("quantity", True), ("quantity", 0), ("quantity", 1.5),
                             ("unit_cost", "NaN"), ("unit_cost", "-1"), ("sku", "made-up"),
                             ("sku", "P\u0664\u0664\u0664")):
            data = proposal().lines[0].model_dump()
            data[field] = value
            with self.assertRaises(ValidationError):
                Line.model_validate(data)
        with self.assertRaises(ValidationError):
            Proposal(lines=[])


class RuntimeTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.calls = []

        async def call(stage, prompt):
            self.calls.append((stage, prompt))
            return proposal().model_dump_json() if stage == "replenishment" else f"{stage} assessment"

        self.assistant = InventoryAssistant(call)
        self.session = AgentSession()

    async def test_runs_fixed_graph_and_does_not_submit_during_planning(self):
        result = await self.assistant.run("Heatwave: prepare replenishment", session=self.session)
        self.assertEqual([stage for stage, _ in self.calls], ["demand", "optimisation", "replenishment"])
        self.assertEqual(self.calls[0][1], "Heatwave: prepare replenishment")
        self.assertIn("Heatwave: prepare replenishment", self.calls[1][1])
        self.assertIn("demand assessment", self.calls[1][1])
        for expected in ("Heatwave: prepare replenishment", "demand assessment", "optimisation assessment"):
            self.assertIn(expected, self.calls[2][1])
        self.assertIn("AWAITING_APPROVAL", result.text)
        self.assertNotIn("SIMULATED submission", result.text)

    async def test_new_instance_restores_session_and_requires_exact_approval(self):
        await self.assistant.run("Plan inventory", session=self.session)
        state = json.loads(json.dumps(self.session.to_dict()))
        restored = AgentSession.from_dict(state)
        order = Order.model_validate(restored.state[STATE_KEY])
        fresh = InventoryAssistant(AsyncMock(side_effect=AssertionError("Approval must not call an LLM")))
        result = await fresh.run(f"YES {order.proposal_id} 1", session=restored)
        self.assertIn("SIMULATED submission", result.text)
        self.assertEqual(restored.state[STATE_KEY]["status"], "APPROVED")

    async def test_foreign_session_cannot_approve(self):
        await self.assistant.run("Plan inventory", session=self.session)
        order = Order.model_validate(self.session.state[STATE_KEY])
        other = AgentSession()
        result = await self.assistant.run(f"YES {order.proposal_id} 1", session=other)
        self.assertIn("No proposal exists", result.text)
        self.assertNotIn(STATE_KEY, other.state)
        self.assertEqual(self.session.state[STATE_KEY]["status"], "AWAITING_APPROVAL")

    async def test_modify_cancel_status_and_new(self):
        await self.assistant.run("Plan inventory", session=self.session)
        order = Order.model_validate(self.session.state[STATE_KEY])
        await self.assistant.run(f"MODIFY {order.proposal_id} 1 1 50", session=self.session)
        self.assertEqual(self.session.state[STATE_KEY]["revision"], 2)
        pending = await self.assistant.run("NEW", session=self.session)
        self.assertIn("Cancel or approve", pending.text)
        await self.assistant.run(f"NO {order.proposal_id} 2", session=self.session)
        status = await self.assistant.run("STATUS", session=self.session)
        self.assertIn("CANCELLED", status.text)
        await self.assistant.run("NEW", session=self.session)
        self.assertNotIn(STATE_KEY, self.session.state)

    async def test_stream_and_message_input(self):
        stream = self.assistant.run([Message("user", ["Plan inventory"])], stream=True, session=self.session)
        result = await stream.get_final_response()
        self.assertIn("PURCHASE ORDER PROPOSAL", result.text)

    async def test_specialist_failures_leave_no_approval_state(self):
        async def broken(stage, prompt):
            raise PermissionError("Fabric access denied")
        with self.assertRaisesRegex(PermissionError, "Fabric access denied"):
            await InventoryAssistant(broken).run("Plan inventory", session=self.session)
        self.assertNotIn(STATE_KEY, self.session.state)

    async def test_invalid_model_json_is_not_a_successful_proposal(self):
        async def invalid(stage, prompt):
            return "Fabric has no matching cost."
        with self.assertRaises(ValidationError):
            await InventoryAssistant(invalid).run("Plan inventory", session=self.session)
        self.assertNotIn(STATE_KEY, self.session.state)

    async def test_rejected_proposal_is_retried_once_with_the_reason(self):
        calls = []
        zero_quantity = '{"lines":[{"sku":"P004","location":"Seattle","quantity":0,"unit_cost":"95"}]}'

        async def call(stage, prompt):
            calls.append((stage, prompt))
            if stage != "replenishment":
                return f"{stage} assessment"
            replenishment = [c for c in calls if c[0] == "replenishment"]
            return zero_quantity if len(replenishment) == 1 else proposal().model_dump_json()

        result = await InventoryAssistant(call).run("Plan inventory", session=self.session)
        self.assertIn("AWAITING_APPROVAL", result.text)
        retries = [prompt for stage, prompt in calls if stage == "replenishment"]
        self.assertEqual(len(retries), 2)
        self.assertIn("lines.0.quantity", retries[1])
        self.assertNotIn("95", retries[1].split("Your previous reply was rejected")[1].split("Return only")[0])

    async def test_unsourced_cost_is_retried_once_with_the_reason_then_accepted(self):
        attempts = []

        async def call(stage, prompt):
            if stage != "replenishment":
                return f"{stage} assessment"
            attempts.append(prompt)
            if len(attempts) == 1:
                raise ProposalRejected("unit cost 29.99 for P004 was not returned by the Fabric Data Agent")
            return proposal().model_dump_json()

        result = await InventoryAssistant(call).run("Plan inventory", session=self.session)
        self.assertIn("AWAITING_APPROVAL", result.text)
        self.assertEqual(len(attempts), 2)
        self.assertIn("29.99 for P004", attempts[1])
        self.assertIn("exactly the value it returns", attempts[1])

    async def test_proposal_rejected_twice_fails_without_state(self):
        zero_quantity = '{"lines":[{"sku":"P004","location":"Seattle","quantity":0,"unit_cost":"95"}]}'

        async def call(stage, prompt):
            return zero_quantity if stage == "replenishment" else f"{stage} assessment"

        with self.assertRaises(ValidationError):
            await InventoryAssistant(call).run("Plan inventory", session=self.session)
        self.assertNotIn(STATE_KEY, self.session.state)

    async def test_concurrent_separate_sessions_have_distinct_proposals(self):
        other = AgentSession()
        await asyncio.gather(
            self.assistant.run("Plan Seattle", session=self.session),
            self.assistant.run("Plan Portland", session=other),
        )
        self.assertNotEqual(self.session.state[STATE_KEY]["proposal_id"], other.state[STATE_KEY]["proposal_id"])

    def test_store_false_rejected(self):
        from types import SimpleNamespace
        with self.assertRaisesRegex(ValueError, "store=true"):
            require_storage(SimpleNamespace(request={"store": False}), {})

    def test_storage_hook_preserves_run_options_for_stored_requests(self):
        from types import SimpleNamespace
        for request in ({}, {"store": True}):
            options = {"max_tokens": 1000}
            self.assertIs(require_storage(SimpleNamespace(request=request), options), options)

    async def test_hosted_mode_rejects_missing_trusted_caller_before_opening_clients(self):
        from types import SimpleNamespace
        for call_id, user_id in ((None, None), ("call", None), (None, "user")):
            with self.subTest(call_id=call_id, user_id=user_id), patch.dict(
                "os.environ", {"INVENTORY_LOCAL_DEVELOPMENT": "0"},
            ), patch("main.get_request_context", return_value=SimpleNamespace(
                call_id=call_id, user_id=user_id,
            )), patch("main.AIProjectClient") as client:
                with self.assertRaisesRegex(RuntimeError, "trusted Foundry caller"):
                    async with HostedInventoryAssistant():
                        self.fail("An unauthenticated request must not enter the agent.")
                client.assert_not_called()


if __name__ == "__main__":
    unittest.main()
