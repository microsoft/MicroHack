# Challenge 8 solution: Publish your agent (stretch)

**[← Previous Solution](../challenge-07/solution-07.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-08.md) - [Next Solution →](../finish/solution-finish.md)

**Duration:** 30 to 45 minutes

## Part A: preview web app

**Channels** appears only on agents created with **Interaction mode** **Voice**. The preview web app needs the agent's endpoint to support the Responses protocol, which is the default. Recipients sign in with their own organisational account; possession of the link is not access.

## Part B and C: chat page

The Codespaces container runs the lab's tests when it starts; all should pass. After `az login --use-device-code` and setting `FOUNDRY_PROJECT_ENDPOINT`, `python3 web/app.py` prints `Chat page on http://localhost:8000` and Codespaces opens the forwarded port.

In our test against a telco lab:

- *How do I find out if there is an outage near me?* gave the known-outage check, citing `KB-KC-005 p1`, and offered to check a postcode.
- *Account KC100201, postcode ZZ4 2BT.* in the **same conversation** returned *Our records show there is a known broadband outage in your area… estimated fix 2027-03-04 18:00.*

That proves the page keeps the conversation (the server passes the conversation ID back each turn), and the agent's CRM tool works from outside the portal.

### How it works

| Piece | What it does |
|---|---|
| `web/static/index.html` | The page. It only ever calls `/api/chat` on its own server. |
| `web/app.py` | Gets a token from the Azure CLI sign-in, creates a conversation, calls `POST {project}/openai/v1/responses` with `agent_reference: contact-chat-agent`, and returns the text. |

The browser never holds a token. For real customers you would add: a managed identity instead of a person's sign-in, sign-in or rate limiting for customers, and a published **Agent Application** so the page calls a stable endpoint with its own identity and permissions.

## Part D ideas

- **Talk to a person** button: one line of JavaScript that sends the message; the handoff appears on the CRM page.
- `AGENT_NAME=agent-assist`: the same page becomes the adviser's screen. That's the point: the front end is generic; the agent decides the behaviour.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| *Could not get a token. Run az login* | Run `az login --use-device-code` in the codespace terminal with the lab account. |
| `Foundry returned 401` or `403` | Signed in to the wrong tenant or subscription. `az account show`, then `az login --tenant <lab tenant>`. |
| `Foundry returned 404` | `FOUNDRY_PROJECT_ENDPOINT` is wrong (it must end in `/api/projects/contact-center`), or the agent name is misspelt. |
| Codespaces shows *Single sign-on required for microsoft* | The codespace would be billed to the Microsoft organisation, which needs SSO for members. Select the message to authorise, or open the codespace from your own fork. Check you are on the right repository and branch first. |
| Codespaces says *Codespace access limited: Enterprise-managed users must have their Codespaces usage paid for by Microsoft EMU* | The account is an enterprise-managed user and can only open codespaces on repositories the enterprise pays for, not on a personal fork. Open it from `microsoft/MicroHack` (authorise SSO when asked), or run the page locally: clone the lab, `az login`, set `FOUNDRY_PROJECT_ENDPOINT` and run `python3 web/app.py`; it uses only the Python standard library. |
| Port 8000 doesn't open | Open the **Ports** tab and select the globe icon next to 8000. Keep its visibility **Private**. |
| **Channels** tab missing | The agent was created as a text agent. Only voice agents get the preview web app. |
