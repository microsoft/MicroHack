# Challenge 3 - Build your first local agent

[Previous Challenge](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-04.md)

## Goal

Turn the local model into an agent that can **act**, not only answer.

## Actions

* Write a system prompt for the maintenance technician copilot.
* Create two tools in Python:
  * `get_machine_status(machine_id)` reads the machine from `resources/data/machines.json`.
  * `create_maintenance_ticket(machine_id, summary, priority)` appends a ticket to a local file. The priority is `low`, `medium` or `high`.
* Describe both tools to the model with JSON schemas and call the local endpoint with `tools=...`.
* Write the **tool-call loop**: send the request, run the tools the model asks for, send the results back, and repeat until the model gives a final answer.
* Test it with the cases in `resources/data/eval/tool_eval.json`, for example:
  * *"What is the status of machine CNC-07?"*
  * *"Open a high priority ticket for CNC-07: spindle vibration above the stop limit."*
  * *"Why is the sky blue?"* (the agent must not create a ticket for this)
* Look at what the model sends as tool arguments. Can it send something wrong? What does your code do about that?
* Add a **confirmation step**: before the agent creates a ticket, the technician must say yes.

## Success criteria

* The agent calls the machine status tool when you ask about a specific machine.
* The agent creates a local ticket when you ask for one, and **only** after the technician confirms.
* The tool-call loop ends with a final answer.
* Asking about an unknown machine gives a clear answer and not a crash.

## Learning resources

* [Function calling with Azure OpenAI](https://learn.microsoft.com/azure/ai-services/openai/how-to/function-calling)
* [Foundry Local CLI reference](https://learn.microsoft.com/azure/foundry-local/reference/reference-cli)
