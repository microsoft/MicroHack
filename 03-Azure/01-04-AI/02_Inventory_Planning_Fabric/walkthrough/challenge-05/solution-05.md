# Challenge 5 - Solution: Run and Publish the Hosted Assistant

**[Previous](../challenge-04/solution-04.md)** - [Home](../../README.md)

## Participant deployment

Participants follow the [deployment guide](../../orchestrator/README.md): sign in to
Cloud Shell in a standalone private browser using the lab username/TAP, download only
this lab's folder from `microsoft/MicroHack` (a sparse checkout, about 8 MB, no branch
needed unless you give them a release tag), and run
`./Start-ParticipantDeployment.ps1 -ResourceGroupName '<ResourceGroupName>' -VerifyHosted`.
The script finds the subscription, Foundry project and Fabric IQ connection itself;
`-SubscriptionId`, `-ProjectEndpoint` and `-FabricIQConnectionName` are only needed to
override that. Coach details and troubleshooting are in the
[facilitator guide](../../orchestrator/FACILITATOR.md#troubleshooting-for-coaches).

The participant does not install anything on their computer. Cloud Shell uses
its existing Python for SDK tooling, bootstraps azd/extensions if needed, and
reuses Azure CLI authentication; the application builds remotely in Foundry.
The helper resolves concrete saved specialist versions, reuses the connection,
creates the `inventory-fabric-iq` toolbox from it, and deploys into the existing project. Never put the TAP in shell commands.

Contributor on the RG plus Foundry User on the account/project is the expected
participant permission combination. Facilitators/platform administrators prepare
provider registration, roles, licenses and tenant policy; attendees need not be
Owner. They can predeploy as a contingency, not as proof of self-deployment.
The hosted assistant's own runtime identity needs no extra role assignment: the deploy
helper bundles the pinned specialists at deploy time.
Do not recreate the retired workflow kind.

The [archived canvas exercise](../../archive/visual-workflow-exercise.md) is historical
only. The workflow designer retires on 1 December 2026, and the old Foundry Fabric
Data Agent connector retires earlier, on 6 November 2026. The replacement connector
still uses the existing published Lakehouse Data Agent.

## Expected execution

Each stage runs the participant's saved specialist **instructions and model**
and queries the published Data Agent through the toolbox. For the seed data a
correct first proposal covers P004, P005 and P006 at Portland and Seattle with
unit costs **$95 / $140 / $85**; quantities and the number of lines vary between runs
(one run proposed only P004 at Seattle, which is also valid). The trace shows
`invoke_agent` → `workflow.run` → `executor.process` for each of the three stages, with
`POST .../openai/v1/responses` calls underneath for the model and Fabric lookups. In the
portal's span tree the Fabric call is not labelled `tools/call ...DataAgent...`; that name
appears in Application Insights.

The actual Agent Framework graph is fixed:

```text
demand -> optimisation -> replenishment -> validated proposal
next user turn -> exact proposal/revision approval -> simulated confirmation
```

Specialist failures, malformed JSON or missing costs must not create a proposal.
The host stores the proposal in the scoped conversation session. It does not
retain a process-global graph or wait in a worker for human input.

## Approval checks

1. Run a heatwave scenario and identify the proposal ID and revision 1.
2. Send `MODIFY <id> 1 1 50`; line 1 becomes 50 and the revision becomes 2.
3. Send `YES <id> 1`; it is stale and must not submit.
4. Send `YES <id> 2`; the response says **SIMULATED submission**, explicitly
   not a real ERP write.
5. Repeat the approval; no second submission occurs.
6. Start a fresh proposal with `NEW` followed by a scenario, then cancel it.
7. Check `STATUS`, a delayed continuation and an independent conversation.

The application, not an LLM's generated wording, decides whether approval was
received. Decimal arithmetic calculates totals. A production ERP integration
would require its own transactional approval/idempotency controls.

## Publishing checks (coach)

Participants publish the **hosted assistant** (its latest active version) with **Just you**
and test it in **Teams for web** and **Microsoft 365 Copilot for web**. Confirm the points
in the [Challenge 5 preflight](../../labautomation/README.md#challenge-5-preflight) before
the event, then use this procedure to rehearse or to help a stuck participant:

1. Open a new Edge InPrivate / Chrome Incognito window and sign in with the **assigned lab
   account**. Check the avatar and tenant in every app, including consent pages.
2. [Teams for web](https://teams.cloud.microsoft/): stay in the browser if a desktop launch
   is offered. Find the assistant under **Apps / Your agents** or its app link, then plan,
   modify, send a stale approval, approve, repeat the approval and send `STATUS` in the
   **same chat**.
3. [Microsoft 365 Copilot for web](https://m365copilot.com/): open the assistant under
   **Agents / Your agents** (labels vary), start a **new chat**, check it does not inherit the
   Teams proposal, then plan, cancel and send `STATUS`.
4. Accept the Fabric consent prompt if one appears, in the same private window and with the
   lab account. Never paste a token into chat.
5. If browser privacy settings block sign-in, apply the tenant-approved, site-specific cookie
   and pop-up settings. Do not disable browser security globally, switch to a desktop client
   or use an embedded browser, and do not count an API test as browser acceptance.
6. Close the private windows afterwards. That resets browser sign-in, not server-side chat
   history; use **new chat** for a fresh conversation.

"Just you" is personal testing, not an organization-wide rollout. Rolling out to others needs
**People in your organization** and Microsoft 365 admin approval.

Before release, also test two separate users and a user who has **no** Fabric access: each
must get their own proposal state, and the user without access must be refused.
