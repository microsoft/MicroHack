"""Validated proposal state and deterministic, simulated approval actions."""

from datetime import datetime, timezone
from decimal import Decimal
from enum import StrEnum
import re
import uuid

from pydantic import BaseModel, ConfigDict, Field


class Line(BaseModel):
    model_config = ConfigDict(extra="forbid")
    sku: str = Field(pattern=r"^P[0-9]{3}$")
    location: str = Field(min_length=1, max_length=120)
    quantity: int = Field(strict=True, ge=1, le=100000)
    unit_cost: Decimal = Field(gt=0, max_digits=12, decimal_places=2, allow_inf_nan=False)


class Proposal(BaseModel):
    model_config = ConfigDict(extra="forbid")
    lines: list[Line] = Field(min_length=1, max_length=50)


class Status(StrEnum):
    AWAITING_APPROVAL = "AWAITING_APPROVAL"
    APPROVED = "APPROVED"
    CANCELLED = "CANCELLED"


class Order(BaseModel):
    model_config = ConfigDict(extra="forbid")
    proposal_id: str = Field(default_factory=lambda: uuid.uuid4().hex)
    revision: int = Field(default=1, ge=1)
    status: Status = Status.AWAITING_APPROVAL
    proposal: Proposal
    created_utc: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    decided_utc: str | None = None

    def render(self) -> str:
        rows = [
            "PURCHASE ORDER PROPOSAL (simulation only)",
            f"Proposal: {self.proposal_id} | Revision: {self.revision} | Status: {self.status}",
            "| Line | SKU | Location | Qty | Unit cost | Line total |",
            "| --- | --- | --- | --- | --- | --- |",
        ]
        total = Decimal(0)
        for index, line in enumerate(self.proposal.lines, 1):
            value = line.unit_cost * line.quantity
            total += value
            location = line.location.replace("|", r"\|").replace("\n", " ")
            rows.append(
                f"| {index} | {line.sku} | {location} | {line.quantity} | "
                f"${line.unit_cost:.2f} | ${value:.2f} |"
            )
        rows.append(f"Total estimated value: ${total:.2f}. No real ERP is connected.")
        if self.status == Status.AWAITING_APPROVAL:
            token = f"{self.proposal_id} {self.revision}"
            rows.extend([
                f"Approve: `YES {token}`",
                f"Cancel: `NO {token}`",
                f"Change quantity: `MODIFY {token} <line> <quantity>`",
                "A change increments the revision and requires fresh approval.",
            ])
        return "\n".join(rows)

    def apply(self, text: str) -> str:
        parts = text.split()
        if len(parts) < 3 or parts[0].upper() not in {"YES", "NO", "MODIFY"}:
            return "No action taken. Use an exact command for this proposal:\n\n" + self.render()
        action = parts[0].upper()
        if parts[1] != self.proposal_id or parts[2] != str(self.revision):
            return "No action taken: proposal ID or revision is stale or incorrect.\n\n" + self.render()
        if self.status != Status.AWAITING_APPROVAL:
            return f"No action taken: proposal is already {self.status}. No duplicate submission."
        if action == "MODIFY":
            if len(parts) != 5 or not all(re.fullmatch(r"[0-9]{1,6}", part) for part in parts[3:]):
                return "No action taken: MODIFY needs a line number and positive integer quantity.\n\n" + self.render()
            index, quantity = int(parts[3]), int(parts[4])
            if not 1 <= index <= len(self.proposal.lines) or not 1 <= quantity <= 100000:
                return "No action taken: invalid line or quantity (allowed 1-100000).\n\n" + self.render()
            self.proposal.lines[index - 1].quantity = quantity
            self.revision += 1
            return self.render()
        if len(parts) != 3:
            return "No action taken: approve or cancel with the exact displayed command.\n\n" + self.render()
        self.status = Status.APPROVED if action == "YES" else Status.CANCELLED
        self.decided_utc = datetime.now(timezone.utc).isoformat()
        if self.status == Status.CANCELLED:
            return "Order cancelled. No ERP action has been taken.\n\n" + self.render()
        return (
            f"SIMULATED submission: PO-{self.proposal_id}-{self.revision}. "
            "No order was sent to a real ERP.\n\n" + self.render()
        )
