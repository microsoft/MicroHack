# Challenge 5 solution: Handoff and agent assist

**[← Previous Solution](../challenge-04/solution-04.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-05.md) - [Next Solution →](../challenge-06/solution-06.md)

**Duration:** 45 minutes

## Expected handoffs

After Part B the CRM home page lists two handoffs:

| Scenario | `customer_id` | Priority | Vulnerability |
|---|---|---|---|
| Vulnerability scenario (for example telco `KC100203`, telecare alarm) | The vulnerable customer, for example `KC-C03` | **high** | true |
| *I'd like to speak to a real person* after verifying | The verified customer | normal | false |

The summary should let a colleague continue without asking again: what happened, what the customer needs and what the agent already did, including any reference numbers.

Two valid ways to handle an unverified caller at risk, both seen in our tests:

1. **Verify quickly, then hand over:** the agent asks for the account number and postcode, checks for a service notice, then calls `escalateToHuman` with the `customer_id`. In our telco run it verified `KC100203`, found the ZZ4 outage, said *our records show…* and handed over at high priority.
2. **Hand over at once, then update:** if the risk is urgent the agent hands over without an account. When the caller then gives their details, it verifies and calls `escalateToHuman` again with the `customer_id` and a summary starting *Update to earlier handoff:*.

Before we added the update rule, the agent handed over unverified and never sent the account, so the adviser had a summary with no customer record. If a group sees that, ask them to find the rule in the HANDOFF section.

## Agent assist

*Next customer, please.* calls `listHandoffs` and picks the oldest high-priority handoff. In our telco run the whisper card:

- flagged a possible vulnerability: a telecare alarm that needs the internet;
- summarised what the voice agent had done;
- gave a calm opening line;
- named the **free 4G backup hub** and an immediate handoff as the next best action, from `KB-KC-005 p4`.

*Wrap up* produced the reason, what was agreed, a follow-up owner and the customer's sentiment.

In the portal run with **Always use** set, the first *Next customer* in one chat searched only the knowledge base and said it couldn't see the queue; a new chat called `listHandoffs` and `getCustomer` and produced the full card. *Always use* forces some tool call, not a particular one, so the ALWAYS line in the instructions still matters. Through the API, every completed run (four of four) called the CRM.

> [!NOTE]
> `agent-assist` only reads the queue; it never changes the CRM. Handoffs from earlier tests stay **waiting**, so *Next customer* may return an older one. Ask for a specific one instead: *Show me the handoff for KC-C03.*

## Points to discuss

- **Why not a second agent that takes over automatically?** In a regulated contact center a person must own a vulnerable customer's call. The tool records the handoff; people decide.
- **Agent assist is for the adviser, not the customer.** It can be more direct and can show internal flags. It must never be connected to a customer channel.
- **The whisper card replaces the most-hated sentence in customer service:** *Can you tell me again what the problem is?*

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| No handoff on the CRM page | The agent said it was connecting the caller but never called `escalateToHuman`. Check **Traces**, then check the HANDOFF section was saved. |
| Handoff has no `customer_id` | The caller was not verified. Fine if it was urgent; the agent should send an update after verification. |
| `agent-assist` says it *can't access the handoff queue* and only the knowledge base appears under the answer | The chat was started before the `crm` tool was saved, so it ran the previous version. **Save**, check the version went up, start a **new chat** and ask again. The ALWAYS line in the instructions also stops the model from skipping the tool. |
| `agent-assist` says the queue is empty | The `CRMTools` toolbox was not added to `agent-assist`, or its `crm` connection points at another CRM. Check the toolbox under **Tools**. |
| Whisper card shows internal citation markers such as `【6:2†source】` | That's how the chat playground shows knowledge citations; the passage opens when selected. |
