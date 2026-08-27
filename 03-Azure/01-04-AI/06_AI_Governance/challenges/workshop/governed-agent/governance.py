"""
Minimal AGT-compatible governance module for Foundry Hosted Agents.

Implements:
- CapabilityGuard: tool allow-list (blocks unauthorized tool calls)
- PolicyEngine: regex-based input blocking (PII, sensitive data)
- AuditLog: structured logging of all governance decisions

Pattern based on: https://microsoft.github.io/agent-governance-toolkit/tutorials/34-maf-integration/
"""
import re
import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone

logger = logging.getLogger("agt.governance")


@dataclass
class GovernanceDecision:
    """Result of a governance check."""
    allowed: bool
    tool_name: str
    reason: str
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class CapabilityGuard:
    """Blocks tool calls not in the allowed_tools list."""

    def __init__(self, allowed_tools: list[str]):
        self.allowed_tools = set(allowed_tools)

    def check(self, tool_name: str) -> GovernanceDecision:
        allowed = tool_name in self.allowed_tools
        reason = "Tool in allowed list" if allowed else (
            f"Tool '{tool_name}' blocked by CapabilityGuard - "
            f"not in allowed list: {sorted(self.allowed_tools)}"
        )
        decision = GovernanceDecision(allowed=allowed, tool_name=tool_name, reason=reason)
        logger.info(f"CapabilityGuard: {tool_name} -> {'ALLOW' if allowed else 'DENY'}")
        return decision


class PolicyEngine:
    """Regex-based policy rules for input text (PII, sensitive data)."""

    def __init__(self, rules: list[dict] | None = None):
        self.rules = rules or []

    def check_input(self, text: str) -> GovernanceDecision:
        for rule in self.rules:
            pattern = rule.get("pattern", "")
            if re.search(pattern, text):
                reason = rule.get("message", f"Blocked by rule: {rule.get('name', 'unnamed')}")
                logger.warning(f"PolicyEngine DENY: {rule.get('name')} matched")
                return GovernanceDecision(allowed=False, tool_name="input_check", reason=reason)
        return GovernanceDecision(allowed=True, tool_name="input_check", reason="Input passed all policy checks")


class GovernanceLayer:
    """Combines CapabilityGuard + PolicyEngine into a single governance layer."""

    def __init__(self, allowed_tools: list[str], policy_rules: list[dict] | None = None):
        self.capability_guard = CapabilityGuard(allowed_tools)
        self.policy_engine = PolicyEngine(policy_rules)

    def check_tool(self, tool_name: str) -> GovernanceDecision:
        return self.capability_guard.check(tool_name)

    def check_input(self, text: str) -> GovernanceDecision:
        return self.policy_engine.check_input(text)