# Challenge 2 - Choose your edge model

[Previous Challenge](challenge-01.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-03.md)

## Goal

Choose the small language model for your copilot **with evidence**, not by feeling. What fits on a shop-floor PC matters more than the best benchmark score.

## Actions

* Pick two small models from the Foundry Local catalog. Use `phi-4-mini` as one of them. Look at the size, the hardware each model runs on, and whether it supports **tool calling**.
* Write a script that runs both models against the same questions:
  * The questions in `resources/data/eval/retrieval_eval.json`. Give the model the matching SOP from `resources/data/sops` and ask it to answer from it.
  * The tool-calling cases in `resources/data/eval/tool_eval.json`.
* Record for each model:
  * how long the first token takes and how many tokens per second you get,
  * how big the model is, and how much memory it uses (Task Manager or Activity Monitor can help),
  * how many answers contain the expected facts,
  * how many tool-calling cases return the right tool with the right arguments.
* Try tool calling in two ways: `tool_choice="auto"` and `tool_choice="required"`. What changes?
* Pick one model and explain your choice in one or two sentences.

## Success criteria

* Both models ran against the full question set and the tool-calling cases.
* You have latency, size, memory, answer-quality and tool-calling figures for each model.
* You can explain your choice in one or two sentences.
* You know which of your two models you must **not** use for the agent, and why.

## Learning resources

* [Foundry Local CLI reference](https://learn.microsoft.com/azure/foundry-local/reference/reference-cli)
* [Function calling with Azure OpenAI](https://learn.microsoft.com/azure/ai-services/openai/how-to/function-calling)
