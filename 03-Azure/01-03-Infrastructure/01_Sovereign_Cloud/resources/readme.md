# Sovereign Cloud infrastructure preparation

Choose the delivery path before running any setup or cleanup scripts.

| Delivery path | Start here | Infrastructure ownership |
| --- | --- | --- |
| Eligible Microsoft-hosted event | [Hosted events](hosted-events/readme.md) | Hacks Console provisions lab scopes, identities and infrastructure, prepares LocalBox and verifies infrastructure readiness. Event Leads verify participant access and Defender cloud reporting. |
| Personal learning, customer-led or other non-Console delivery | [Manual setup](manual-setup/readme.md) | The subscription owner provisions, funds and removes the infrastructure. |

Both paths use [LocalBox preparation](localbox/readme.md) and the [Pester health checks](tests/readme.md). Hosted Console automation runs LocalBox preparation and its infrastructure checks without an organizer login to the Client; manual delivery requires the owner to run them. Do not start a competing preparation session during hosted automation. The Console integration remains in [labautomation](../labautomation); do not run those platform hooks as standalone scripts without the documented platform helper environment.

## Responsibility boundary

| Task | Hosted event | Manual delivery |
| --- | --- | --- |
| Subscriptions, users, initial lab RBAC, provider/quota preparation | Console and content automation | Subscription owner |
| Participant shared Azure AKS with Ubuntu confidential pool, K3s and networking | Console content automation for Challenges 5/7 | Subscription owner using the lab template |
| Challenge 4 ACI/ACR comparison and Challenge 5 applications | Participants using walkthrough scripts | Same walkthrough scripts against the prepared scope |
| Shared LocalBox deployment | Console deploys/reuses once per event in the lowest-GUID event subscription and waits for nested readiness | Subscription owner deploys LocalBox |
| Storage, Windows image, VM/AKS networks, AKS on Azure Local, proxy RBAC and MetalLB | Console invokes preparation automatically on LocalBox-Client | Subscription owner runs the same preparation script |
| Reference VM, MDE installation, update assessment and LocalBox infrastructure health | Console prepares the reference VM, waits for onboarding, requests an assessment and runs upstream/Full health checks | Organizer prepares and validates explicitly |
| AKS Local Entra admin group | Console-owned event group; use **Lab Group ObjectId** from the Credentials tab | Supply an existing security group with intended users as members |
| Participant sign-in, Bastion/proxy access, Defender cloud reporting and workload smoke tests | Event Lead; not established by the automated infrastructure gate | Organizer/subscription owner |
| Challenge 6 participant Windows VM and challenge workloads | Participants using walkthroughs; automation does not complete their exercises | Same walkthroughs against prepared infrastructure |
| Teardown | Console lifecycle; verify shared resources and group cleanup | Explicit owner-managed cleanup |

One Console team is one lab. This content pack shares **one LocalBox across the entire event**, even when participant labs span several subscriptions. Use the Console's **Shared LocalBox Subscription ID** and **Shared LocalBox Resource Group ID** to find it. Participant VMs stay in their assigned scopes. The existing Azure AKS/K3s labs are not replaced by AKS on Azure Local.