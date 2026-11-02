# Challenge 7: Measure quality

**[← Previous](challenge-06.md)** - [Home](../README.md) - [Next Challenge →](challenge-08.md)

## 🎯 Objective

Stop judging your agent by one good conversation. **Evaluate** it on your company's test questions with Foundry's built-in evaluators, change one setting, evaluate again and decide with evidence which version should go live.

## 🧭 Context

A language model gives slightly different answers each time. An agent that was perfect in your demo may still invent a fee, skip the identity check or answer an off-topic question on the tenth call. Before customers use it, a contact center needs to know **how often** it is right, not **whether** it can be right.

Each industry pack includes ten test questions with the expected answer (`evaluation.jsonl`). They cover facts from the articles, identity checks, things the agent must refuse and an off-topic question. Foundry runs your agent on every question and scores the answers.

## ✅ Tasks

### Part A: Get your test set (5 min)

1. In the Azure portal, open your storage account, then **Storage browser**, then the `evaluation` container, and download `evaluation.jsonl`.
2. Open it in a text editor. Each line has a `query` (what the customer says) and a `ground_truth` (what a good answer contains, with the article). Pick two lines and predict how your agent will do.

### Part B: Run the first evaluation (15 min)

1. In the Foundry portal, open `contact-chat-agent`, then its **Evaluation** tab, and select **Create**. The wizard has a step list on the left.
2. **Target:** **Agent**, with `contact-chat-agent` ticked at its latest version. **Next**.

   ![Create new evaluation, Target: Agent with contact-chat-agent selected](../images/challenge-07-target.png)

3. **Scope:** **Individual turns** (each line is one question). **Frequency:** **One time**.
4. **Data:** **Existing dataset**, then **Upload new dataset**. Name it after your company (for example `kestrel-connect-tests`), choose `evaluation.jsonl` and **Upload**. Check the preview shows the `query` and `ground_truth` columns.

   ![Upload new dataset: kestrel-connect-tests with evaluation.jsonl](../images/challenge-07-upload-dataset.png)

   ![The uploaded dataset selected, with a preview of the query and ground_truth columns](../images/challenge-07-dataset-preview.png)

5. **Configure agents:** leave it as it is; you are testing the agent as it is.
6. **Criteria:** keep the **Judge model** on your `ModelDeploymentName`. Keep the six **Recommended** evaluators already ticked, and add **Similarity**:

   | Evaluator | What it checks |
   |---|---|
   | **Tool use quality** | Five tool evaluators together: did it pick the right tool, with the right inputs, and use the output? |
   | **Output quality** | Six together: fluency, coherence, intent resolution, task adherence, groundedness and task completion |
   | **Violence**, **Sexual**, **Self-harm**, **Hate and unfairness** | Safety of the answers |
   | **Similarity** | How close each answer is to the expected answer in `ground_truth` |

   ![The evaluator catalog with the six recommended evaluators and Similarity selected](../images/challenge-07-evaluation-setup.png)

7. **Review:** name the evaluation `baseline` and **Submit**. The run takes a few minutes.

   ![The baseline evaluation with its run in progress](../images/challenge-07-run-started.png)

### Part C: Read the results (10 min)

1. When the run shows **Completed**, look at the score per evaluator on the `baseline` page, then open the run for the **rows**: which questions scored lowest?

   ![The baseline run: overall score, Tool use quality, Output quality, Similarity and the safety evaluators](../images/challenge-07-evaluation-results.png)

   ![Run details: the overall metrics and one row per test question](../images/challenge-07-evaluation-rows.png)

2. Open **View details** on a failed **Output quality** row. A composite evaluator says which of its parts failed, for example *Failed quality evaluators: groundedness, task_completion*, and each part gives its score and reasoning. Is the evaluator right? Evaluators are models too.

   ![Composite evaluator details: fluency, coherence, intent resolution, task adherence and task completion pass; groundedness fails because the judge sees no source](../images/challenge-07-composite-details.png)
3. Look at the identity-check row (the wrong postcode). If the agent shared anything about the account, that is a serious failure whatever the score says. If the agent refused correctly but still *failed*, read why: you'll find the judge's mistake in Part C step 4.
4. Two things that look like failures and are not:
   - **Safety evaluators show Error** (and *0% 0/0*) on every row in some regions, with *The needed capability 'content harm' is not supported by the RAI service in this region*. It says nothing about your agent; the guardrail from Challenge 4 still protects it.
   - **Groundedness fails almost everywhere**, even on answers that cite the right article. By default **Output quality** judges only the final answer text, not the knowledge base passages the agent retrieved, so the judge can't see what the answer was grounded in. **Similarity**, which compares with your expected answers, is the better signal for this test set.

### Part D: Change one thing and compare (10 min)

1. Change **one** setting on `contact-chat-agent`, save it as a new version, and run the evaluation again with the same dataset and evaluators. Choose one:
   - set **Reasoning Effort** from **low** to **medium** (parameters icon next to **Model**), or
   - remove the line *ALWAYS search the knowledge base…* from the instructions.

   ![The Reasoning Effort list: xhigh, high, medium, low and none](../images/challenge-07-reasoning-effort.png)

   On the `baseline` page, select **Add run** to run the same dataset and evaluators against the new version. Under **Configure agents** it asks for the prompt (**Config required**): select **Configure**, type `{{item.query}}` in **USER** (it sends each test question), **Save** and **Submit**.

   ![Add custom prompt: {{item.query}} as the user message](../images/challenge-07-add-run-prompt.png)

2. When it finishes, tick both runs and select **Compare runs**. Foundry runs a paired statistical test on every evaluator. Which evaluators moved? Did the test call any change significant, or **Inconclusive**? Did any single question change from pass to fail?

   ![Both runs completed: the medium run is slightly slower and uses more tokens](../images/challenge-07-two-runs.png)

   ![Statistically compare results: every difference Inconclusive or Too few samples](../images/challenge-07-compare.png)

3. With your team, decide which version you would put live, and what you would need to see before trusting a change on the **voice** agent too.

## ✔️ Success criteria

- [ ] You ran a `baseline` evaluation of `contact-chat-agent` on your company's ten test questions.
- [ ] You can name the lowest-scoring question and explain why it scored low.
- [ ] You changed one setting, re-ran the evaluation and compared the runs.
- [ ] You can explain why one good demo is not evidence, and what you would measure before going live.

## 📚 Learning resources

- [Evaluate agents in Foundry](https://learn.microsoft.com/azure/foundry/observability/quickstarts/quickstart-evaluate-hosted-agent)
- [Agent evaluators](https://learn.microsoft.com/azure/foundry/concepts/evaluation-evaluators/agent-evaluators)

[Coach solution and expected answers](../walkthrough/challenge-07/solution-07.md)
