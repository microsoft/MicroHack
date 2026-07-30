# Diagrams

Source diagrams for the CLM microhack. Both the **architecture** and the **user journey** views are
maintained as finalized images (`architecture.png`, `user-journey.png`).

| View | Image |
|------|-------|
| **Architecture** — Orchestrator + specialist agents on Microsoft Foundry, grounded by Foundry IQ, traced & evaluated, published to Teams/M365 Copilot | [`architecture.png`](architecture.png) |
| **User journey** — the Contoso contract manager's path: draft → review → ask → sign-off → track → proactive renewal alert | [`user-journey.png`](user-journey.png) |

## Legend (architecture)

- 🟦 **Blue** = GPT agents · 🟪 **Purple** = Claude (Anthropic) agents ·
  🟧 **Orange** = tools / MCP · 🟩 **Green** = data / grounding · ⬜ **Gray** = governance ·
  **dashed grey** = telemetry (traces, eval scorecards) · **dashed red** = alerts / guardrails.

> The **[`architecture.png`](architecture.png)** is the finalized image embedded in the top-level
> README; the **[`user-journey.png`](user-journey.png)** is the finalized user-journey image embedded
> in the README.
