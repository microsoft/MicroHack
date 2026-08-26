#!/usr/bin/env python3
"""
Enterprise claims processing data models shared across the claims pipeline agents.
"""

from datetime import datetime, timezone
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field


class SeverityLevel(str, Enum):
    INFO = "INFO"
    WARN = "WARN"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


class ClaimStatus(str, Enum):
    RECEIVED = "RECEIVED"
    INTAKE_COMPLETE = "INTAKE_COMPLETE"
    POLICY_RETRIEVED = "POLICY_RETRIEVED"
    APPROVED = "APPROVED"
    DENIED = "DENIED"
    ESCALATED = "ESCALATED"
    COVERAGE_VALIDATION_FAILED = "COVERAGE_VALIDATION_FAILED"


class StructuredClaim(BaseModel):
    """Normalized claim details used as input to coverage validation"""

    policy_number: str
    claim_amount: float
    damage_description: str
    incident_date: str
    claim_type: str
    vehicle_info: str
    extraction_confidence: float


class PolicyInfo(BaseModel):
    """Policy document fields retrieved for a given policy number"""

    policy_id: str
    policy_number: str
    policy_type: str
    coverage_types: list[str] = Field(default_factory=list)
    limits: dict[str, float] = Field(default_factory=dict)
    deductibles: dict[str, float] = Field(default_factory=dict)
    exclusions: list[str] = Field(default_factory=list)
    effective_date: str
    expiry_date: str
    retrieval_score: float = 0.0


class CoverageDecision(BaseModel):
    """Structured output of the coverage adjudication step"""

    is_covered: bool
    coverage_percentage: float = 0
    applicable_deductible: float = 0.0
    approved_amount: float = 0.0
    exclusions_matched: list[str] = Field(default_factory=list)
    reasoning: str = ""
    risk_flags: list[str] = Field(default_factory=list)
    confidence_score: float = 0.0
    consistency_score: int = Field(default=0, ge=0, le=100)
    requires_escalation: bool = False
    escalation_reason: Optional[str] = None


class ErrorInfo(BaseModel):
    """Structured error/escalation entry attached to a claim's processing state"""

    error_code: str
    error_message: str
    severity: SeverityLevel
    retry_eligible: bool = False
    recommendation: str = ""
    agent_name: str = ""
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class AuditEntry(BaseModel):
    """One entry in a claim's audit trail"""

    agent_name: str
    action: str
    status: str
    message: str = ""
    metadata: dict[str, Any] = Field(default_factory=dict)
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ClaimProcessingState(BaseModel):
    """Shared state passed between agents in the claims processing pipeline"""

    claim_id: str
    status: ClaimStatus = ClaimStatus.RECEIVED
    structured_claim: Optional[StructuredClaim] = None
    policy_info: Optional[PolicyInfo] = None
    coverage_decision: Optional[CoverageDecision] = None
    errors: list[ErrorInfo] = Field(default_factory=list)
    audit_trail: list[AuditEntry] = Field(default_factory=list)
    intelligence_duration_ms: Optional[float] = None

    def update_status(self, status: ClaimStatus) -> None:
        self.status = status

    def add_audit_entry(
        self,
        agent_name: str,
        action: str,
        status: str,
        message: str = "",
        metadata: Optional[dict[str, Any]] = None,
    ) -> None:
        self.audit_trail.append(
            AuditEntry(
                agent_name=agent_name,
                action=action,
                status=status,
                message=message,
                metadata=metadata or {},
            )
        )

    def add_error(self, error: ErrorInfo) -> None:
        self.errors.append(error)

    def to_result_dict(self) -> dict[str, Any]:
        """Serialize to the claim result shape used by the CLI and downstream steps"""
        return {
            "claim_id": self.claim_id,
            "status": self.status.value,
            "policy_info": self.policy_info.model_dump() if self.policy_info else None,
            "coverage_decision": self.coverage_decision.model_dump() if self.coverage_decision else None,
            "audit_trail": [entry.model_dump(mode="json") for entry in self.audit_trail],
            "errors": [error.model_dump(mode="json") for error in self.errors],
            "intelligence_duration_ms": self.intelligence_duration_ms,
        }
