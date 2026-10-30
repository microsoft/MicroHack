# Challenge 3 solution: Take action with the CRM

**[← Previous Solution](../challenge-02/solution-02.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-03.md) - [Next Solution →](../challenge-04/solution-04.md)

**Duration:** 50 minutes

## Expected tool calls

A good run always calls `verifyCaller` **first**, then uses the `customer_id` it returned. Expected sequences:

| Industry | Scenario | Tool calls | Outcome |
|---|---|---|---|
| telco | Known outage | `verifyCaller` → `getServiceNotices` (area `ZZ4`) | ZZ4 fibre-cable outage, estimated fix 4 March 18:00; compensation is automatic (`KB-KC-005`); **no** engineer booked |
| telco | Book a visit | `verifyCaller` → `getServiceNotices` (`ZZ5`, none) → `listAppointmentSlots` → `bookAppointment` | Two slots offered, one booked, reference `KC-APT-01xx` read back |
| energy | Estimated bill | `verifyCaller` → `getServiceNotices` (`ZZ2`) → optionally `openCase` | ZZ2 meter-reading notice; asks for a reading |
| energy | Smart meter | `verifyCaller` → `listAppointmentSlots` → `bookAppointment` | Slot booked; someone over 18 must be home |
| bank | Dispute status | `verifyCaller` → `getCustomer` | Open case `HB-CASE-1207`; up to 30 days |
| bank | Book an adviser | `verifyCaller` → `listAppointmentSlots` → `bookAppointment` | Mortgage adviser call booked; bring payslips and statements |
| insurance | Storm damage | `verifyCaller` → `getServiceNotices` (`ZZ3`) → `openCase` | Safety first; temporary repairs up to 500 pounds; claim case opened |
| insurance | Assessor visit | `verifyCaller` → `listAppointmentSlots` → `bookAppointment` | Assessor visit booked |
| retail | Late order | `verifyCaller` → `getServiceNotices` (`ZZ5`) → `openCase` | ZZ5 depot closure; refund or redelivery; case for the delivery fee |
| retail | Return collection | `verifyCaller` → `listAppointmentSlots` → `bookAppointment` | Returns collection booked; refund within 5 working days of arrival |

Each booking and case shows up on the CRM home page within seconds.

In our telco voice test the booking scenario ran `getServiceNotices` (ZZ5, none), gave the restart steps from `KB-KC-005`, then `verifyCaller` → `listAppointmentSlots` → `bookAppointment`, and booked `KC-APT-0101`. Asking for the postcode first to check notices, then for identity before booking, is fine.

In our telco test the chat agent verified `KC100201`, found the ZZ4 notice and did not offer an engineer. For the booking scenario it offered two slots, booked the chosen one and read back `KC-APT-0103`.

## Identity checks

Try a wrong postcode, for example `KC100202` with `ZZ9 9ZZ`. `verifyCaller` returns `verified: false` and the agent must share **nothing** about the account, not even whether it exists. In our tests the agent asked the caller to check their details and offered a colleague.

Answers about the account should sound like *our records show…*. The agent must not mention internal IDs (`customer_id`, `slot_id`) or cite an article for something that came from the CRM.

## Points to discuss

- **Deterministic work stays in code.** The CRM decides whether an account number and postcode match, and never returns a stored account number in full, so the agent can't read one out from the records. The number the caller says still reaches the model and the traces, which is one reason traces need the same care as call recordings.
- **Where the system stops:** this CRM trusts the agent to call `verifyCaller` before `getCustomer`, `bookAppointment` or `openCase`. Ask groups how they would close that gap in a real system, for example with a short-lived verification token that every later call must present.
- **Read-back:** the agent says the reference number only after the tool returns it. If it says *I've booked that* without a `bookAppointment` call in **Traces**, that is a serious failure; ask participants to find the sentence in the instructions that forbids it.
- **Same tool, two channels:** the chat agent gets the same tool and instructions. Customers expect the same answer whichever way they contact you.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| The OpenAPI tool won't save | It needs a **Connection** even with **Anonymous** authentication: create one named `crm` with your `CrmUrl`. Paste the JSON from `<CrmUrl>/openapi.json`, not the URL. |
| No **Add** option for an OpenAPI tool on the voice agent | Voice agents take tools from a toolbox. Create `CRMTools` under **Build**, then **Tools**, and use **Add a toolbox** on the agent. |
| The toolbox still has `web_search`, `code_interpreter` or `FoundryMCPServerpreview` | They are added by default. Remove them so the agent can only reach the CRM, then save the toolbox as a new version and select that version on the agent. |
| A test customer is *not verified* although the details are right | Speech recognition misheard them. The CRM home page shows each identity check with the postcode it heard and why it failed. The CRM already ignores spaces and punctuation and reads a spoken *oh* as zero; ask the participant to say the details slowly or spell them. |
| **Traces** says *Create or connect an App Insights resource* | The project has no Application Insights connection. The lab automation creates one (`appinsights`); in an older lab, select **Connect** and choose the lab's Application Insights. Only sessions started after connecting are traced. |
| Tool calls fail with 409 | No industry pack is selected in the CRM. Run the Challenge 1 `setup` command again. |
| Tool calls fail with 500 or time out on the first call | The CRM is cold-starting on Flex Consumption. Wait 30 seconds and ask again. |
| `bookAppointment` returns 409 *That slot has just been taken* | Another participant in the same lab booked it. The agent should offer another slot; ask it to. |
| The agent asks for the account number again after verifying | It lost track of `customer_id`. Check the IDENTITY section was pasted in full: it tells the agent to *use the customer_id* from `verifyCaller` for every later call. |
