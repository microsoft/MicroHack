# Challenge 6: Post-contact analytics and supervisor insights

**[← Previous](challenge-05.md)** - [Home](../README.md) - [Next Challenge →](challenge-07.md)

## 🎯 Objective

Turn recorded calls into structured insight with **Content Understanding**: a transcript, a summary, the customer's intent and sentiment, and a **quality scorecard** you design. Then build a **supervisor agent** that looks across a week of contacts and finds the trends a team leader needs to act on.

## 🧭 Context

Most contact centers review a tiny sample of calls by hand, weeks later. With an analyzer, **every** contact gets the same structured review, and a supervisor can ask questions across all of them: *why are people calling, where, and are we handling it well?*

Your lab has two kinds of material for this:

| Material | Where | Used for |
|---|---|---|
| Three **recorded calls** for your company (MP3) | Storage container `calls` | Analysing individual calls in Parts A and B |
| A **week of analysed contacts** (30 contacts, 1 to 10 March 2027) | Storage container `insights` | Supervisor trends in Parts C and D |

## ✅ Tasks

### Part A: Analyse a recorded call (15 min)

1. In the Azure portal, open your storage account, then **Storage browser**, then the `calls` container, and **download** your company's three MP3 files. Play one: it is a short call between a customer and an adviser.

   ![Storage browser: the calls container with the three MP3 files and Download on the selected blob](../images/challenge-06-download-call.png)

2. In the Foundry portal, type `content understanding` in the search bar at the top, select **Azure-AI-Content-Understanding** (a model) and **Open in playground**.

   ![The Content Understanding playground with the prebuilt analyzers, including Call center](../images/challenge-06-cu-playground.png)

3. Select **Call center**. The first time, a **Configure** panel asks for model deployments. Choose:
   - **Chat completion model:** your `AnalysisModelDeploymentName` (`gpt-5.4`). The call center analyzer needs a full-size model; the lab deploys one for it.
   - **Chat completion model (mini):** your `ModelDeploymentName` (`gpt-5.4-mini`).
   - **Embedding model:** your `EmbeddingDeploymentName` (`text-embedding-3-large`).

   Pick `gpt-5.4` under **Deployments** in the list, not under **Models** (those would create a new deployment). Select **Apply changes**. Don't select **Deploy models** if it is offered: the deployment you need already exists.

   ![Configure: gpt-5.4 under Deployments for the chat completion model](../images/challenge-06-configure-models.png)

4. Upload `<PREFIX>-CALL-02.mp3`, select it and select **Run analysis**. Check the **transcript** (are the adviser and the customer told apart as two speakers?), the **summary**, the **sentiment**, the **topics** and the **people** it found.

![The Call center result: a time-stamped transcript with Agent and Customer, and the summary, topics, companies and people fields](../images/challenge-06-call-analysis.png)

   Turn off **Hide missing fields** to see every field, and open the **Result** tab for the full JSON, including the sentiment.

### Part B: Design your quality scorecard (15 min)

A summary is nice; a **scorecard** changes coaching. You'll build your own analyzer on top of the Call center one.

1. In the Call center playground, select **Customize in CU Studio**. It opens Content Understanding Studio in a new tab.
2. The first time, **Set up your default resource** opens. Choose your lab's resource group (`ResourceGroupName`) and Foundry resource (`FoundryAccountName`); make sure the resource name does **not** say *(new)*. Select **Next**, check that the review lists your three deployments, and **Save**.

   ![Set up your default resource: the lab's resource group and Foundry resource](../images/challenge-06-studio-resource.png)

   ![Review configuration: gpt-5.4 for the prebuilt default scenario, gpt-5.4-mini for search, text-embedding-3-large for embeddings](../images/challenge-06-studio-review.png)

3. Select **Create** and fill in the project:
   - **Project name:** `contact-call-scorecard`; **Workflow kind:** **Extract content and field with custom schema**.
   - Under **Advanced settings**: your lab's resource group, storage account `StorageAccountName` and blob container **`cu-projects`** (the lab creates it for Studio projects; don't use `azure-webjobs-hosts` or the pack containers). **Chat completion model:** `gpt-5.4`.

   ![Create a new project: contact-call-scorecard on the lab's storage account and the cu-projects container](../images/challenge-06-studio-project.png)

4. Upload `<PREFIX>-CALL-02.mp3`. In **Choose a template**, select **Call Center** and **Save**. Its six fields (Summary, Topics, Companies, People, Sentiment, Categories) become your starting schema.

   ![Choose a template: Call Center with its six fields](../images/challenge-06-studio-template.png)

5. On the **Schema** tab, select **Add new field** (or **Click to add new field**) for each row below. Field names can use only letters, numbers and underscores. Set **Value Type** from its dropdown, keep **Method** on **Generate**, and select **Save** at the bottom when all seven are in.

   | Field Name | Field Description | Value Type |
   |---|---|---|
   | `intent` | The main reason for the contact, in two or three words | String |
   | `identity_checked` | True if the adviser confirmed the account number and postcode before discussing the account | Boolean |
   | `resolved` | True if the customer's need was met during the call | Boolean |
   | `escalated` | True if the customer was passed to another person or team | Boolean |
   | `vulnerability_signs` | Any sign the customer may be vulnerable, or "none" | String |
   | `empathy_score` | 1 to 5: how well the adviser acknowledged the customer's feelings | Integer |
   | `next_action` | What should happen next, if anything | String |

   ![The Call Center template's six fields on the Schema tab, with Add new field](../images/challenge-06-studio-schema.png)

6. Select **Run analysis**. The **Test** tab shows every field next to the transcript; the **Result** tab has the JSON, where `identity_checked` comes back as a true or false value and `empathy_score` as a number.

   ![The scorecard for KC-CALL-02: transcript, summary, topics, people and sentiment, with the scorecard fields further down](../images/challenge-06-scorecard.png)

7. Upload the other two calls and run each. Compare the three results with your team. Do the scores match what you heard? Which field would you trust least, and why?

### Part C: The supervisor's knowledge base (10 min)

1. In **Build**, then **Knowledge**, create a second knowledge base `contact-insights-kb` (chat completions model `ModelDeploymentName`, **Minimal** reasoning, **Extractive data**) with a new Azure Blob Storage source `contact-insights` on the **`insights`** container, with the same settings as Challenge 1. Wait until it is **Active**.

   ![Create a knowledge source: contact-insights on the insights container, System assigned identity, Minimal, text-embedding-3-large](../images/challenge-06-insights-source.png)

   ![contact-insights-kb saved with the contact-insights source Active](../images/challenge-06-insights-kb.png)

2. Create an agent `supervisor-insights` with **Interaction mode** **Text**, remove **Web search**, add `contact-insights-kb` under **Knowledge**, and paste:

   ```text
   You are the supervisor insights assistant for <Company>'s contact center team leaders.

   Your knowledge base holds analysed contacts: date, channel, intent, postcode area, sentiment,
   whether it was resolved at first contact, whether it was escalated, handle time, quality scores
   from 1 to 5 and a short summary. ALWAYS search it before answering. Never invent numbers.

   When asked about trends:
   - Count, don't guess. Give numbers and the contact IDs behind them.
   - Look for spikes by intent, by area and by day, and connect them (for example many outage
     contacts in one area on the same days).
   - Point out quality problems, especially any contact where verification scored 1, which means
     the identity check was missed.
   - Finish with two or three concrete actions for next week, each linked to the evidence.
   Keep answers short enough for a team leader to read in two minutes.
   ```

3. **Save**.

### Part D: Find the trends (10 min)

Ask `supervisor-insights`:

1. *What were the top three reasons customers contacted us from 1 to 10 March?*
2. *Is there a spike in any postcode area? On which days?*
3. *Which contacts missed the identity check?*
4. *What should we change next week?*

Check one answer against the contacts file in the `insights` container. Every company has one deliberate trend and two missed identity checks hidden in its week. Did the supervisor find them?

![supervisor-insights with only contact-insights-kb, counting the top contact reasons with the contact IDs behind them](../images/challenge-06-supervisor-setup.png)

![The spike: ZZ4 contacts by day, with three a day from 3 to 6 March, and next-week actions](../images/challenge-06-supervisor.png)

![The two contacts where the identity check was missed](../images/challenge-06-supervisor-checks.png)

## ✔️ Success criteria

- [ ] The Call center analyzer produces a transcript, summary and sentiment for your company's calls, and `contactCallScorecard` adds your scorecard fields.
- [ ] Your scorecard fields are filled in for all three calls, and you discussed which ones you would trust.
- [ ] `supervisor-insights` uses only `contact-insights-kb`, and finds your company's trend and the two missed identity checks.
- [ ] Its recommended actions are tied to evidence from the contacts.

## 📚 Learning resources

- [Content Understanding audio overview](https://learn.microsoft.com/azure/ai-services/content-understanding/audio/overview)
- [What is Foundry IQ?](https://learn.microsoft.com/azure/foundry/agents/concepts/what-is-foundry-iq)

[Coach solution and expected answers](../walkthrough/challenge-06/solution-06.md)
