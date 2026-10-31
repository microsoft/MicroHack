# Challenge 5: Work in a portal that has no API

**[← Previous](challenge-04.md)** - [Home](../README.md) - [Next Challenge →](challenge-06.md)

## 🎯 Objective

Raise the approved queries in your partner's **web portal**, the one with no API, by letting the agent use a **browser**. A named person approves every query before it's submitted, and the portal records who approved it.

## 🧭 Why this matters for your business

Every company has systems that only have a web page: a partner's portal, a government site, a supplier's ordering screen. Today people copy each item into those forms by hand, and it's often the step that stops a process from being automated at all.

**Browser Automation** in Foundry gives your agent a managed browser in Microsoft's cloud. It reads the page, fills the form and submits it, the way a person would. That reaches the last mile, and it's exactly why the controls matter: anything the agent submits is real. So in this challenge the agent **prepares**, a person **approves**, and only then does the agent **submit**.

## ✅ Tasks

### Part A: Do one by hand (5 min)

1. Open `<BackOfficeUrl>/portal` and select **Raise a new …**. Look at the form: partner, type, reference, amount, details and **Approved by**. The portal refuses a query without an approver.

   ![The partner portal's form: supplier, type of query, reference, amount, details and Approved by](../images/challenge-05-portal-form.png)

2. Don't submit anything. Count the clicks and fields for one query, and multiply by the queries in your Summary sheet from Challenge 3.

### Part B: Add the browser to your toolbox (10 min)

1. Select **Build**, then **Tools**, and open your `ops-tools` toolbox. Under **Included**, select **Add**, then **Add tool**.
2. On the **Configured** tab, select **Browser Automation**, then **Add tool**.

   ![Select a tool, Configured tab: Browser Automation selected](../images/challenge-05-select-browser.png)

3. Choose the connection `BrowserConnectionName` (`browser`) and select **Connect**. The lab automation connected it to your own Playwright workspace, which signs in with the project's identity: there's no password or key to manage. (If the dialog says preview connections are deprecated, that's expected in this lab; the connection works.)

   ![Add Browser Automation tool: the browser connection](../images/challenge-05-browser-connection.png)

4. The toolbox now has two tools, `erp` and `browser`. Save it: that creates **version 2**. Your agent still uses version 1 until you switch it.

   ![The ops-tools toolbox with the ERP tool and Browser Automation](../images/challenge-05-toolbox-browser.png)

5. Open `ops-agent`. In **Tools**, select the **⋯** next to `ops-tools`, then **Switch version**. Choose **Version 2** and select **Switch**. The toolbox now shows as `ops-tools (2)`: the number is the version the agent uses. Select **Save and start new chat**.

   ![The toolbox menu on the agent: Edit, View, Switch version and Remove](../images/challenge-05-switch-version-menu.png)

   ![Switch toolbox version: Version 2 selected](../images/challenge-05-switch-version.png)

   Versions are a control, not a chore: an agent keeps the tools it was tested with until someone deliberately moves it to the new ones.

### Part C: Prepare, approve, submit (25 min)

1. In the new chat, attach your `exceptions.xlsx` from Challenge 3 (to get it onto your computer: in Cloud Shell, **Manage files**, **Download**, `exceptions.xlsx`) and ask:

   > *From this workbook, list the queries we should raise in the partner portal: partner, type of query, reference, amount and a one-line reason. Use your skill for the type and action. Don't submit anything yet: wait for my approval.*

   In seconds the agent lists every query with the action from your skill, and stops: *I've not submitted anything; waiting for your approval.*

   ![The agent's list of queries to raise, ending with: waiting for your approval](../images/challenge-05-prepare-queries.png)

2. Check the list as a team. Pick **two** queries to raise now; a browser is slow, so start small.
3. Approve in writing, as your company's approver (see the table below), and ask the agent to check its own work before each submit:

   > *Approved by <approver's name>. Raise these two queries in the partner portal at <BackOfficeUrl>/portal, one form per query, with the approver's name in Approved by: <the two queries from the list>. Before you submit each form, take a snapshot and check every field matches the query, especially the supplier. Fix anything that doesn't match. After submitting, report the reference number and the supplier the portal shows.*

4. Watch it work. The agent opens the portal, picks the partner and the type, types the reference, amount and details, fills in **Approved by** and submits. Each step goes back to the model to decide the next click, so one form takes one to three minutes.
5. **Check the agent's work.** Open `<BackOfficeUrl>/portal` in your own tab and compare every row with what you approved: supplier, type, reference and amount.

| Company | Approver |
|---|---|
| Ashgrove Supply | Dana Okoro, Financial Controller |
| Kestrel Connect | Tom Ashby, Head of Carrier Relations |
| Lumora Energy | Helen Marsh, Finance Director |
| Northmere Insurance | Claire Dunmore, Chief Financial Officer |
| Parcelpine | Joanna Price, Finance Director |

> [!IMPORTANT]
> **Why step 5 matters.** In our test, without the check in the approval, we asked for three queries. The agent reported three reference numbers as if all were done, but one had been filed under the wrong supplier: a dropdown had timed out and the agent didn't look again before submitting. The portal had the evidence; the agent's report didn't. An agent that works in a web page can be wrong in ways it doesn't notice, so a person compares the result with the approval, every time.
>
> ![The agent's report: three reference numbers](../images/challenge-05-agent-report.png)
>
> ![The portal: INQ-106 filed under Kellerman Hygiene instead of Brightwell Packaging](../images/challenge-05-portal-cases.png)

### Part D: See every browser session (10 min)

Every time the agent opens a browser, your Playwright workspace records it: when it started and ended, which agent opened it, and how long it was billed for.

1. In the [Azure portal](https://portal.azure.com), open your Playwright workspace (`PlaywrightWorkspaceName`, for example `pw-frontier-<suffix>`).
2. Select **Browser sessions**, then **Browser activity log**. Each row is one browser session from your agent, with its **Billable Time**.
3. Select a session. **Browser session details** shows the start and end, the status, the browser (Chromium on Linux) and the **Source ID**: the Foundry project and agent that opened it.
4. Look at **Billable Time** and **Status**. In our lab, sessions that did a minute or two of work were billed for 15 to 31 minutes, and the newest ones were still **Active** long after the agent had answered: a browser stays open, and billed, until it times out. Add up the billable time for your Part C run; you'll use it for the cost of a run in Challenge 7.

   ![Browser activity log: one row per session, with billable time; the newest still active](../images/challenge-05-browser-sessions.png)

   ![Browser session details: an agent's session still Active after the agent finished](../images/challenge-05-browser-session-details.png)

5. Fix it the way you'd fix it for a colleague: tell the agent to tidy up. Add this sentence to `ops-agent`'s instructions and save:

   ```text
   When you have finished in a web page, close the browser.
   ```

   Next time, check the log again: the session should end when the agent finishes. In **Traces**, the agent's last browser step is now `close_browser_session`. In our lab the next session was billed **3 minutes 34 seconds**, the length of the run, instead of 15 to 31 minutes.

   ![Browser activity log after the fix: the newest session billed 00:03:34](../images/challenge-05-browser-closed.png)

The agent's browser runs in Microsoft's cloud, not on your computer, and in this preview there's no live view of it from the Foundry playground. That's one more reason for the check in step 5 of Part C: the evidence of what the agent did is the portal itself, the trace, and this log.

### Part E: Discuss (5 min)

- The approval here is a sentence in the chat. Where would a real approval come from in your organisation: an email, a Teams message, a workflow? What would you need to see in the trace to trust it?
- Which web-only systems in your organisation would you point this at first? Which would you never?

## ✔️ Success criteria

- [ ] The agent prepared a list of queries and waited for approval.
- [ ] After approval, it raised them in the portal with the approver's name, and gave you each reference number.
- [ ] You compared every query in the portal with what you approved, and know what to do if one is wrong.
- [ ] You can explain why the browser is the riskiest tool so far, and what keeps it under control.

## 📚 Learning resources

- [Browser Automation tool in Foundry](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/browser-automation)
- [Playwright Workspaces](https://learn.microsoft.com/azure/app-testing/playwright-workspaces/overview-what-is-microsoft-playwright-workspaces)
- [Create and manage a toolbox](https://learn.microsoft.com/azure/foundry/agents/how-to/tools/toolbox)

[Coach solution and expected answers](../walkthrough/challenge-05/solution-05.md)
