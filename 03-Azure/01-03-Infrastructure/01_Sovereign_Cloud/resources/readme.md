# Sovereign Cloud infrastructure preparation

Choose the delivery path before running any setup or cleanup scripts.

| Delivery path | Start here | Infrastructure ownership |
| --- | --- | --- |
| Eligible Microsoft-hosted event | [Hosted events](hosted-events/readme.md) | Hacks Console provisions lab scopes, identities and baseline infrastructure. Event Leads complete LocalBox preparation and validate readiness. |
| Personal learning, customer-led or other non-Console delivery | [Manual setup](manual-setup/readme.md) | The subscription owner provisions, funds and removes the infrastructure. |

Both paths use [LocalBox preparation](localbox/readme.md) and the [Pester health checks](tests/readme.md). The Console integration remains in [labautomation](../labautomation); do not run those platform hooks as standalone scripts without the documented platform helper environment.

## Responsibility boundary

| Task | Hosted event | Manual delivery |
| --- | --- | --- |
| Subscriptions, users, initial lab RBAC, provider/quota preparation | Console and content automation | Subscription owner |
| Participant shared Azure AKS with Ubuntu confidential pool, K3s and networking | Console content automation for Challenges 5/7 | Subscription owner using the lab template |
| Challenge 4 ACI/ACR comparison and Challenge 5 applications | Participants using walkthrough scripts | Same walkthrough scripts against the prepared scope |
| Shared LocalBox deployment | Console submits once per subscription; full readiness still requires verification | Subscription owner deploys LocalBox |
| Storage, Windows image, VM/AKS networks, AKS on Azure Local | Event Lead runs preparation on each LocalBox Client | Same preparation script |
| AKS Local Entra admin group | Console-owned event group; use **Lab Group ObjectId** from the Credentials tab | Supply an existing security group with intended users as members |
| Runtime health and participant access | Event Lead | Organizer/subscription owner |
| Teardown | Console lifecycle; verify shared resources and group cleanup | Explicit owner-managed cleanup |

One Console team is one lab. This content pack currently shares one LocalBox per **subscription**, so an event spanning several subscriptions has several LocalBoxes. The existing Azure AKS/K3s labs are not replaced by AKS on Azure Local.