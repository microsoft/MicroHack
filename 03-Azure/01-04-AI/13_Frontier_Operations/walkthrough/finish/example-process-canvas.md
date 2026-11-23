# Example process canvas: supplier onboarding

**[Home](../../README.md)** - [Finish](../../challenges/finish.md) - [Blank canvas](../../templates/process-canvas.md)

A worked example for coaches, filled in the way a team would in the Finish. The company and numbers are fictional.

## 1. The process

| Question | Our answer |
|---|---|
| Name of the process | Supplier onboarding |
| Who does it today, and how often? | Procurement team, about 40 new suppliers a month |
| How long does one run take today (people × hours)? | 2 people × 3 hours, spread over 5 working days |
| What triggers it? | A buyer requests a new supplier in the purchasing system |
| What does "done" look like, and who receives it? | Supplier set up in the ERP with verified bank details; the buyer is told |

## 2. Is it ready for an agent?

- [x] People move data between files, emails and systems.
- [x] The rules are written down somewhere, or one expert knows them.
- [x] Most of the time goes on preparing, matching or chasing, not on deciding.
- [x] Exceptions follow a pattern you could explain to a new joiner.
- [x] At least one system has no API, and people type into its web page.
- [x] A person already approves the result before it leaves the team.

## 3. The agent team

| Part | What it is for our process |
|---|---|
| **Instructions** (the outcome) | Prepare each requested supplier for approval, with every check done and evidenced |
| **Skill** (the expert's method) | Our onboarding checklist: required documents, bank-detail checks, sanctions screening, payment terms |
| **Subagents** (work that splits into independent pieces) | One per check, in parallel: documents, bank, sanctions |
| **Tools** (systems with an API) | ERP (create the supplier record, as a draft); document store |
| **Browser** (systems with no API) | The public company registry |
| **People** (who approves what, and when) | Procurement manager approves the supplier; finance approves the bank details |

## 4. Trust

| Question | Our answer |
|---|---|
| What data does the agent see? Is any of it personal or confidential? | Supplier contacts and bank details: confidential |
| Which websites and systems may it reach? | The ERP, the company registry and the sanctions list. Nothing else. |
| What must never happen without a person's approval? | Activating a supplier, or changing bank details |
| How would you check its work in the first month? | A person reviews every onboarding against the checklist |

## 5. The business case

| Measure | Today | With the agent (estimate) |
|---|---|---|
| Time per run (people × hours) | 6 hours | 1 hour (review and approval) |
| Runs per month | 40 | 40 |
| Errors or rework per month | 3 to 4 (wrong bank details, missing documents) | Caught by the checks before approval |
| Cost per run | About GBP 240 in people's time | About GBP 40 of review, plus a few pounds of model and browser |
| Time until the result reaches the decision maker | 5 working days | Same day |

## 6. First step

| Question | Our answer |
|---|---|
| Who owns the process and would sponsor a pilot? | Head of Procurement |
| Which month, partner or team would you pilot with? | New suppliers for one business unit, for four weeks |
| How would you know after four weeks that it worked? | Onboarding in 1 day instead of 5, with no bank-detail errors |
