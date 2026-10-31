# Challenge 2: Capture your expert's know-how in a skill

**[← Previous](challenge-01.md)** - [Home](../README.md) - [Next Challenge →](challenge-03.md)

## 🎯 Objective

Write down how your most experienced colleague does the job, publish it as a **skill**, and prove with a score that the agent now follows your team's rules instead of its own.

## 🧭 Why this matters for your business

Every team has someone who just *knows*: which differences are rounding, which reference formats are really the same invoice, what to do about a credit note. When that person is on holiday the work slows down, and when they leave the knowledge leaves with them.

In Challenge 1 the agent did the work, but it used **its own** judgement. That's fine for a first draft and wrong for a process you sign off. A **skill** is your team's method, written once in plain language and versioned in Foundry. The agent loads it when the task needs it and applies it the same way every time, for every colleague and every partner. When the rules change, you update the skill, not every agent.

The pattern for the rest of the day: **instructions set the outcome, skills set the method.**

## ✅ Tasks

### Part A: Measure the agent without a skill (10 min)

1. In the Foundry portal, open `ops-agent` and start a **new chat**.
2. Pick **one** partner. Use the same one all through this challenge. Attach that partner's statement and `ledger-export.csv`, and ask:

   > *Reconcile this partner's statement against our ledger export. Create exceptions.xlsx with a sheet named after the partner (reference, category, our amount, their amount, difference, action), and give it back to me as a file.*

3. Bring the workbook into Cloud Shell:

   ```bash
   python3 -m frontierops download
   ```

   **What this does:** saves the newest file your agent handed back, `exceptions.xlsx`, in your Cloud Shell home folder (`~`).
4. Score it against the answer key for your company:

   ```bash
   python3 -m frontierops score ~/exceptions.xlsx
   ```

   **What this does:** every statement has six lines planted the way real statements go wrong: a real price difference, a rounding difference, lines missing on each side, a duplicate and a credit note. The tool opens the workbook the agent gave you, compares it with the answer key for your company and lists each line the agent handled differently from your handbook. It only reads the file; nothing changes in Azure. Note the score.

> 📸 **Screenshot to add:** `images/challenge-02-score-before.png`: Cloud Shell: the score without a skill, with the lines the agent got wrong.

### Part B: Write the skill (15 min)

The setup command put a starter skill in `my-files/skills/reconciliation/SKILL.md`. It has the five headings an expert would use, and a **TODO** where your words go.

1. Open it in the Cloud Shell editor:

   ```bash
   code my-files/skills/reconciliation/SKILL.md
   ```

   **What this does:** opens the file in a simple editor above the terminal. A skill is just a text file: a few lines at the top that name and describe it, then the method in plain English.

2. Open `my-files/handbook.md` next to it and, as a team, replace every **TODO** with your company's method. Write it the way you'd brief a new joiner: short, exact, with the real numbers. For example: the tolerance amount, which reference formats count as the same, and the action for each kind of exception.
3. Keep the first lines (the front matter between the two `---` lines). The **name** must stay `reconciliation`. The **description** is what the agent reads to decide when to use the skill, so make it one clear sentence.
4. Save with Ctrl+S.

> [!TIP]
> Business people write the best skills. Let the person who knows the process dictate and the person at the keyboard type.

### Part C: Publish it (5 min)

```bash
python3 -m frontierops publish-skill my-files/skills/reconciliation
```

**What this does:**

- Checks your file first, and tells you in plain words what to fix: a TODO left in, quotes around the name, a missing description.
- Packages the folder and uploads it to your Foundry project as a new **version** of the skill `reconciliation`, and makes it the default.
- Doesn't change your agent yet; that's Part D.

If you publish again later, you get version 2, 3 and so on. Older versions are kept, so you can always go back. If the tool asks you to sign in, you're in a new Cloud Shell session: run `az login --use-device-code` as in Challenge 1, then publish again.

> 📸 **Screenshot to add:** `images/challenge-02-publish-skill.png`: Cloud Shell: publish-skill reports the version it published.

### Part D: Give the skill to your agent (5 min)

1. In the Foundry portal, select **Build**, then **Tools**, and open **Skills (Preview)**. Find `reconciliation` and open it: you see your description and your method.
2. Open `ops-agent`. In the **Tools** section select **Add**, then **Add skills**, choose `reconciliation` and select **Add**.
3. Select **Save and start new chat** and wait for the new version to become active.

> 📸 **Screenshot to add:** `images/challenge-02-add-skill.png`: The agent's Tools section with the reconciliation skill added.

### Part E: Measure again (10 min)

1. In the new chat, attach the same two files and send the same request as in Part A.
2. Watch the steps: early on the agent calls **skill** with `reconciliation` and loads your method before it writes any code.
3. Run `python3 -m frontierops download` again to fetch the new workbook (it replaces the first one in `~`), and score it again.
4. Compare the two scores. Which lines changed? Find the rule in your skill that made the difference.

> 📸 **Screenshot to add:** `images/challenge-02-score-after.png`: Cloud Shell: the score with the skill, next to the score without it.

## ✔️ Success criteria

- [ ] You measured the agent without a skill, and know which kinds of line it got wrong.
- [ ] Your team wrote the company's method in `SKILL.md` and published it.
- [ ] `ops-agent` loads the skill (you saw the **skill** step) and scores higher with it.
- [ ] You can explain the difference between instructions (the outcome) and a skill (the method), and why the skill is kept outside the agent.

## 📚 Learning resources

- [Use skills with Microsoft Foundry agents](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/skills)
- [Add a skill to a Copilot harness agent](https://learn.microsoft.com/azure/foundry/agents/how-to/use-tools-skills-copilot-harness#add-a-skill)
- [The Agent Skills format](https://agentskills.io)

[Coach solution and expected answers](../walkthrough/challenge-02/solution-02.md)
