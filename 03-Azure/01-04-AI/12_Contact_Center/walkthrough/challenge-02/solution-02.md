# Challenge 2 solution: Voice self-service agent

**[← Previous Solution](../challenge-01/solution-01.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-02.md) - [Next Solution →](../challenge-03/solution-03.md)

**Duration:** 45 minutes

## Expected answers

| Industry | Question | Must contain | Article |
|---|---|---|---|
| telco | First bill higher | A part-month charge from the day you joined or changed plan | `KB-KC-007` |
| telco | Missed engineer visit | 40 pounds without notice; free to move or cancel up to 24 hours before | `KB-KC-006` |
| energy | Estimated bill | Marked with an **E** next to the reading | `KB-LE-005` |
| energy | Smart meter cost | Free | `KB-LE-006` |
| bank | Replacement card | 3 to 5 working days, new card number | `KB-HB-005` |
| bank | Safe account | Never; anyone asking is a criminal | `KB-HB-007` |
| insurance | Home excess | 250 pounds unless the schedule shows otherwise | `KB-NI-005` |
| insurance | Fix the roof now | Emergency temporary repairs up to 500 pounds without approval; keep receipts | `KB-NI-006` |
| retail | Return window | 30 days, unused, original packaging | `KB-PP-006` |
| retail | Next-day order a week late | Refund or free redelivery after 5 working days late | `KB-PP-005` |
| all | Weather | Declines and steers back to the company's topics | none |
| all | *What's my balance?* | Can't access accounts yet; offers a colleague | none |

The **voice** agent names the article in words (*our article on engineer visits says…*) and does not read labels aloud. The **chat** agent ends each fact with a label such as `[KB-KC-007 p1]`. Opening a citation marker shows the passage from the knowledge base.

In our telco test the chat agent answered the bill question citing `KB-KC-007`, declined the weather question, and said it could not see accounts.

## What a good chat twin looks like

The chat twin uses the same instructions with three edits: *chat assistant… customer messages* in the first line, a HOW YOU WRITE section instead of HOW YOU SPEAK, and *Cite only paragraph labels that appear in what the knowledge base returned. Never make one up.*

That last line matters. Before we added it, the chat agent once cited a label that does not exist (`[KC-HELP-001 p1]`) and once used `[CRM]` as if it were a citation. If participants see an invented label, ask them to find the sentence in the instructions that should prevent it.

## Points to discuss

- **Voice is a different design problem.** Short sentences, one question at a time, numbers said as words, no lists, no markdown. Ask participants to read a chat answer aloud: it sounds wrong.
- **Interruptions:** the realtime model stops speaking when the caller talks. Ask why that matters more on a phone line than in chat.
- **Why remove Web search?** With it, the agent could answer from other companies' policies, which sounds right and is wrong for this company.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| **Interaction mode** can't be changed | It is fixed when the agent is created. Create a new agent with **Voice**. |
| No microphone prompt | Browser permissions. Allow the microphone for `ai.azure.com`, or use Edge or Chrome. A headset avoids echo in a busy room. |
| Answers without citing anything | The knowledge base was not added, or Web search is still attached. Check **Tools** and **Knowledge**, then **Save**. |
| *I don't have that information* for a question that is in an article | The knowledge source is still indexing, or the participant loaded another company after building the knowledge base. Check the source is **Active** and the `knowledge` container has the right prefix. |
